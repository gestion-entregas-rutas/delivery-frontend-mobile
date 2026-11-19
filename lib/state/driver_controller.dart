import 'dart:async';

import 'package:flutter/foundation.dart';

import '../data/api/api_exception.dart';
import '../data/api/api_client.dart';
import '../data/api/logistica_repository.dart';
import '../location/gps_service.dart';
import '../models/logistica_models.dart';
import '../realtime/seguimiento_service.dart';
import '../utils/route_day.dart' as day;

enum DriverLoadState { idle, loading, loaded, empty, error }

class DriverController extends ChangeNotifier {
  DriverController({
    required this.repository,
    required this.driverId,
    SeguimientoService? seguimiento,
    GpsService? gps,
    DateTime? initialDate,
    this.closeApiClient = false,
    this.validateSession,
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now,
       seguimiento =
           seguimiento ??
           _defaultSeguimiento(
             repository.api.baseUrl,
             repository.api.accessTokenProvider,
           ),
       gps = gps ?? GpsService(),
       selectedDate = _dateString(initialDate ?? DateTime.now()) {
    this.seguimiento.onRutaActualizada = _onRealtimeRoute;
    this.seguimiento.onReconexion = _onRealtimeReconnected;
    this.seguimiento.onConnectionChanged = _onConnectionChanged;
    // Revalidate the JWT before every initial/reconnected subscription. A
    // closed hub must never resume protected updates with a revoked session.
    this.seguimiento.beforeSubscribe = validateSession;
    this.gps.onStateChanged = _onGpsState;
  }

  final LogisticaRepository repository;
  final String driverId;
  final SeguimientoService seguimiento;
  final GpsService gps;
  final bool closeApiClient;
  final Future<bool> Function()? validateSession;

  /// Reloj del teléfono; se puede cambiar en pruebas.
  final DateTime Function() _clock;

  /// Ahora, según el reloj del controlador.
  DateTime get now => _clock();

  /// Por qué la ruta actual NO se puede iniciar hoy (por ejemplo, es de
  /// mañana); `null` si no hay ruta por iniciar o sí se puede.
  ///
  /// Es un control de la app para no dejar hacer algo que no corresponde. La
  /// decisión final sigue siendo del servidor (AGENTS.md, regla 3).
  String? get startBlockedReason {
    final current = route;
    if (current == null || current.estado != 'Planificada') return null;
    return day.startBlockedReason(current.fecha, now);
  }

  String selectedDate;
  RutaDto? route;
  DriverLoadState loadState = DriverLoadState.idle;
  ApiException? error;
  String? realtimeError;
  bool _hadRealtimeConnection = false;
  bool isBusy = false;
  bool uncertainMutation = false;
  GpsState gpsState = GpsState.stopped;
  GpsSample? latestGpsSample;

  int _generation = 0;
  int _refreshGeneration = 0;
  int _mutationGeneration = 0;
  final Map<String, String> _rememberedRouteIds = <String, String>{};
  bool _disposed = false;
  bool _foreground = true;
  bool _clientClosed = false;
  Future<void> _actionQueue = Future<void>.value();
  DateTime? _lastLocationSentAtUtc;
  DateTime? _lastLocationSampleAtUtc;
  bool _sendingLocation = false;

  Future<void>? _initFuture;

  /// Idempotente: la puede llamar quien precarga la ruta (el splash) y luego
  /// la pantalla principal sin duplicar la conexión ni la consulta.
  Future<void> initialize() => _initFuture ??= _initialize();

  Future<void> _initialize() async {
    if (_disposed) return;
    seguimiento.setRoute(null, const <String>[]);
    if (validateSession != null && !await validateSession!()) return;
    try {
      // Subscribe before REST so a fast route update cannot be missed.
      await seguimiento.start(driverId: driverId);
    } catch (exception) {
      realtimeError = 'Actualizaciones en tiempo real no disponibles; puedes usar Actualizar.';
      _notify();
    }
    if (!_disposed) await refresh();
  }

  Future<void> retryRealtime() async {
    if (validateSession != null && !await validateSession!()) return;
    try {
      await seguimiento.start(driverId: driverId);
      realtimeError = null;
      await refresh();
    } catch (_) {
      realtimeError = 'Actualizaciones en tiempo real no disponibles; puedes seguir usando Actualizar.';
      _notify();
    }
  }

  Future<void> changeDate(DateTime value) async {
    final next = _dateString(value);
    if (next == selectedDate) return;
    _generation++;
    selectedDate = next;
    route = null;
    uncertainMutation = false;
    _lastLocationSentAtUtc = null;
    _lastLocationSampleAtUtc = null;
    await gps.stop();
    seguimiento.setRoute(null, const <String>[]);
    _notify();
    await refresh();
  }

  Future<void> refresh() async {
    if (_disposed) return;
    final requestGeneration = ++_refreshGeneration;
    final screenGeneration = _generation;
    final requestDate = selectedDate;
    loadState = DriverLoadState.loading;
    error = null;
    _notify();
    try {
      var result = await repository.rutaActiva(driverId, requestDate);
      // The active endpoint intentionally stops returning a completed route.
      // Remember its id per date and read it directly so completion remains
      // visible after the last delivery.
      if (result == null) {
        final remembered = _rememberedRouteIds[requestDate];
        if (remembered != null) {
          try {
            final completed = await repository.ruta(remembered);
            if (completed.repartidorId == driverId &&
                completed.fecha == requestDate) {
              result = completed;
            }
          } on ApiException catch (exception) {
            if (exception.statusCode != 404) rethrow;
          }
        }
      }
      if (_disposed ||
          requestGeneration != _refreshGeneration ||
          screenGeneration != _generation) {
        return;
      }
      route = result;
      if (result == null) {
        unawaited(gps.stop());
        loadState = DriverLoadState.empty;
        seguimiento.setRoute(null, const <String>[]);
      } else {
        _rememberedRouteIds[requestDate] = result.id;
        loadState = DriverLoadState.loaded;
        _setRealtimeRoute(result);
        if (result.estado != 'EnCurso') unawaited(gps.stop());
      }
      if (uncertainMutation) uncertainMutation = false;
      _notify();
    } on ApiException catch (exception) {
      if (_disposed ||
          requestGeneration != _refreshGeneration ||
          screenGeneration != _generation) {
        return;
      }
      error = exception;
      loadState = DriverLoadState.error;
      _notify();
    }
  }

  Future<void> startRoute() => _enqueueMutation(() async {
    final current = _requireActionRoute();
    if (current.estado != 'Planificada' || current.paradas.isEmpty) {
      throw const ApiException(message: 'La ruta no está lista para iniciar.');
    }
    // Una ruta de otro día no se inicia: ni se pide el GPS ni se llama al
    // servidor.
    final blocked = day.startBlockedReason(current.fecha, now);
    if (blocked != null) throw ApiException(message: blocked);
    await gps.checkReadiness();
    // GPS preparation is visible to the driver, but does not block the
    // REST delivery workflow while the backend location contract is pending.
    final updated = await repository.iniciarRuta(current.id);
    if (!_sameRoute(current)) return;
    route = updated;
    _rememberedRouteIds[selectedDate] = updated.id;
    loadState = DriverLoadState.loaded;
    _setRealtimeRoute(updated);
    await _startLocalGps();
    _notify();
  });

  Future<void> markEnCamino(String pedidoId) => _enqueueMutation(() async {
    final current = _requireActionRoute();
    final stop = _stop(current, pedidoId);
    if (current.estado != 'EnCurso' || stop?.pedido.estado != 'AsignadoARuta') {
      throw const ApiException(
        message: 'Este pedido no puede marcarse en camino todavía.',
      );
    }
    final updated = await repository.marcarEnCamino(pedidoId);
    if (!_sameRoute(current)) return;
    route = route!.withPedido(updated);
    _setRealtimeRoute(route!);
    _notify();
  });

  Future<void> confirmDelivery(String pedidoId) => _enqueueMutation(() async {
    final current = _requireActionRoute();
    final stop = _stop(current, pedidoId);
    if (current.estado != 'EnCurso' || stop?.pedido.estado != 'EnCamino') {
      throw const ApiException(
        message: 'Este pedido no puede confirmarse todavía.',
      );
    }
    final updated = await repository.confirmarEntrega(pedidoId);
    if (!_sameRoute(current)) return;
    route = route!.withPedido(updated);
    _setRealtimeRoute(route!);
    // Las paradas canceladas no impiden cerrar la ruta.
    if (route!.allResolved) {
      try {
        final refreshed = await repository.ruta(current.id);
        if (!_sameRoute(current)) return;
        route = refreshed;
        _rememberedRouteIds[selectedDate] = refreshed.id;
      } on ApiException catch (exception) {
        // The POST response remains authoritative for the delivered
        // order; a failed follow-up must remain visible as uncertain.
        if (exception.isUncertain) {
          uncertainMutation = true;
        }
      }
      await gps.stop();
    }
    _notify();
  });

  Future<void> _enqueueMutation(Future<void> Function() action) {
    // A tap while a transition is in flight is ignored instead of queued
    // against a stale route snapshot.
    if (_disposed || isBusy || uncertainMutation) return Future<void>.value();
    isBusy = true;
    _mutationGeneration = _generation;
    error = null;
    _notify();
    final operation = _actionQueue.then((_) async {
      try {
        await action();
      } on ApiException catch (exception) {
        error = exception;
        if (exception.isConflict || exception.isUncertain) {
          uncertainMutation = exception.isUncertain;
          await _refreshAfterMutation();
        }
        // refresh() clears the previous banner while loading; keep the
        // mutation response visible after the authoritative refresh.
        error = exception;
        _notify();
      } finally {
        if (!_disposed) {
          isBusy = false;
          _notify();
        }
      }
    });
    _actionQueue = operation.catchError((_) {});
    return operation;
  }

  Future<void> _refreshAfterMutation() async {
    final wasUncertain = uncertainMutation;
    await refresh();
    if (loadState == DriverLoadState.error && wasUncertain) {
      uncertainMutation = true;
      _notify();
    }
  }

  RutaDto _requireActionRoute() {
    final current = route;
    if (current == null ||
        loadState != DriverLoadState.loaded ||
        uncertainMutation) {
      throw const ApiException(
        message: 'La ruta ya no está disponible. Actualiza antes de continuar.',
      );
    }
    return current;
  }

  ParadaDto? _stop(RutaDto current, String pedidoId) {
    for (final stop in current.paradas) {
      if (stop.pedido.id == pedidoId) return stop;
    }
    return null;
  }

  bool _sameRoute(RutaDto snapshot) =>
      !_disposed &&
      route?.id == snapshot.id &&
      route?.fecha == selectedDate &&
      _mutationGeneration == _generation;

  void _handleGpsSample(GpsSample sample, int generation) {
    if (latestGpsSample == null ||
        sample.capturedAtUtc.isAfter(latestGpsSample!.capturedAtUtc)) {
      latestGpsSample = sample;
      _notify();
    }
    // Solo se envía al servidor con la ruta en curso (ver _reportLocation).
    unawaited(_reportLocation(sample, generation));
  }

  Future<void> _startLocalGps() async {
    final generation = _generation;
    gps.onSample = (sample) => _handleGpsSample(sample, generation);
    gpsState = await gps.start();
    if (_disposed ||
        !_foreground ||
        generation != _generation ||
        route?.estado != 'EnCurso') {
      await gps.stop();
      return;
    }
    _notify();
  }

  /// Enciende el GPS para VER tu posición en el mapa y en la ruta a una
  /// parada, aunque la ruta aún no esté iniciada. Pide el permiso de ubicación
  /// si hace falta.
  ///
  /// La posición se usa solo en el teléfono: no se envía al servidor mientras
  /// la ruta no esté en curso (la regla está en [_reportLocation]). No cambia
  /// ningún estado de la ruta ni de las entregas.
  Future<void> enableLocationPreview() async {
    if (_disposed || !_foreground) return;
    final generation = _generation;
    gps.onSample = (sample) => _handleGpsSample(sample, generation);
    gpsState = await gps.start();
    if (_disposed || generation != _generation) return;
    _notify();
  }

  /// Apaga el GPS que se encendió solo para ver la posición, salvo que la ruta
  /// esté en curso (entonces el GPS es parte del seguimiento y se queda).
  Future<void> releaseLocationPreview() async {
    if (_disposed) return;
    if (route?.estado == 'EnCurso') return;
    await gps.stop();
    // Sin GPS encendido la posición guardada ya no es la actual.
    if (_disposed) return;
    latestGpsSample = null;
    _notify();
  }

  Future<void> _reportLocation(GpsSample sample, int generation) async {
    final current = route;
    if (_disposed ||
        !_foreground ||
        generation != _generation ||
        current?.estado != 'EnCurso' ||
        uncertainMutation) {
      return;
    }
    if (_lastLocationSampleAtUtc != null &&
        !sample.capturedAtUtc.isAfter(_lastLocationSampleAtUtc!)) {
      return;
    }
    final lastSent = _lastLocationSentAtUtc;
    if (lastSent != null &&
        sample.capturedAtUtc.difference(lastSent) <
            const Duration(seconds: 12)) {
      return;
    }
    if (_sendingLocation) return;
    _sendingLocation = true;
    try {
      await repository.reportarUbicacion(
        rutaId: current!.id,
        latitud: sample.latitude,
        longitud: sample.longitude,
        precisionMetros: sample.accuracyMeters,
        capturadaEnUtc: sample.capturedAtUtc,
      );
      _lastLocationSentAtUtc = sample.capturedAtUtc;
      _lastLocationSampleAtUtc = sample.capturedAtUtc;
    } on ApiException {
      // Best-effort: fallos de red/contrato no deben interrumpir la operación.
    } finally {
      _sendingLocation = false;
    }
  }

  void _setRealtimeRoute(RutaDto value) {
    seguimiento.setRoute(value.id, value.paradas.map((stop) => stop.pedido.id));
  }

  void _onRealtimeRoute(RutaDto value) {
    if (_disposed ||
        value.repartidorId != driverId ||
        value.fecha != selectedDate) {
      return;
    }
    if (route?.id != null && route!.id != value.id) return;
    // A pushed update is newer than any REST request currently in flight.
    _refreshGeneration++;
    route = value;
    loadState = DriverLoadState.loaded;
    error = null;
    _setRealtimeRoute(value);
    _rememberedRouteIds[selectedDate] = value.id;
    if (value.estado == 'Completada' || value.estado == 'Cancelada') {
      unawaited(gps.stop());
    }
    _notify();
  }

  Future<void> _onRealtimeReconnected() async {
    if (validateSession != null && !await validateSession!()) return;
    realtimeError = null;
    await refresh();
  }

  void _onConnectionChanged(bool connected) {
    if (connected) {
      _hadRealtimeConnection = true;
      realtimeError = null;
    } else if (_hadRealtimeConnection || loadState != DriverLoadState.idle) {
      realtimeError = 'Conexión en tiempo real interrumpida; pulsa Reintentar para volver a suscribirte.';
    }
    _notify();
  }

  void _onGpsState(GpsState value) {
    gpsState = value;
    _notify();
  }

  void onPaused() {
    _foreground = false;
    unawaited(gps.stop());
  }

  Future<void> onResumed() async {
    if (_disposed) return;
    _foreground = true;
    await gps.stop();
    if (validateSession != null && !await validateSession!()) return;
    await refresh();
    if (!_disposed &&
        _foreground &&
        loadState == DriverLoadState.loaded &&
        !uncertainMutation &&
        route?.estado == 'EnCurso') {
      await _startLocalGps();
    }
  }

  Future<void> logout() async {
    _generation++;
    await gps.stop();
    await seguimiento.stop();
    route = null;
    latestGpsSample = null;
    _lastLocationSentAtUtc = null;
    _lastLocationSampleAtUtc = null;
    _closeClientIfOwned();
    _disposed = true;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    unawaited(gps.stop());
    unawaited(seguimiento.stop());
    _closeClientIfOwned();
    super.dispose();
  }

  void _closeClientIfOwned() {
    if (closeApiClient && !_clientClosed) {
      _clientClosed = true;
      repository.api.close();
    }
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  static SeguimientoService _defaultSeguimiento(
    String baseUrl,
    AccessTokenProvider? accessTokenProvider,
  ) => SeguimientoService(
    hubUrl: baseUrl,
    accessTokenProvider: accessTokenProvider,
    onRutaActualizada: (_) {},
  );

  static String _dateString(DateTime value) =>
      '${value.year.toString().padLeft(4, '0')}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}';
}
