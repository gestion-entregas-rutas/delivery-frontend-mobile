import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../data/routing/road_router.dart';
import '../models/logistica_models.dart';
import '../state/driver_controller.dart';
import '../theme/app_colors.dart';
import '../theme/app_text.dart';
import '../utils/contact.dart';
import '../utils/format.dart';
import '../widgets/primary_button.dart';
import '../widgets/route/gps_status.dart';
import '../widgets/route/map_markers.dart';
import '../widgets/route/route_map.dart' show RouteMap;
import '../widgets/status_chip.dart';

/// Ruta hasta UNA parada: desde la posición del repartidor hasta ese cliente,
/// por las calles, con distancia y tiempo. "Iniciar" hace que el mapa siga al
/// repartidor mientras avanza.
///
/// Es distinta del mapa global (pestaña Mapa), que muestra todas las paradas.
/// No cambia el estado de la ruta ni de la entrega: eso sigue dependiendo del
/// servidor (AGENTS.md, regla 3).
class StopRouteScreen extends StatefulWidget {
  const StopRouteScreen({
    super.key,
    required this.stop,
    required this.controller,
    required this.router,
    this.onCall,
    this.onWhatsapp,
  });

  final ParadaDto stop;

  /// De aquí sale la ubicación del repartidor y el estado del GPS.
  final DriverController controller;
  final RoadRouter router;
  final VoidCallback? onCall;
  final VoidCallback? onWhatsapp;

  @override
  State<StopRouteScreen> createState() => _StopRouteScreenState();
}

class _StopRouteScreenState extends State<StopRouteScreen> {
  /// Mientras avanzas, el camino se vuelve a pedir como máximo así de seguido
  /// y solo si te moviste esto.
  static const Duration _minRefresh = Duration(seconds: 15);
  static const double _minMoveMeters = 50;
  static const double _arrivedMeters = 40;

  final MapController _map = MapController();
  final Distance _distance = const Distance();

  bool _ready = false;
  bool _following = false;
  RoadRoute? _route;
  bool _loading = false;
  bool _failed = false;
  LatLng? _lastOrigin;
  DateTime? _lastRequestAt;
  bool _fittedRoute = false;

  LatLng get _destination => LatLng(
    widget.stop.pedido.ubicacion.latitud,
    widget.stop.pedido.ubicacion.longitud,
  );

