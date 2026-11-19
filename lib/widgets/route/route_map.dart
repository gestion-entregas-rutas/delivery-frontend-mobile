import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../data/routing/road_router.dart';
import '../../location/gps_service.dart';
import '../../models/logistica_models.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text.dart';
import '../../utils/contact.dart';
import '../status_chip.dart';
import 'gps_status.dart';
import 'map_markers.dart';

/// Un punto del mapa: una parada con su posición ya validada.
class MapStop {
  const MapStop({required this.stop, required this.point});

  final ParadaDto stop;
  final LatLng point;

  bool get delivered => stop.pedido.estado == 'Entregado';
  String get id => stop.pedido.id;
}

/// Paradas de la ruta con coordenadas válidas, en el orden del algoritmo del
/// servidor. Se descartan las que no tienen posición (vacía o 0,0).
List<MapStop> mapStopsOf(RutaDto? route) {
  if (route == null) return const [];
  final result = <MapStop>[];
  for (final stop in route.paradas) {
    final lat = stop.pedido.ubicacion.latitud;
    final lng = stop.pedido.ubicacion.longitud;
    final valid =
        lat.isFinite &&
        lng.isFinite &&
        lat.abs() <= 90 &&
        lng.abs() <= 180 &&
        !(lat == 0 && lng == 0);
    if (valid) result.add(MapStop(stop: stop, point: LatLng(lat, lng)));
  }
  return result;
}

/// Mapa global de la ruta: todas las paradas en un solo mapa, unidas por las
/// calles en el orden de entrega. Cada parada es una caja; las entregadas
/// cambian de color y llevan un check. El repartidor es una moto.
///
/// El ORDEN de las paradas lo decide el servidor (AGENTS.md, regla 2); aquí
/// solo se dibuja el camino por calles entre ellas. Si no se puede trazar
/// (sin red o sin servicio), se dibujan líneas rectas.
class RouteMap extends StatefulWidget {
  const RouteMap({
    super.key,
    required this.route,
    this.router,
    this.myLocation,
    this.gpsState,
    this.onEnableLocation,
    this.onOpenSettings,
    this.onCall,
    this.onWhatsapp,
  });

  /// Los tests lo apagan: las teselas necesitan red.
  static bool tilesEnabled = true;

  final RutaDto? route;

  /// Traza el camino por calles. Sin él, líneas rectas.
  final RoadRouter? router;
  final GpsSample? myLocation;

  /// Estado del GPS: si no hay ubicación, se muestra aquí con su botón para
  /// activarla.
  final GpsState? gpsState;
  final VoidCallback? onEnableLocation;
  final VoidCallback? onOpenSettings;

  final ValueChanged<ParadaDto>? onCall;
  final ValueChanged<ParadaDto>? onWhatsapp;

  @override
  State<RouteMap> createState() => _RouteMapState();
}

class _RouteMapState extends State<RouteMap> {
  final MapController _controller = MapController();
  bool _ready = false;
  String? _selectedId;

  // Trazado por calles de toda la ruta.
  String? _roadKey;
  List<LatLng>? _road;
  bool _roadLoading = false;

  @override
  void initState() {
    super.initState();
    _loadRoad();
  }

  @override
  void didUpdateWidget(RouteMap oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.route?.id != widget.route?.id) {
      _selectedId = null;
      WidgetsBinding.instance.addPostFrameCallback((_) => _fitAll());
    }
    _loadRoad();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// Pide el camino por calles. La clave solo depende de las coordenadas: que
  /// una parada pase a entregada no vuelve a pedirlo.
  void _loadRoad() {
    final stops = mapStopsOf(widget.route);
    final key = stops
        .map((s) => '${s.point.latitude},${s.point.longitude}')
        .join(';');
    if (key == _roadKey) return;
    _roadKey = key;
    _road = null;
    final router = widget.router;
    if (router == null || stops.length < 2) {
      _roadLoading = false;
      return;
    }
    _roadLoading = true;
    router.route([for (final s in stops) s.point]).then((result) {
      if (!mounted || _roadKey != key) return;
      setState(() {
        _road = result?.points;
        _roadLoading = false;
      });
    });
  }

