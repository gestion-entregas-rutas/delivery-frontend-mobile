import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../auth/auth_controller.dart';
import '../data/api/logistica_repository.dart';
import '../data/routing/road_router.dart';
import '../location/gps_service.dart';
import '../models/logistica_models.dart';
import '../settings/device_settings.dart';
import '../state/driver_controller.dart';
import '../theme/app_colors.dart';
import '../theme/app_text.dart';
import '../theme/app_theme.dart';
import '../utils/route_day.dart';
import '../utils/contact.dart';
import '../widgets/primary_button.dart';
import '../widgets/route/current_stop_card.dart';
import '../widgets/route/empty_state.dart';
import '../widgets/route/gps_status.dart';
import '../widgets/route/inline_notice.dart';
import '../widgets/route/route_header.dart';
import '../widgets/route/route_map.dart';
import '../widgets/route/stop_row.dart';
import '../widgets/route_node_tile.dart';
import '../widgets/settings/setting_tile.dart';
import '../widgets/status_chip.dart';
import 'login_screen.dart';
import 'stop_route_screen.dart';

// AppColors vive en theme/; se reexporta para no cambiar todos los imports.
export '../theme/app_colors.dart';

const String kAppName = 'RutaExpress';

/// A partir de este ancho la ruta se muestra en dos columnas.
const double kWideBreakpoint = 840;

/// Lo que hace el botón fijo de abajo según el estado de la ruta.
class _RouteAction {
  const _RouteAction({
    required this.label,
    required this.icon,
    required this.onPressed,
    this.loading = false,
  });

  final String label;
  final IconData icon;
  final VoidCallback? onPressed;
  final bool loading;
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({
    super.key,
    required this.repository,
    required this.driverId,
    this.controller,
    this.auth,
    this.router,
    this.deviceSettings,
  });

  final LogisticaRepository repository;
  final String driverId;
  final DriverController? controller;
  final AuthController? auth;

  /// Traza caminos por calles. Si no se da, se usa el OSRM público.
  final RoadRouter? router;

  /// Ajustes del teléfono (GPS, precisión, notificaciones) que se manejan desde
  /// Perfil. Si no se da, se usan los del sistema.
  final DeviceSettingsController? deviceSettings;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  late final DriverController _controller =
      widget.controller ??
      DriverController(
        repository: widget.repository,
        driverId: widget.driverId,
        closeApiClient: widget.auth == null,
        validateSession: widget.auth?.validateCurrentSession,
      );

  /// 0 = Ruta, 1 = Mapa, 2 = Perfil.
  int _navIndex = 0;

  late final RoadRouter _router = widget.router ?? OsrmRoadRouter();
  late final DeviceSettingsController _settings =
      widget.deviceSettings ?? DeviceSettingsController();