  LatLng? get _me {
    final sample = widget.controller.latestGpsSample;
    return sample == null ? null : LatLng(sample.latitude, sample.longitude);
  }

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onLocation);
    _onLocation();
    // Sin ubicación todavía: se enciende el GPS al abrir (pide el permiso si
    // falta), para que no haya que ir a configurar nada en otra parte.
    if (_me == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) widget.controller.enableLocationPreview();
      });
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onLocation);
    // Si la ruta no está en curso, el GPS se apaga al salir. Se difiere para
    // no notificar al resto de la app en plena destrucción de este árbol.
    final controller = widget.controller;
    Future<void>.microtask(controller.releaseLocationPreview);
    _map.dispose();
    super.dispose();
  }

  void _onLocation() {
    final me = _me;
    if (me == null) return;
    if (_shouldRequest(me)) _requestRoute(me);
    if (_following && _ready) {
      _map.move(me, math.max(_map.camera.zoom, 17));
    }
  }

  bool _shouldRequest(LatLng me) {
    if (_loading) return false;
    final lastOrigin = _lastOrigin;
    final lastAt = _lastRequestAt;
    if (lastOrigin == null || lastAt == null) return true;
    // Si falló, se reintenta con el mismo ritmo.
    final moved = _distance.as(LengthUnit.Meter, lastOrigin, me);
    return DateTime.now().difference(lastAt) >= _minRefresh &&
        (moved >= _minMoveMeters || _failed);
  }

  Future<void> _requestRoute(LatLng origin) async {
    _lastOrigin = origin;
    _lastRequestAt = DateTime.now();
    if (mounted) setState(() => _loading = true);
    final result = await widget.router.route([origin, _destination]);
    if (!mounted) return;
    setState(() {
      _loading = false;
      _failed = result == null;
      if (result != null) _route = result;
    });
    if (result != null && !_fittedRoute && !_following) {
      _fittedRoute = true;
      WidgetsBinding.instance.addPostFrameCallback((_) => _fitRoute());
    }
  }

  void _fitRoute() {
    if (!_ready) return;
    final points = _route?.points ?? [?_me, _destination];
    if (points.length < 2) {
      _map.move(_destination, 16);
      return;
    }
    _map.fitCamera(
      CameraFit.coordinates(
        coordinates: points,
        padding: const EdgeInsets.fromLTRB(48, 110, 48, 330),
        maxZoom: 17,
      ),
    );
  }

  void _toggleFollow() {
    final me = _me;
    if (me == null) return;
    setState(() => _following = !_following);
    if (_following && _ready) {
      _map.move(me, math.max(_map.camera.zoom, 17));
    } else if (!_following) {
      _fitRoute();
    }
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: widget.controller,
    builder: (context, _) {
      final me = _me;
      final order = widget.stop.pedido;
      final straight = me == null
          ? null
          : _distance.as(LengthUnit.Meter, me, _destination);
      final arrived = straight != null && straight <= _arrivedMeters;
      return Scaffold(
        backgroundColor: AppColors.brandSoft,
        // expand: sin esto el Stack mediría solo lo que su hijo no posicionado
        // (la barra de arriba) y el mapa quedaría de unos pocos píxeles.
        body: Stack(
          fit: StackFit.expand,
          children: [
            Positioned.fill(child: _mapView(me)),
            Positioned(
              left: 0,
              right: 0,
              top: 0,
              child: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                  child: Row(
                    children: [
                      Material(
                        color: Colors.white,
                        elevation: 3,
                        shape: const CircleBorder(),
                        child: IconButton(
                          tooltip: 'Volver',
                          onPressed: () => Navigator.of(context).maybePop(),
                          icon: const Icon(Icons.arrow_back_rounded),
                          style: IconButton.styleFrom(
                            minimumSize: const Size(48, 48),
                            foregroundColor: AppColors.ink,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(999),
                            boxShadow: const [
                              BoxShadow(
                                color: Color(0x26000000),
                                blurRadius: 12,
                                offset: Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Text(
                            'Ruta a ${order.clienteNombre}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppText.body.copyWith(
                              fontWeight: FontWeight.w700,
                              color: AppColors.ink,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: _panel(context, me, arrived, straight),
            ),
          ],
        ),
      );
    },
  );

  Widget _mapView(LatLng? me) {
    final points = [?me, _destination];
    final road = _route?.points;
    return FlutterMap(
      mapController: _map,
      options: MapOptions(
        initialCenter: _destination,
        initialZoom: 16,
        initialCameraFit: points.length > 1
            ? CameraFit.coordinates(
                coordinates: points,
                padding: const EdgeInsets.fromLTRB(48, 110, 48, 330),
                maxZoom: 17,
              )
            : null,
        minZoom: 3,
        maxZoom: 19,
        interactionOptions: const InteractionOptions(
          flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
        ),
        onMapReady: () {
          _ready = true;
          if (_route != null && !_fittedRoute) {
            _fittedRoute = true;
            _fitRoute();
          }
        },
        // Si tocas y mueves el mapa, dejas de seguirte: el mapa no pelea con
        // tu dedo.
        onPositionChanged: (_, hasGesture) {
          if (hasGesture && _following) setState(() => _following = false);
        },
      ),
      children: [
        if (RouteMap.tilesEnabled)
          TileLayer(
            urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
            userAgentPackageName: 'com.example.frontend_mobile',
          )
        else
          const ColoredBox(color: AppColors.brandSoft),
        PolylineLayer(
          polylines: [
            if (road != null && road.length >= 2)
              Polyline(
                points: road,
                strokeWidth: 7,
                color: AppColors.brandBright,
                borderStrokeWidth: 2,
                borderColor: Colors.white,
              )
            else if (me != null)
              // Sin camino por calles: línea recta, para no dejar el mapa
              // vacío.
              Polyline(
                points: [me, _destination],
                strokeWidth: 4,
                color: AppColors.brandBright,
                pattern: StrokePattern.dashed(segments: const [12, 9]),
              ),
          ],
        ),
        MarkerLayer(
          markers: [
            Marker(
              point: _destination,
              width: 54,
              height: 54,
              child: StopBoxMarker(
                key: const ValueKey('destination-marker'),
                delivered: widget.stop.pedido.estado == 'Entregado',
                active: widget.stop.pedido.estado != 'Entregado',
                semanticLabel:
                    'Destino: parada ${widget.stop.orden}, ${widget.stop.pedido.clienteNombre}',
              ),
            ),
            if (me != null)
              Marker(
                point: me,
                width: 60,
                height: 60,
                child: const DriverMarker(),
              ),
          ],
        ),
        if (RouteMap.tilesEnabled)
          const SimpleAttributionWidget(
            source: Text('OpenStreetMap contributors'),
            alignment: Alignment.topRight,
          ),
      ],
    );
  }

  Widget _panel(
    BuildContext context,
    LatLng? me,
    bool arrived,
    double? straight,
  ) {
    final order = widget.stop.pedido;
    final route = _route;
    final phone = order.clienteTelefono.trim();
    final hasLocation = me != null;

    final String headline;
    final String detail;
    if (arrived) {
      headline = 'Ya llegaste';
      detail = order.direccion;
    } else if (route != null) {
      headline =
          '${formatDuration(route.durationSeconds)} · '
          '${formatDistance(route.distanceMeters)}';
      detail = 'hasta ${order.direccion}';
    } else if (straight != null) {
      headline = '≈ ${formatDistance(straight)}';
      detail = _loading
          ? 'Calculando el camino por las calles…'
          : 'En línea recta. No se pudo trazar por calles.';
    } else {
      headline = order.clienteNombre;
      detail = order.direccion;
    }

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        boxShadow: [
          BoxShadow(
            color: Color(0x33000000),
            blurRadius: 20,
            offset: Offset(0, -4),
          ),
        ],
      ),
      // Con letra grande o pantalla baja el panel no debe salirse de la
      // pantalla: se limita a ~60 % del alto y se desplaza.
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * .6,
        ),
        child: SingleChildScrollView(
          child: SafeArea(
            top: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    StatusChip(
                      status: arrived ? AppStatus.done : AppStatus.active,
                      label: arrived
                          ? 'En el destino'
                          : 'Parada ${widget.stop.orden}',
                    ),
                    if (_loading) ...[
                      const SizedBox(width: 10),
                      const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2.5),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 10),
                Text(headline, style: AppText.title),
                Text(
                  detail,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppText.body.copyWith(color: AppColors.grey),
                ),
                const SizedBox(height: 4),
                Text(
                  '${order.clienteNombre} · ${shortTime(order.horaEntrega)}',
                  style: AppText.bodySmall.copyWith(
                    fontWeight: FontWeight.w700,
                    color: AppColors.ink,
                  ),
                ),
                const SizedBox(height: 14),
                if (!hasLocation) ...[
                  Text(
                    'Necesitamos tu ubicación para trazar el camino hasta aquí.',
                    style: AppText.bodySmall.copyWith(color: AppColors.grey),
                  ),
                  const SizedBox(height: 8),
                  GpsStatus(
                    state: widget.controller.gpsState,
                    onOpenSettings: widget.controller.gps.openSettings,
                    onEnable: widget.controller.enableLocationPreview,
                  ),
                  const SizedBox(height: 12),
                ],
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: phone.isEmpty ? null : widget.onCall,
                        icon: const Icon(Icons.call_rounded, size: 20),
                        label: const Text('Llamar'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: whatsappUri(phone) == null
                            ? null
                            : widget.onWhatsapp,
                        icon: const Icon(Icons.chat_rounded, size: 20),
                        label: const Text('WhatsApp'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                PrimaryButton(
                  label: _following ? 'Detener' : 'Iniciar',
                  icon: _following
                      ? Icons.stop_rounded
                      : Icons.navigation_rounded,
                  onPressed: hasLocation ? _toggleFollow : null,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