  MapStop? _byId(String? id) {
    if (id == null) return null;
    for (final stop in mapStopsOf(widget.route)) {
      if (stop.id == id) return stop;
    }
    return null;
  }

  /// Encuadra todas las paradas (y al repartidor, si hay ubicación).
  void _fitAll() {
    if (!_ready) return;
    final points = _allPoints();
    if (points.isEmpty) return;
    if (points.length == 1) {
      _controller.move(points.first, 16);
      return;
    }
    _controller.fitCamera(
      CameraFit.coordinates(
        coordinates: points,
        padding: const EdgeInsets.fromLTRB(48, 110, 48, 120),
        maxZoom: 17,
      ),
    );
  }

  List<LatLng> _allPoints() => [
    for (final stop in mapStopsOf(widget.route)) stop.point,
    if (widget.myLocation != null)
      LatLng(widget.myLocation!.latitude, widget.myLocation!.longitude),
  ];

  /// Selecciona una parada y la centra, para que su tarjeta de abajo no la
  /// tape.
  void _select(MapStop stop) {
    setState(() => _selectedId = stop.id);
    if (_ready) _controller.move(stop.point, _controller.camera.zoom);
  }

  void _centerOnMe() {
    final me = widget.myLocation;
    if (!_ready || me == null) return;
    _controller.move(LatLng(me.latitude, me.longitude), 16.5);
  }