  // Para llevar la vista hasta la parada actual al abrir la ruta.
  final GlobalKey _activeKey = GlobalKey();
  String? _scrolledTo;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    unawaited(_controller.initialize());
    unawaited(_settings.refresh());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _controller.onResumed();
      // Pudo haber cambiado algo en los ajustes del teléfono.
      unawaited(_settings.refresh());
    } else {
      _controller.onPaused();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    if (widget.controller == null) _controller.dispose();
    if (widget.router == null) (_router as OsrmRoadRouter).close();
    if (widget.deviceSettings == null) _settings.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------- acciones

  void _snack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _logout() async {
    if (widget.auth != null) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Cerrar sesión'),
          content: const Text(
            'Se cerrarán todas las sesiones de tu cuenta, también en otros dispositivos. ¿Deseas continuar?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Cerrar sesión'),
            ),
          ],
        ),
      );
      if (confirmed != true || !mounted) return;
    }
    await _controller.logout();
    if (widget.auth != null) {
      await widget.auth!.logout();
      return;
    }
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute<void>(builder: (_) => const LoginScreen()),
      (_) => false,
    );
  }

  Future<void> _selectDate() async {
    final current =
        DateTime.tryParse(_controller.selectedDate) ?? DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: current,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked != null) await _controller.changeDate(picked);
  }

  Future<void> _startRoute() async {
    final blocked = _controller.startBlockedReason;
    if (blocked != null) {
      _snack(blocked);
      return;
    }
    final accepted = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Ubicación durante la ruta'),
        content: const Text(
          'Mientras la ruta esté activa, la app usa tu ubicación para el seguimiento de tus entregas.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Ahora no'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Iniciar ruta'),
          ),
        ],
      ),
    );
    if (accepted == true) await _controller.startRoute();
  }

  Future<void> _call(String phone) async {
    final uri = Uri(scheme: 'tel', path: phone);
    try {
      if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
        _snack('No se pudo abrir el marcador.');
      }
    } on Exception {
      _snack('No se pudo abrir el marcador.');
    }
  }

  /// Abre un chat de WhatsApp con el cliente, con un saludo ya escrito.
  Future<void> _whatsapp(ParadaDto stop) async {
    final order = stop.pedido;
    final uri = whatsappUri(
      order.clienteTelefono,
      message:
          'Hola ${order.clienteNombre}, soy tu repartidor de RutaExpress. Te escribo sobre tu entrega.',
    );
    if (uri == null) {
      _snack('El teléfono de este cliente no sirve para WhatsApp.');
      return;
    }
    try {
      if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
        _snack('No se pudo abrir WhatsApp. ¿Está instalado?');
      }
    } on Exception {
      _snack('No se pudo abrir WhatsApp. ¿Está instalado?');
    }
  }

  /// Abre la ruta hasta esa parada en una pantalla propia (sin salir de la
  /// app): camino por calles desde tu posición, distancia, tiempo e Iniciar.
  void _openStopRoute(ParadaDto stop) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => StopRouteScreen(
          stop: stop,
          controller: _controller,
          router: _router,
          onCall: () => _call(stop.pedido.clienteTelefono),
          onWhatsapp: () => _whatsapp(stop),
        ),
      ),
    );
  }

  Future<void> _confirmDelivery(ParadaDto stop) async {
    final order = stop.pedido;
    final items = parseStopItems(order.detalles);
    // Una casilla por artículo (o una general si no hay detalle). Se crea
    // fuera del builder para que no se reinicie al abrir el teclado.
    final checks = List<bool>.filled(items.isEmpty ? 1 : items.length, true);
    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => SafeArea(
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              20,
              0,
              20,
              20 + MediaQuery.of(context).viewInsets.bottom,
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text('Confirmar entrega', style: AppText.title),
                  const SizedBox(height: 6),
                  Text(
                    '¿Confirmas la entrega a ${order.clienteNombre}?',
                    style: AppText.body.copyWith(
                      fontWeight: FontWeight.w700,
                      color: AppColors.ink,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Parada ${stop.orden} · ${order.direccion}',
                    style: AppText.bodySmall.copyWith(color: AppColors.grey),
                  ),
                  const SizedBox(height: 12),
                  if (items.isEmpty)
                    CheckboxListTile(
                      value: checks[0],
                      onChanged: (v) =>
                          setModalState(() => checks[0] = v ?? false),
                      controlAffinity: ListTileControlAffinity.leading,
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Paquetes entregados al destinatario'),
                    )
                  else
                    for (var i = 0; i < items.length; i++)
                      CheckboxListTile(
                        value: checks[i],
                        onChanged: (v) =>
                            setModalState(() => checks[i] = v ?? false),
                        controlAffinity: ListTileControlAffinity.leading,
                        contentPadding: EdgeInsets.zero,
                        title: Text(items[i]),
                      ),
                  const SizedBox(height: 4),
                  Text(
                    'Marca cada paquete que entregaste.',
                    style: AppText.bodySmall.copyWith(color: AppColors.grey),
                  ),
                  const SizedBox(height: 16),
                  PrimaryButton(
                    label: 'Confirmar entrega',
                    icon: Icons.check_circle_rounded,
                    onPressed: checks.every((c) => c)
                        ? () => Navigator.pop(context, true)
                        : null,
                  ),
                  const SizedBox(height: 4),
                  TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: const Text('Volver'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    if (confirmed == true) await _controller.confirmDelivery(order.id);
  }

  // ------------------------------------------------------------------ estado

  ParadaDto? _activeStop(RutaDto route) {
    for (final stop in route.paradas) {
      if (stop.pedido.estado != 'Entregado') return stop;
    }
    return null;
  }

  bool _canAct(RutaDto route) =>
      _controller.loadState == DriverLoadState.loaded &&
      !_controller.isBusy &&
      !_controller.uncertainMutation &&
      route.estado == 'EnCurso';

  /// El botón fijo de abajo: siempre hay a lo sumo uno por estado.
  _RouteAction? _actionFor(RutaDto? route) {
    if (route == null) return null;
    final busy = _controller.isBusy;
    if (route.estado == 'Planificada') {
      // Una ruta de mañana (o de un día que ya pasó) no se puede iniciar hoy.
      final canStart =
          _controller.loadState == DriverLoadState.loaded &&
          !busy &&
          !_controller.uncertainMutation &&
          route.paradas.isNotEmpty &&
          _controller.startBlockedReason == null;
      return _RouteAction(
        label: route.paradas.isEmpty ? 'Sin paradas' : 'Iniciar ruta',
        icon: Icons.play_arrow_rounded,
        onPressed: canStart ? _startRoute : null,
        loading: busy,
      );
    }
    final active = _activeStop(route);
    if (route.estado != 'EnCurso' || active == null) return null;
    final order = active.pedido;
    if (order.estado == 'AsignadoARuta') {
      return _RouteAction(
        label: 'Voy en camino',
        icon: Icons.directions_run_rounded,
        onPressed: _canAct(route)
            ? () => _controller.markEnCamino(order.id)
            : null,
        loading: busy,
      );
    }
    if (order.estado == 'EnCamino') {
      return _RouteAction(
        label: 'Confirmar entrega',
        icon: Icons.check_circle_rounded,
        onPressed: _canAct(route) ? () => _confirmDelivery(active) : null,
        loading: busy,
      );
    }
    return null;
  }

  /// "Hoy · 2026-11-18", "Mañana · 2026-11-19", "Ayer · 2026-11-17" o solo la
  /// fecha si es otro día.
  String _dateLabel() {
    final date = _controller.selectedDate;
    final relative = relativeDayLabel(date, _controller.now);
    return relative == null ? date : '$relative · $date';
  }

  // ------------------------------------------------------------------- build

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _controller,
    builder: (context, _) {
      final wide = MediaQuery.sizeOf(context).width >= kWideBreakpoint;
      final route = _controller.route;
      final action = _navIndex == 0 ? _actionFor(route) : null;
      return AnnotatedRegion<SystemUiOverlayStyle>(
        // Fondo claro: iconos oscuros en la barra de estado.
        value: const SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.dark,
          statusBarBrightness: Brightness.light,
        ),
        child: Scaffold(
          backgroundColor: AppColors.paper,
          body: SafeArea(
            bottom: false,
            child: switch (_navIndex) {
              1 => _mapTab(),
              2 => _profile(),
              _ => _routeTab(wide, action),
            },
          ),
          bottomNavigationBar: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (action != null && !wide) _actionBar(action),
              NavigationBar(
                selectedIndex: _navIndex,
                onDestinationSelected: (index) {
                  setState(() => _navIndex = index);
                  if (index == 2) unawaited(_settings.refresh());
                },
                destinations: const [
                  NavigationDestination(
                    icon: Icon(Icons.route_outlined),
                    selectedIcon: Icon(
                      Icons.route_rounded,
                      color: AppColors.brand,
                    ),
                    label: 'Ruta',
                  ),
                  NavigationDestination(
                    icon: Icon(Icons.map_outlined),
                    selectedIcon: Icon(
                      Icons.map_rounded,
                      color: AppColors.brand,
                    ),
                    label: 'Mapa',
                  ),
                  NavigationDestination(
                    icon: Icon(Icons.person_outline_rounded),
                    selectedIcon: Icon(
                      Icons.person_rounded,
                      color: AppColors.brand,
                    ),
                    label: 'Perfil',
                  ),
                ],
              ),
            ],
          ),
        ),
      );
    },
  );

  /// Barra fija sobre la navegación: queda al alcance del pulgar.
  Widget _actionBar(_RouteAction action) => DecoratedBox(
    decoration: const BoxDecoration(
      color: AppColors.surface,
      border: Border(top: BorderSide(color: AppColors.border)),
    ),
    child: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: AppTheme.maxContentWidth),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
          child: PrimaryButton(
            label: action.label,
            icon: action.icon,
            loading: action.loading,
            onPressed: action.onPressed,
          ),
        ),
      ),
    ),
  );

  /// Mapa global de la ruta: todas las paradas en un solo mapa.
  Widget _mapTab() {
    final route = _controller.route;
    final hasStops = mapStopsOf(route).isNotEmpty;
    if (!hasStops) {
      return const EmptyState(
        icon: Icons.map_outlined,
        title: 'Sin paradas para mostrar',
        message:
            'Cuando tengas una ruta con paradas, las verás todas juntas aquí.',
      );
    }
    return RouteMap(
      // Un mapa por ruta: al cambiar de ruta se vuelve a encuadrar todo.
      key: ValueKey(route?.id),
      route: route,
      router: _router,
      myLocation: _controller.latestGpsSample,
      gpsState: _controller.gpsState,
      onEnableLocation: _controller.enableLocationPreview,
      onOpenSettings: _controller.gps.openSettings,
      onCall: (stop) => _call(stop.pedido.clienteTelefono),
      onWhatsapp: _whatsapp,
    );
  }

  Widget _routeTab(bool wide, _RouteAction? action) {
    final route = _controller.route;
    final done = route?.completedCount ?? 0;
    final total = route?.paradas.length ?? 0;
    final active = route == null ? null : _activeStop(route);
    final inProgress = route?.estado == 'EnCurso';
    _scrollToActive(wide ? null : (inProgress ? active : null));

    final top = <Widget>[
      RouteHeader(
        dateLabel: _dateLabel(),
        done: done,
        total: total,
        busy: _controller.isBusy,
        onChangeDate: _selectDate,
        onRefresh: _controller.refresh,
      ),
      const SizedBox(height: 14),
      // Mientras el GPS está en reposo no hay nada que decir: se omite.
      if (_controller.gpsState != GpsState.stopped) ...[
        GpsStatus(
          state: _controller.gpsState,
          onOpenSettings: _controller.gps.openSettings,
          onEnable: _controller.enableLocationPreview,
        ),
        const SizedBox(height: 14),
      ],
      if (_controller.realtimeError != null)
        InlineNotice(
          status: AppStatus.warning,
          message: _controller.realtimeError!,
          actionLabel: 'Reintentar',
          onAction: _controller.retryRealtime,
        ),
      if (_controller.error != null)
        InlineNotice(
          status: AppStatus.error,
          message: _controller.error!.message,
          actionLabel: 'Actualizar',
          onAction: _controller.refresh,
        ),
      // Ruta de otro día: se puede ver, pero no iniciar. Dice por qué y ofrece
      // ir a la de hoy.
      if (_controller.startBlockedReason != null)
        InlineNotice(
          status: AppStatus.warning,
          message: _controller.startBlockedReason!,
          actionLabel: 'Ir a hoy',
          onAction: () => _controller.changeDate(_controller.now),
        ),
      if (_controller.uncertainMutation && _controller.error == null)
        InlineNotice(
          status: AppStatus.warning,
          message: 'No pudimos confirmar el último cambio. Actualiza para ver cómo quedó.',
          actionLabel: 'Actualizar',
          onAction: _controller.refresh,
        ),
    ];

    final Widget content;
    if (_controller.loadState == DriverLoadState.loading && route == null) {
      content = const Padding(
        padding: EdgeInsets.symmetric(vertical: 64),
        child: Center(child: CircularProgressIndicator()),
      );
    } else if (_controller.loadState == DriverLoadState.empty) {
      content = EmptyState(
        icon: Icons.inventory_2_outlined,
        title: 'Sin entregas asignadas',
        message: 'Cuando te asignen una ruta aparecerá aquí.',
        actionLabel: 'Actualizar',
        onAction: _controller.refresh,
      );
    } else if (route == null) {
      content = _controller.loadState == DriverLoadState.error
          ? EmptyState(
              icon: Icons.cloud_off_rounded,
              title: 'No pudimos cargar tu ruta',
              message: 'Revisa tu conexión e inténtalo de nuevo.',
              actionLabel: 'Reintentar',
              onAction: _controller.refresh,
            )
          : const SizedBox.shrink();
    } else if (wide) {
      content = _wideRoute(route, active, inProgress, action);
    } else {
      content = _timeline(route, active, inProgress, compactActive: false);
    }

    return RefreshIndicator(
      onRefresh: _controller.refresh,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: wide ? 1040 : AppTheme.maxContentWidth,
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
              child: wide && route != null && content is! EmptyState
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [...top, content],
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [...top, content],
                    ),
            ),
          ),
        ),
      ),
    );
  }

  /// Lleva la vista a la parada actual una vez por parada, para que al abrir
  /// la ruta no haya que desplazarse para encontrarla.
  void _scrollToActive(ParadaDto? active) {
    final id = active?.pedido.id;
    if (id == null || id == _scrolledTo) return;
    _scrolledTo = id;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final context = _activeKey.currentContext;
      if (!mounted || context == null) return;
      Scrollable.ensureVisible(
        context,
        alignment: 0.02,
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeOutCubic,
      );
    });
  }

  /// La línea de ruta: todas las paradas unidas, con la actual expandida.
  Widget _timeline(
    RutaDto route,
    ParadaDto? active,
    bool inProgress, {
    required bool compactActive,
  }) {
    final total = route.paradas.length;
    final finished = total > 0 && route.completedCount == total;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (finished) _finishedBanner(total),
        for (var i = 0; i < total; i++)
          _timelineTile(
            route,
            route.paradas[i],
            index: i,
            total: total,
            isActive: inProgress && route.paradas[i] == active,
            compactActive: compactActive,
          ),
      ],
    );
  }

  Widget _timelineTile(
    RutaDto route,
    ParadaDto stop, {
    required int index,
    required int total,
    required bool isActive,
    required bool compactActive,
  }) {
    final delivered = stop.pedido.estado == 'Entregado';
    final status = delivered
        ? AppStatus.done
        : isActive
        ? AppStatus.active
        : AppStatus.pending;
    return RouteNodeTile(
      key: isActive && !compactActive ? _activeKey : null,
      status: status,
      number: stop.orden,
      isFirst: index == 0,
      isLast: index == total - 1,
      child: isActive && !compactActive
          ? CurrentStopCard(
              stop: stop,
              onCall: () => _call(stop.pedido.clienteTelefono),
              onWhatsapp: () => _whatsapp(stop),
              onShowMap: () => _openStopRoute(stop),
            )
          : StopRow(stop: stop),
    );
  }

  /// Pantallas anchas: lista a la izquierda, parada actual y acción a la
  /// derecha.
  Widget _wideRoute(
    RutaDto route,
    ParadaDto? active,
    bool inProgress,
    _RouteAction? action,
  ) {
    final showActive = inProgress && active != null;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          flex: 5,
          child: _timeline(route, active, inProgress, compactActive: true),
        ),
        const SizedBox(width: 28),
        Expanded(
          flex: 6,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (showActive)
                CurrentStopCard(
                  stop: active,
                  onCall: () => _call(active.pedido.clienteTelefono),
                  onWhatsapp: () => _whatsapp(active),
                  onShowMap: () => _openStopRoute(active),
                ),
              if (action != null) ...[
                const SizedBox(height: 16),
                PrimaryButton(
                  label: action.label,
                  icon: action.icon,
                  loading: action.loading,
                  onPressed: action.onPressed,
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _finishedBanner(int total) => Container(
    margin: const EdgeInsets.only(bottom: 16),
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: AppColors.doneSoft,
      borderRadius: BorderRadius.circular(20),
    ),
    child: Row(
      children: [
        const Icon(Icons.check_circle_rounded, size: 32),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            'Ruta completada: $total entregas',
            style: AppText.headline.copyWith(color: AppColors.ink),
          ),
        ),
      ],
    ),
  );

  // ------------------------------------------------------------------ perfil

  /// Configuración del teléfono: ubicación, ubicación precisa y notificaciones.
  /// Cada ajuste dice cómo está y, si hace falta, tiene su botón para arreglarlo
  /// sin salir a buscar en otra parte.
  Widget _settingsSection() => AnimatedBuilder(
    animation: _settings,
    builder: (context, _) {
      final st = _settings.state;

      final SettingTile gps;
      if (!st.loaded) {
        gps = _tile(
          icon: Icons.location_on_rounded,
          title: 'Ubicación (GPS)',
          description:
              'Para ver tu posición y trazar el camino hasta el cliente.',
          status: 'Comprobando…',
          ok: true,
        );
      } else if (st.locationServiceOn == false) {
        gps = _tile(
          icon: Icons.location_off_rounded,
          title: 'Ubicación (GPS)',
          description:
              'Para ver tu posición y trazar el camino hasta el cliente.',
          status: 'Apagada en el teléfono',
          ok: false,
          button: 'Activar',
          key: DeviceSettingsController.gps,
          action: _settings.enableGps,
        );
      } else if (st.locationBlocked) {
        gps = _tile(
          icon: Icons.location_off_rounded,
          title: 'Ubicación (GPS)',
          description:
              'Para ver tu posición y trazar el camino hasta el cliente.',
          status: 'Bloqueada para la app',
          ok: false,
          button: 'Ajustes',
          key: DeviceSettingsController.gps,
          action: _settings.enableGps,
        );
      } else if (!st.hasLocationPermission) {
        gps = _tile(
          icon: Icons.location_off_rounded,
          title: 'Ubicación (GPS)',
          description:
              'Para ver tu posición y trazar el camino hasta el cliente.',
          status: 'Sin permiso',
          ok: false,
          button: 'Permitir',
          key: DeviceSettingsController.gps,
          action: _settings.enableGps,
        );
      } else {
        gps = _tile(
          icon: Icons.location_on_rounded,
          title: 'Ubicación (GPS)',
          description:
              'Para ver tu posición y trazar el camino hasta el cliente.',
          status: 'Activada',
          ok: true,
        );
      }

      const precisionTitle = 'Ubicación precisa';
      const precisionText = 'Hace que el camino y la distancia sean exactos.';
      final SettingTile precision;
      if (!st.loaded) {
        precision = _tile(
          icon: Icons.my_location_rounded,
          title: precisionTitle,
          description: precisionText,
          status: 'Comprobando…',
          ok: true,
        );
      } else if (!st.hasLocationPermission) {
        precision = _tile(
          icon: Icons.my_location_rounded,
          title: precisionTitle,
          description: precisionText,
          status: 'Requiere el permiso de ubicación',
          ok: false,
          button: st.locationBlocked ? 'Ajustes' : 'Permitir',
          key: DeviceSettingsController.precision,
          action: _settings.enablePrecision,
        );
      } else if (st.precision == LocationPrecision.approximate) {
        precision = _tile(
          icon: Icons.my_location_rounded,
          title: precisionTitle,
          description: precisionText,
          status: 'Aproximada',
          ok: false,
          button: 'Activar',
          key: DeviceSettingsController.precision,
          action: _settings.enablePrecision,
        );
      } else if (st.precision == LocationPrecision.precise) {
        precision = _tile(
          icon: Icons.my_location_rounded,
          title: precisionTitle,
          description: precisionText,
          status: 'Activada',
          ok: true,
        );
      } else {
        precision = _tile(
          icon: Icons.my_location_rounded,
          title: precisionTitle,
          description: precisionText,
          status: 'No disponible en este teléfono',
          ok: true,
        );
      }

      const notifTitle = 'Notificaciones';
      const notifText = 'Avisos de la app en este teléfono.';
      final SettingTile notifications = switch (st.notifications) {
        NotificationsState.granted => _tile(
          icon: Icons.notifications_active_rounded,
          title: notifTitle,
          description: notifText,
          status: 'Activadas',
          ok: true,
        ),
        NotificationsState.denied => _tile(
          icon: Icons.notifications_off_rounded,
          title: notifTitle,
          description: notifText,
          status: 'Desactivadas',
          ok: false,
          button: 'Activar',
          key: DeviceSettingsController.notifications,
          action: _settings.enableNotifications,
        ),
        NotificationsState.blocked => _tile(
          icon: Icons.notifications_off_rounded,
          title: notifTitle,
          description: notifText,
          status: 'Bloqueadas para la app',
          ok: false,
          button: 'Ajustes',
          key: DeviceSettingsController.notifications,
          action: _settings.enableNotifications,
        ),
        NotificationsState.unknown => _tile(
          icon: Icons.notifications_none_rounded,
          title: notifTitle,
          description: notifText,
          status: st.loaded ? 'No disponible' : 'Comprobando…',
          ok: true,
        ),
      };

      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Configuración', style: AppText.headline),
          const SizedBox(height: 10),
          SettingsCard(children: [gps, precision, notifications]),
          const SizedBox(height: 10),
          Text(
            'Tu ubicación solo se comparte con la central mientras tu ruta está en curso.',
            style: AppText.bodySmall.copyWith(color: AppColors.grey),
          ),
        ],
      );
    },
  );

  SettingTile _tile({
    required IconData icon,
    required String title,
    required String description,
    required String status,
    required bool ok,
    String? button,
    String? key,
    VoidCallback? action,
  }) => SettingTile(
    icon: icon,
    title: title,
    description: description,
    statusLabel: status,
    statusOk: ok,
    buttonLabel: button,
    onPressed: action,
    loading: key != null && _settings.busy.contains(key),
  );

  Widget _profile() {
    final name = widget.auth?.user?.nombreUsuario ?? 'Repartidor';
    final initial = name.trim().isEmpty ? 'R' : name.trim()[0].toUpperCase();
    return SingleChildScrollView(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: AppTheme.maxContentWidth),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text('Perfil', style: AppText.title),
                const SizedBox(height: 20),
                Row(
                  children: [
                    CircleAvatar(
                      radius: 32,
                      backgroundColor: AppColors.brand,
                      child: Text(
                        initial,
                        style: AppText.title.copyWith(color: Colors.white),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(name, style: AppText.headline),
                          Text(
                            'Repartidor',
                            style: AppText.body.copyWith(color: AppColors.grey),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                _settingsSection(),
                const SizedBox(height: 24),
                OutlinedButton.icon(
                  onPressed: _controller.isBusy ? null : _logout,
                  icon: const Icon(Icons.logout_rounded),
                  label: const Text('Cerrar sesión'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
