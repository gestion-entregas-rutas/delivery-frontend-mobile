import 'dart:async';

import 'package:signalr_netcore/signalr_client.dart';

import '../models/logistica_models.dart';

typedef RutaActualizada = void Function(RutaDto ruta);
typedef RestaurarRuta = Future<void> Function();

/// One connection per session; automatic reconnect never retries mutations.
class SeguimientoService {
  SeguimientoService({
    required String hubUrl,
    this.accessTokenProvider,
    this.onRutaActualizada,
    this.onReconexion,
    this.onConnectionChanged,
    this.beforeSubscribe,
  }) : hubUrl = _normalizeHubUrl(hubUrl);
  final String hubUrl;
  final String? Function()? accessTokenProvider;
  RutaActualizada? onRutaActualizada;
  RestaurarRuta? onReconexion;
  void Function(bool connected)? onConnectionChanged;
  Future<bool> Function()? beforeSubscribe;
  HubConnection? _connection;
  String? _driverId;
  String? _routeId;
  Future<void>? _startFuture;
  int _generation = 0;
  bool _subscribed = false;
  bool get isConnected =>
      _subscribed && _connection?.state == HubConnectionState.Connected;

  Future<void> start({required String driverId}) {
    if (_startFuture != null) return _startFuture!;
    if (isConnected && _driverId == driverId) return Future<void>.value();
    _driverId = driverId;
    final future = _start();
    _startFuture = future;
    return future.whenComplete(() {
      if (identical(_startFuture, future)) _startFuture = null;
    });
  }

  Future<void> _start() async {
    final generation = _generation;
    final connection = _connection ??= _build(generation);
    try {
      if (connection.state != HubConnectionState.Connected) {
        await connection.start()?.timeout(const Duration(seconds: 15));
      }
      if (!_current(connection, generation)) return;
      await _subscribe(connection, generation);
    } catch (_) {
      if (_current(connection, generation)) {
        _subscribed = false;
        onConnectionChanged?.call(false);
        // A timed-out initial start must not leave a hidden live connection.
        _connection = null;
        unawaited(connection.stop().catchError((_) {}));
      }
      rethrow;
    }
  }

  HubConnection _build(int generation) {
    final connection = HubConnectionBuilder()
        .withUrl(
          hubUrl,
          options: HttpConnectionOptions(
            accessTokenFactory: () async => accessTokenProvider?.call() ?? '',
          ),
        )
        .withAutomaticReconnect()
        .build();
    connection.on('RutaActualizada', (arguments) {
      if (!_current(connection, generation) || !_subscribed) return;
      final raw = arguments == null || arguments.isEmpty
          ? null
          : arguments.first;
      if (raw is! Map) return;
      try {
        final route = RutaDto.fromJson(Map<String, dynamic>.from(raw));
        if (route.repartidorId != _driverId ||
            (_routeId != null && route.id != _routeId)) {
          return;
        }
        onRutaActualizada?.call(route);
      } on FormatException {
        // Malformed notifications never replace the displayed route.
      }
    });
    connection.onreconnecting(({Exception? error}) {
      if (!_current(connection, generation)) return;
      _subscribed = false;
      onConnectionChanged?.call(false);
      unawaited(_validateAfterDisconnect(connection, generation));
    });
    connection.onclose(({Exception? error}) {
      if (!_current(connection, generation)) return;
      _subscribed = false;
      onConnectionChanged?.call(false);
      unawaited(_validateAfterDisconnect(connection, generation));
    });
    connection.onreconnected(({String? connectionId}) async {
      if (!_current(connection, generation)) return;
      try {
        await _subscribe(connection, generation);
        if (_current(connection, generation)) await onReconexion?.call();
      } catch (_) {
        if (_current(connection, generation)) {
          _subscribed = false;
          onConnectionChanged?.call(false);
        }
      }
    });
    return connection;
  }

  Future<void> _validateAfterDisconnect(
    HubConnection connection,
    int generation,
  ) async {
    final validator = beforeSubscribe;
    if (validator == null || !_current(connection, generation)) return;
    try {
      if (!await validator() && _current(connection, generation)) {
        // Invalid or temporarily unverifiable sessions must stop automatic
        // reconnect attempts until the app has restored the session.
        await stop();
      }
    } catch (_) {
      // Validation failures are surfaced by the session controller. Keep the
      // transport disconnected instead of reviving protected subscriptions.
      if (_current(connection, generation)) await stop();
    }
  }

  bool _current(HubConnection connection, int generation) =>
      identical(_connection, connection) &&
      _generation == generation &&
      _driverId != null;

  Future<void> _subscribe(HubConnection connection, int generation) async {
    final id = _driverId;
    if (id == null || !_current(connection, generation)) return;
    if (beforeSubscribe != null && !await beforeSubscribe!()) return;
    if (!_current(connection, generation)) return;
    await connection
        .invoke('SuscribirseARepartidor', args: <Object>[id])
        .timeout(const Duration(seconds: 15));
    if (!_current(connection, generation)) return;
    _subscribed = true;
    onConnectionChanged?.call(true);
  }

  void setRoute(String? routeId, Iterable<String> pedidoIds) {
    _routeId = routeId;
  }

  Future<void> stop() async {
    _generation++;
    _driverId = null;
    _routeId = null;
    _subscribed = false;
    _startFuture = null;
    final connection = _connection;
    _connection = null;
    try {
      await connection?.stop().timeout(const Duration(seconds: 5));
    } catch (_) {
      // Ignore shutdown transport failures; stale callbacks are already invalidated.
    }
  }

  static String _normalizeHubUrl(String value) {
    var result = value.trim();
    while (result.endsWith('/')) {
      result = result.substring(0, result.length - 1);
    }
    if (result.endsWith('/api')) {
      result = result.substring(0, result.length - 4);
    }
    return '$result/hubs/seguimiento';
  }
}