  /// La parada actual es la primera que aún no se entregó.
  String? _activeId(List<MapStop> stops) {
    for (final s in stops) {
      if (!s.delivered) return s.id;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final stops = mapStopsOf(widget.route);
    final points = _allPoints();
    final selected = _byId(_selectedId);
    final activeId = _activeId(stops);

    final options = MapOptions(
      initialCenter: points.isEmpty ? const LatLng(0, 0) : points.first,
      initialZoom: 15,
      initialCameraFit: points.length > 1
          ? CameraFit.coordinates(
              coordinates: points,
              padding: const EdgeInsets.fromLTRB(48, 110, 48, 120),
              maxZoom: 17,
            )
          : null,
      minZoom: 3,
      maxZoom: 19,
      interactionOptions: const InteractionOptions(
        flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
      ),
      onTap: (_, _) => setState(() => _selectedId = null),
      onMapReady: () => _ready = true,
    );

    return Stack(
      children: [
        Positioned.fill(
          child: FlutterMap(
            mapController: _controller,
            options: options,
            children: [
              if (RouteMap.tilesEnabled)
                TileLayer(
                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'com.example.frontend_mobile',
                )
              else
                const ColoredBox(color: AppColors.brandSoft),
              PolylineLayer(polylines: _polylines(stops)),
              MarkerLayer(
                markers: [
                  for (final stop in stops)
                    Marker(
                      point: stop.point,
                      width: stop.id == activeId || stop.id == _selectedId
                          ? 54
                          : 40,
                      height: stop.id == activeId || stop.id == _selectedId
                          ? 54
                          : 40,
                      child: StopBoxMarker(
                        key: ValueKey('stop-marker-${stop.stop.orden}'),
                        delivered: stop.delivered,
                        active: stop.id == activeId,
                        selected: stop.id == _selectedId,
                        semanticLabel:
                            'Parada ${stop.stop.orden}, ${stop.delivered
                                ? 'entregada'
                                : stop.id == activeId
                                ? 'actual'
                                : 'pendiente'}, ${stop.stop.pedido.clienteNombre}',
                        onTap: () => _select(stop),
                      ),
                    ),
                  if (widget.myLocation != null)
                    Marker(
                      point: LatLng(
                        widget.myLocation!.latitude,
                        widget.myLocation!.longitude,
                      ),
                      width: 60,
                      height: 60,
                      child: const DriverMarker(),
                    ),
                ],
              ),
              if (RouteMap.tilesEnabled)
                const SimpleAttributionWidget(
                  source: Text('OpenStreetMap contributors'),
                ),
            ],
          ),
        ),
        Positioned(
          left: 12,
          right: 12,
          top: 12,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _Legend(
                stops: stops,
                note: _roadLoading
                    ? 'Trazando el camino por las calles…'
                    : (widget.router != null &&
                          stops.length >= 2 &&
                          _road == null)
                    ? 'No se pudo trazar por calles: se muestra en línea recta.'
                    : null,
              ),
              // Sin ubicación: dice por qué y ofrece activarla aquí mismo.
              if (widget.myLocation == null && widget.gpsState != null) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withAlpha(240),
                    borderRadius: BorderRadius.circular(18),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x26000000),
                        blurRadius: 12,
                        offset: Offset(0, 4),
                      ),
                    ],
                  ),
                  child: GpsStatus(
                    state: widget.gpsState!,
                    onOpenSettings: widget.onOpenSettings,
                    onEnable: widget.onEnableLocation,
                  ),
                ),
              ],
            ],
          ),
        ),
        Positioned(
          right: 12,
          bottom: selected == null ? 28 : 210,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _MapButton(
                icon: Icons.zoom_out_map_rounded,
                tooltip: 'Ver toda la ruta',
                onPressed: _fitAll,
              ),
              const SizedBox(height: 10),
              _MapButton(
                icon: Icons.my_location_rounded,
                tooltip: widget.myLocation == null
                    ? 'Activar mi ubicación'
                    : 'Centrar en mi ubicación',
                // Sin ubicación el botón la pide en vez de quedar apagado.
                onPressed: widget.myLocation != null
                    ? _centerOnMe
                    : widget.onEnableLocation,
              ),
            ],
          ),
        ),
        if (selected != null)
          Positioned(
            left: 12,
            right: 12,
            bottom: 12,
            child: _SelectedStopCard(
              stop: selected,
              onClose: () => setState(() => _selectedId = null),
              onCall: widget.onCall == null
                  ? null
                  : () => widget.onCall!(selected.stop),
              onWhatsapp: widget.onWhatsapp == null
                  ? null
                  : () => widget.onWhatsapp!(selected.stop),
            ),
          ),
      ],
    );
  }

  /// Camino por calles partido en lo ya recorrido y lo que falta. Sin camino
  /// por calles, líneas rectas entre paradas (punteadas lo que falta).
  List<Polyline> _polylines(List<MapStop> stops) {
    final lastDone = stops.lastIndexWhere((s) => s.delivered);
    final road = _road;
    if (road != null) {
      final parts = lastDone < 0
          ? (before: const <LatLng>[], after: road)
          : splitPathAt(road, stops[lastDone].point);
      return [
        if (parts.after.length >= 2)
          Polyline(
            points: parts.after,
            strokeWidth: 6,
            color: AppColors.brandBright,
            borderStrokeWidth: 2,
            borderColor: Colors.white,
          ),
        if (parts.before.length >= 2)
          Polyline(
            points: parts.before,
            strokeWidth: 6,
            color: AppColors.done,
            borderStrokeWidth: 2,
            borderColor: Colors.white,
          ),
      ];
    }
    final donePath = lastDone >= 1
        ? [for (final s in stops.sublist(0, lastDone + 1)) s.point]
        : const <LatLng>[];
    final remainingStart = lastDone < 0 ? 0 : lastDone;
    final remainingPath = stops.length - remainingStart >= 2
        ? [for (final s in stops.sublist(remainingStart)) s.point]
        : const <LatLng>[];
    return [
      if (donePath.length >= 2)
        Polyline(points: donePath, strokeWidth: 5, color: AppColors.done),
      if (remainingPath.length >= 2)
        Polyline(
          points: remainingPath,
          strokeWidth: 4,
          color: AppColors.brandBright,
          pattern: StrokePattern.dashed(segments: const [12, 9]),
        ),
    ];
  }
}

/// Leyenda arriba del mapa: qué significa cada marca y cuántas faltan.
class _Legend extends StatelessWidget {
  const _Legend({required this.stops, this.note});

