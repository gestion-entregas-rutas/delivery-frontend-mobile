import 'dart:async';

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../auth/auth_controller.dart';
import '../data/api/api_exception.dart';
import '../data/api/logistica_repository.dart';
import '../location/gps_service.dart';
import '../models/logistica_models.dart';
import '../state/driver_controller.dart';
import 'login_screen.dart';

class AppColors {
  static const canvas = Color(0xFFF5F5F7);
  static const surface = Color(0xFFFFFFFF);
  static const yellow = Color(0xFFFFC107);
  static const yellowSoft = Color(0xFFFFF4CC);
  static const ink = Color(0xFF111111);
  static const grey = Color(0xFF6E6E73);
  static const border = Color(0xFFE5E5EA);
  static const green = Color(0xFF34C759);
  static const greenSoft = Color(0xFFEAF9EF);
  static const blue = Color(0xFF007AFF);
  static const blueSoft = Color(0xFFE8F2FF);
  static const orange = Color(0xFFFF9500);
  static const orangeSoft = Color(0xFFFFF3E0);
}

const String kAppName = 'RutaExpress';

class HomeScreen extends StatefulWidget {
  const HomeScreen({
    super.key,
    required this.repository,
    required this.driverId,
    this.controller,
    this.auth,
  });

  final LogisticaRepository repository;
  final String driverId;
  final DriverController? controller;
  final AuthController? auth;

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
  int _navIndex = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    unawaited(_controller.initialize());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _controller.onResumed();
    } else {
      _controller.onPaused();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    if (widget.controller == null) _controller.dispose();
    super.dispose();
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
    final accepted = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Ubicación durante la ruta'),
        content: const Text(
          'Mientras la ruta esté activa, la app capturará tu ubicación para apoyar el seguimiento operativo. Si el servidor dispone de endpoint de ubicación, intentará enviarla de forma autenticada.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Ahora no'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Continuar'),
          ),
        ],
      ),
    );
    if (accepted == true) await _controller.startRoute();
  }

  Future<void> _call(String phone) async {
    final uri = Uri(scheme: 'tel', path: phone);
    try {
      if (!await launchUrl(uri, mode: LaunchMode.externalApplication) &&
          mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No se pudo abrir el marcador.')),
        );
      }
    } on Exception {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No se pudo abrir el marcador.')),
        );
      }
    }
  }

  Future<void> _openMap(double latitude, double longitude) async {
    final uri = Uri.https('www.google.com', '/maps/search/', <String, String>{
      'api': '1',
      'query': '$latitude,$longitude',
    });
    try {
      if (!await launchUrl(uri, mode: LaunchMode.externalApplication) &&
          mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No se pudo abrir una app de mapas.')),
        );
      }
    } on Exception {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No se pudo abrir una app de mapas.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _controller,
    builder: (context, _) => Scaffold(
      backgroundColor: AppColors.canvas,
      body: SafeArea(bottom: false, child: _body()),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _navIndex,
        onDestinationSelected: (index) => setState(() => _navIndex = index),
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        indicatorColor: AppColors.yellowSoft,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.route_outlined),
            selectedIcon: Icon(Icons.route_rounded, color: AppColors.ink),
            label: 'Ruta',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person_rounded, color: AppColors.ink),
            label: 'Perfil',
          ),
        ],
      ),
    ),
  );

  Widget _body() {
    if (_navIndex == 1) return _profile();
    return RefreshIndicator(
      onRefresh: _controller.refresh,
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverToBoxAdapter(child: _hero()),
          SliverToBoxAdapter(
            child: Container(
              decoration: const BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                boxShadow: [
                  BoxShadow(
                    color: Color(0x14000000),
                    blurRadius: 20,
                    offset: Offset(0, -4),
                  ),
                ],
              ),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 10, 20, 28),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Center(
                      child: Container(
                        width: 36,
                        height: 5,
                        decoration: BoxDecoration(
                          color: AppColors.border,
                          borderRadius: BorderRadius.circular(99),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    _dateHeader(),
                    const SizedBox(height: 10),
                    if (_controller.realtimeError != null)
                      _warning(_controller.realtimeError!),
                    if (_controller.error != null)
                      _errorCard(_controller.error!),
                    _routeContent(),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _hero() {
    final route = _controller.route;
    final done = route?.completedCount ?? 0;
    final total = route?.paradas.length ?? 0;
    final finished = route != null && total > 0 && done == total;
    final title = route == null
        ? 'Mi ruta del día'
        : finished
        ? '¡Ruta finalizada por hoy!'
        : 'Entrega ${total == 0 ? 0 : (done + 1).clamp(1, total)} de $total';
    final subtitle = route == null
        ? 'Consulta y gestiona tus entregas asignadas.'
        : finished
        ? '$total entregas completadas'
        : '$done de $total entregas completadas';
    return Container(
      height: 320,
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF1C1C1E), Color(0xFF2C2C2E)],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _topBar(),
          const Spacer(),
          if (route != null) _routeDots(route),
          if (route != null) const SizedBox(height: 16),
          Text(
            title,
            style: const TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w800,
              color: Colors.white,
              height: 1.1,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            subtitle,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w500,
              color: Colors.white.withAlpha(210),
            ),
          ),
          const SizedBox(height: 14),
          if (route != null)
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: total == 0 ? 0 : done / total,
                minHeight: 8,
                backgroundColor: Colors.white.withAlpha(35),
                valueColor: const AlwaysStoppedAnimation<Color>(
                  AppColors.yellow,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _topBar() => Row(
    children: [
      const CircleAvatar(
        radius: 20,
        backgroundColor: Color(0x33FFC107),
        child: Icon(Icons.person_rounded, color: Colors.white),
      ),
      const SizedBox(width: 10),
      const Expanded(
        child: Text(
          kAppName,
          style: TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      IconButton(
        tooltip: 'Actualizar',
        onPressed: _controller.isBusy ? null : _controller.refresh,
        icon: const Icon(Icons.refresh_rounded, color: Colors.white),
      ),
    ],
  );

  Widget _routeDots(RutaDto route) {
    final stops = route.paradas;
    final show = stops.take(8).toList();
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (final stop in show) ...[
            _dot(stop),
            if (stop != show.last)
              Container(width: 18, height: 3, color: Colors.white24),
          ],
          if (stops.length > show.length)
            Padding(
              padding: const EdgeInsets.only(left: 8),
              child: Text(
                '+${stops.length - show.length}',
                style: const TextStyle(
                  color: Colors.white70,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _dot(ParadaDto stop) {
    final delivered = stop.pedido.estado == 'Entregado';
    final active = stop.pedido.estado == 'EnCamino';
    final color = delivered
        ? AppColors.green
        : active
        ? AppColors.blue
        : AppColors.yellow;
    return Container(
      width: 34,
      height: 34,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: color.withAlpha(delivered || active ? 255 : 70),
        shape: BoxShape.circle,
        border: Border.all(color: color, width: 2),
      ),
      child: delivered
          ? const Icon(Icons.check, size: 16, color: Colors.white)
          : Text(
              '${stop.orden}',
              style: TextStyle(
                color: active ? Colors.white : Colors.white,
                fontWeight: FontWeight.w800,
                fontSize: 13,
              ),
            ),
    );
  }

  Widget _dateHeader() => Row(
    children: [
      Expanded(
        child: Text(
          'Hoy · ${_controller.selectedDate}',
          style: const TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w700,
            color: AppColors.ink,
          ),
        ),
      ),
      SizedBox(
        height: 48,
        child: OutlinedButton.icon(
          onPressed: _controller.isBusy ? null : _selectDate,
          icon: const Icon(Icons.calendar_today_outlined, size: 18),
          label: const Text('Cambiar'),
        ),
      ),
    ],
  );

  Widget _routeContent() {
    if (_controller.loadState == DriverLoadState.loading &&
        _controller.route == null) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 64),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (_controller.loadState == DriverLoadState.empty) return _emptyRoute();
    final route = _controller.route;
    if (route == null) {
      return _controller.loadState == DriverLoadState.error
          ? _retry()
          : const SizedBox.shrink();
    }

    final done = route.completedCount;
    final total = route.paradas.length;
    final finished = total > 0 && done == total;
    final active = _activeStop(route);
    final canStart =
        route.estado == 'Planificada' &&
        _controller.loadState == DriverLoadState.loaded &&
        !_controller.isBusy &&
        !_controller.uncertainMutation;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _kpis(route),
        const SizedBox(height: 14),
        _gpsStatusBar(),
        const SizedBox(height: 14),
        if (route.estado == 'Planificada')
          _primaryButton(
            icon: Icons.play_arrow_rounded,
            label: route.paradas.isEmpty ? 'Sin paradas' : 'Iniciar ruta',
            color: AppColors.blue,
            onPressed: canStart && route.paradas.isNotEmpty
                ? _startRoute
                : null,
          ),
        if (route.estado == 'EnCurso' && active != null) ...[
          _activeStopCard(active, route),
          const SizedBox(height: 14),
        ],
        if (finished)
          _finishedBanner(total)
        else if (route.estado == 'EnCurso')
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              'Entrega ${done + 1} de $total en curso',
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: AppColors.ink,
              ),
            ),
          ),
        const SizedBox(height: 6),
        ...route.paradas.map(
          (stop) => _stopTile(stop, route, active?.pedido.id),
        ),
      ],
    );
  }

  ParadaDto? _activeStop(RutaDto route) {
    for (final stop in route.paradas) {
      if (stop.pedido.estado != 'Entregado') return stop;
    }
    return null;
  }

  Widget _kpis(RutaDto route) => Row(
    children: [
      Expanded(
        child: _kpi(
          icon: Icons.inventory_2_outlined,
          value: '${route.paradas.length}',
          label: 'Paquetes',
        ),
      ),
      const SizedBox(width: 10),
      Expanded(
        child: _kpi(
          icon: Icons.check_circle_outline,
          value: '${route.completedCount}',
          label: 'Completadas',
        ),
      ),
      const SizedBox(width: 10),
      Expanded(
        child: _kpi(
          icon: Icons.route_outlined,
          value: '${route.paradas.length - route.completedCount}',
          label: 'Pendientes',
        ),
      ),
    ],
  );

  Widget _kpi({
    required IconData icon,
    required String value,
    required String label,
  }) => Container(
    padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
    decoration: BoxDecoration(
      color: AppColors.canvas,
      borderRadius: BorderRadius.circular(16),
    ),
    child: Column(
      children: [
        Icon(icon, color: AppColors.ink, size: 20),
        const SizedBox(height: 6),
        Text(
          value,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: AppColors.ink,
          ),
        ),
        Text(
          label,
          style: const TextStyle(fontSize: 12, color: AppColors.grey),
        ),
      ],
    ),
  );

  Widget _primaryButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback? onPressed,
  }) => SizedBox(
    height: 52,
    child: FilledButton.icon(
      style: FilledButton.styleFrom(
        backgroundColor: color,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
        textStyle: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
      ),
      onPressed: onPressed,
      icon: Icon(icon),
      label: Text(label),
    ),
  );

  Widget _activeStopCard(ParadaDto stop, RutaDto route) {
    final order = stop.pedido;
    final canAct =
        _controller.loadState == DriverLoadState.loaded &&
        !_controller.isBusy &&
        !_controller.uncertainMutation &&
        route.estado == 'EnCurso';
    final isEnCamino = order.estado == 'EnCamino';
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.canvas,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                alignment: Alignment.center,
                decoration: const BoxDecoration(
                  color: AppColors.blue,
                  shape: BoxShape.circle,
                ),
                child: Text(
                  '${stop.orden}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isEnCamino ? 'Parada actual' : 'Siguiente parada',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.grey,
                      ),
                    ),
                    Text(
                      order.clienteNombre,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: AppColors.ink,
                      ),
                    ),
                  ],
                ),
              ),
              _statusChip(order.estado),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            order.direccion,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: AppColors.ink,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '${order.fechaEntrega} · ${order.horaEntrega}',
            style: const TextStyle(fontSize: 13, color: AppColors.grey),
          ),
          if ((order.detalles ?? '').trim().isNotEmpty) ...[
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.sticky_note_2_outlined,
                    size: 18,
                    color: AppColors.ink,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      order.detalles!.trim(),
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: AppColors.ink,
                        height: 1.35,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 48,
                  child: OutlinedButton.icon(
                    onPressed: order.clienteTelefono.isEmpty
                        ? null
                        : () => _call(order.clienteTelefono),
                    icon: const Icon(Icons.phone_outlined),
                    label: const Text('Llamar'),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: SizedBox(
                  height: 48,
                  child: OutlinedButton.icon(
                    onPressed: () => _openMap(
                      order.ubicacion.latitud,
                      order.ubicacion.longitud,
                    ),
                    icon: const Icon(Icons.navigation_outlined),
                    label: const Text('Navegar'),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (canAct && order.estado == 'AsignadoARuta')
            _primaryButton(
              icon: Icons.directions_walk_rounded,
              label: 'En camino',
              color: AppColors.blue,
              onPressed: () => _controller.markEnCamino(order.id),
            ),
          if (canAct && order.estado == 'EnCamino')
            _primaryButton(
              icon: Icons.check_circle_outline,
              label: 'Confirmar entrega',
              color: AppColors.green,
              onPressed: () => _confirmDelivery(stop),
            ),
        ],
      ),
    );
  }

  Future<void> _confirmDelivery(ParadaDto stop) async {
    final order = stop.pedido;
    final items = (order.detalles ?? '')
        .split(RegExp(r'[\n,]'))
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();
    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        final checks = List<bool>.filled(
          items.isEmpty ? 1 : items.length,
          true,
        );
        return StatefulBuilder(
          builder: (context, setModalState) => SafeArea(
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                20,
                10,
                20,
                20 + MediaQuery.of(context).viewInsets.bottom,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Container(
                      width: 36,
                      height: 5,
                      decoration: BoxDecoration(
                        color: AppColors.border,
                        borderRadius: BorderRadius.circular(99),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  const Text(
                    'Confirmar entrega',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '¿Confirmas la entrega a ${order.clienteNombre}?',
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: AppColors.ink,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Parada ${stop.orden} · ${order.direccion}',
                    style: const TextStyle(color: AppColors.grey),
                  ),
                  const SizedBox(height: 14),
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
                    ...List.generate(
                      items.length,
                      (i) => CheckboxListTile(
                        value: checks[i],
                        onChanged: (v) =>
                            setModalState(() => checks[i] = v ?? false),
                        controlAffinity: ListTileControlAffinity.leading,
                        contentPadding: EdgeInsets.zero,
                        title: Text(items[i]),
                      ),
                    ),
                  const SizedBox(height: 8),
                  const Text(
                    'Verifica los paquetes y confirma la entrega.',
                    style: TextStyle(fontSize: 13, color: AppColors.grey),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    height: 52,
                    child: FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.green,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(999),
                        ),
                      ),
                      onPressed: checks.every((c) => c)
                          ? () => Navigator.pop(context, true)
                          : null,
                      child: const Text(
                        'Confirmar entrega',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    height: 48,
                    child: TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text('Volver'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
    if (confirmed == true) await _controller.confirmDelivery(order.id);
  }

  Widget _stopTile(ParadaDto stop, RutaDto route, String? activeId) {
    final order = stop.pedido;
    final isActive = order.id == activeId;
    final delivered = order.estado == 'Entregado';
    if (isActive && route.estado == 'EnCurso') return const SizedBox.shrink();
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: delivered ? AppColors.greenSoft : AppColors.yellowSoft,
              shape: BoxShape.circle,
            ),
            child: delivered
                ? const Icon(Icons.check, size: 18, color: AppColors.green)
                : Text(
                    '${stop.orden}',
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  order.clienteNombre,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: AppColors.ink,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  order.direccion,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 13, color: AppColors.grey),
                ),
              ],
            ),
          ),
          _statusChip(order.estado),
        ],
      ),
    );
  }

  Widget _finishedBanner(int total) => Container(
    margin: const EdgeInsets.only(bottom: 12),
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: AppColors.greenSoft,
      borderRadius: BorderRadius.circular(16),
    ),
    child: Row(
      children: [
        const Icon(Icons.celebration_outlined, color: AppColors.green),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            '¡Ruta finalizada por hoy! $total entregas completadas.',
            style: const TextStyle(
              fontWeight: FontWeight.w700,
              color: AppColors.ink,
            ),
          ),
        ),
      ],
    ),
  );

  Widget _statusChip(String state) {
    final delivered = state == 'Entregado';
    final enRoute = state == 'EnCamino';
    final (color, bg, label) = delivered
        ? (AppColors.green, AppColors.greenSoft, 'Completada')
        : enRoute
        ? (AppColors.blue, AppColors.blueSoft, 'En camino')
        : (const Color(0xFF9A6B00), AppColors.yellowSoft, 'Pendiente');
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }

  Widget _gpsStatusBar() {
    final state = _controller.gpsState;
    final active = state == GpsState.active;
    final attention =
        state == GpsState.serviceDisabled ||
        state == GpsState.permissionDenied ||
        state == GpsState.permissionDeniedForever ||
        state == GpsState.unavailable;
    final label = switch (state) {
      GpsState.active => 'Seguimiento de ubicación activo',
      GpsState.waitingForSample => 'Esperando ubicación válida…',
      GpsState.serviceDisabled => 'Ubicación del teléfono apagada',
      GpsState.permissionDenied => 'Permiso de ubicación denegado',
      GpsState.permissionDeniedForever => 'Permiso bloqueado: revisa Ajustes',
      GpsState.accuracyInsufficient => 'Precisión insuficiente',
      GpsState.unavailable => 'GPS no disponible',
      _ => 'GPS listo al iniciar la ruta',
    };
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: attention ? AppColors.orangeSoft : AppColors.canvas,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Icon(
            active ? Icons.gps_fixed : Icons.gps_not_fixed,
            color: active ? AppColors.green : AppColors.orange,
            size: 20,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.ink,
              ),
            ),
          ),
          if (state == GpsState.serviceDisabled ||
              state == GpsState.permissionDeniedForever)
            SizedBox(
              height: 48,
              child: TextButton(
                onPressed: _controller.gps.openSettings,
                child: const Text('Ajustes'),
              ),
            ),
        ],
      ),
    );
  }

  Widget _emptyRoute() => Padding(
    padding: const EdgeInsets.symmetric(vertical: 48),
    child: Center(
      child: Column(
        children: [
          const Icon(Icons.route_outlined, size: 54, color: AppColors.grey),
          const SizedBox(height: 14),
          const Text(
            'Sin entregas asignadas',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          const Text(
            'Vuelve más tarde o actualiza.',
            style: TextStyle(color: AppColors.grey),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 48,
            child: OutlinedButton.icon(
              onPressed: _controller.refresh,
              icon: const Icon(Icons.refresh),
              label: const Text('Actualizar'),
            ),
          ),
        ],
      ),
    ),
  );

  Widget _retry() => Center(
    child: Padding(
      padding: const EdgeInsets.symmetric(vertical: 40),
      child: SizedBox(
        height: 48,
        child: FilledButton.icon(
          onPressed: _controller.refresh,
          icon: const Icon(Icons.refresh),
          label: const Text('Reintentar'),
        ),
      ),
    ),
  );

  Widget _errorCard(ApiException exception) => Container(
    margin: const EdgeInsets.only(bottom: 12),
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: const Color(0xFFFFEBEE),
      borderRadius: BorderRadius.circular(14),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(Icons.error_outline, color: Colors.red),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            exception.message,
            style: const TextStyle(color: Color(0xFF8B1E2D)),
          ),
        ),
        IconButton(
          onPressed: _controller.refresh,
          icon: const Icon(Icons.refresh),
        ),
      ],
    ),
  );

  Widget _warning(String value) => Container(
    margin: const EdgeInsets.only(bottom: 12),
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: AppColors.orangeSoft,
      borderRadius: BorderRadius.circular(14),
    ),
    child: Row(
      children: [
        const Icon(Icons.sync_problem_outlined, color: AppColors.orange),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
        ),
        SizedBox(
          height: 48,
          child: IconButton(
            tooltip: 'Reintentar tiempo real',
            onPressed: _controller.retryRealtime,
            icon: const Icon(Icons.sync),
          ),
        ),
      ],
    ),
  );

  Widget _profile() => ListView(
    padding: const EdgeInsets.all(20),
    children: [
      const SizedBox(height: 16),
      const CircleAvatar(
        radius: 36,
        backgroundColor: AppColors.yellowSoft,
        child: Icon(Icons.person_rounded, size: 38, color: AppColors.ink),
      ),
      const SizedBox(height: 16),
      const Center(
        child: Text(
          'Configuración',
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
        ),
      ),
      const SizedBox(height: 8),
      Center(
        child: Text(
          _controller.driverId,
          textAlign: TextAlign.center,
          style: const TextStyle(color: AppColors.grey),
        ),
      ),
      const SizedBox(height: 24),
      const Text(
        'La ubicación se captura durante la ruta activa. Si el backend expone un endpoint compatible, la app enviará muestras autenticadas para el seguimiento operativo.',
        style: TextStyle(color: AppColors.grey, height: 1.5),
      ),
      const SizedBox(height: 24),
      SizedBox(
        height: 48,
        child: OutlinedButton.icon(
          onPressed: _controller.isBusy ? null : _logout,
          icon: const Icon(Icons.logout),
          label: const Text('Cerrar sesión'),
        ),
      ),
    ],
  );
}