  final List<MapStop> stops;

  /// Aviso sobre el trazado (cargando o sin calles), si hace falta.
  final String? note;

  @override
  Widget build(BuildContext context) {
    final done = stops.where((s) => s.delivered).length;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withAlpha(240),
        borderRadius: BorderRadius.circular(18),
        boxShadow: const [
          BoxShadow(
            color: Color(0x26000000),
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Wrap(
            spacing: 16,
            runSpacing: 6,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(
                '$done de ${stops.length} entregadas',
                style: AppText.bodySmall.copyWith(
                  fontWeight: FontWeight.w700,
                  color: AppColors.ink,
                ),
              ),
              const _LegendItem(color: AppColors.done, label: 'Entregada'),
              const _LegendItem(color: AppColors.brandBright, label: 'Actual'),
              const _LegendItem(
                color: AppColors.surface,
                border: AppColors.brand,
                label: 'Pendiente',
              ),
            ],
          ),
          if (note != null) ...[
            const SizedBox(height: 6),
            Text(
              note!,
              style: AppText.label.copyWith(
                color: AppColors.grey,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _LegendItem extends StatelessWidget {
  const _LegendItem({required this.color, required this.label, this.border});

  final Color color;
  final Color? border;
  final String label;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Container(
        width: 14,
        height: 14,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: Border.all(color: border ?? color, width: 2),
        ),
      ),
      const SizedBox(width: 6),
      Text(label, style: AppText.label.copyWith(color: AppColors.grey)),
    ],
  );
}

class _MapButton extends StatelessWidget {
  const _MapButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) => Material(
    color: Colors.white,
    elevation: 3,
    shape: const CircleBorder(),
    child: IconButton(
      tooltip: tooltip,
      onPressed: onPressed,
      iconSize: 24,
      style: IconButton.styleFrom(
        minimumSize: const Size(48, 48),
        foregroundColor: AppColors.brand,
      ),
      icon: Icon(icon),
    ),
  );
}

class _SelectedStopCard extends StatelessWidget {
  const _SelectedStopCard({
    required this.stop,
    required this.onClose,
    required this.onCall,
    required this.onWhatsapp,
  });

  final MapStop stop;
  final VoidCallback onClose;
  final VoidCallback? onCall;
  final VoidCallback? onWhatsapp;

  @override
  Widget build(BuildContext context) {
    final order = stop.stop.pedido;
    final status = stop.delivered ? AppStatus.done : AppStatus.pending;
    final phone = order.clienteTelefono.trim();
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 8, 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(24),
        boxShadow: const [
          BoxShadow(
            color: Color(0x33000000),
            blurRadius: 18,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Expanded(
                child: Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(
                      'Parada ${stop.stop.orden}',
                      style: AppText.label.copyWith(color: AppColors.grey),
                    ),
                    StatusChip(
                      status: status,
                      label: stop.delivered ? 'Entregada' : 'Pendiente',
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Cerrar',
                onPressed: onClose,
                icon: const Icon(Icons.close_rounded),
              ),
            ],
          ),
          Text(order.clienteNombre, style: AppText.headline),
          const SizedBox(height: 2),
          Text(
            order.direccion,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: AppText.bodySmall.copyWith(color: AppColors.grey),
          ),
          const SizedBox(height: 6),
          Text(
            [
              shortTime(order.horaEntrega),
              if (phone.isNotEmpty) phone,
            ].join('   '),
            style: AppText.bodySmall.copyWith(
              fontWeight: FontWeight.w700,
              color: AppColors.ink,
            ),
          ),
          if (!stop.delivered && (onCall != null || onWhatsapp != null)) ...[
            const SizedBox(height: 10),
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: phone.isEmpty ? null : onCall,
                      icon: const Icon(Icons.call_rounded, size: 20),
                      label: const Text('Llamar'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: whatsappUri(phone) == null ? null : onWhatsapp,
                      icon: const Icon(Icons.chat_rounded, size: 20),
                      label: const Text('WhatsApp'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
