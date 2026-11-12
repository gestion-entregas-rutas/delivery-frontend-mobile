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
  static const yellow = Color(0xFFFFC107);
  static const yellowSoft = Color(0xFFFFF4CC);
  static const ink = Color(0xFF111111);
  static const grey = Color(0xFF8A8A8A);
  static const surface = Color(0xFFF3F3F3);
  static const border = Color(0xFFEDEDED);
  static const green = Color(0xFF2E9E5B);
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

  Future<void> _actionFor(String pedidoId) async {
    final route = _controller.route;
    if (route == null) return;
    final stop = route.paradas
        .where((item) => item.pedido.id == pedidoId)
        .firstOrNull;
    if (stop == null) return;
    if (stop.pedido.estado == 'AsignadoARuta') {
      await _controller.markEnCamino(pedidoId);
      return;
    }
    if (stop.pedido.estado == 'EnCamino') {
      final accepted = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Confirmar entrega'),
          content: Text(
            '¿Confirmas la entrega a ${stop.pedido.clienteNombre}?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Confirmar'),
            ),
          ],
        ),
      );
      if (accepted == true) await _controller.confirmDelivery(pedidoId);
    }
  }

  Future<void> _startRoute() async {
    final accepted = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Ubicación durante la ruta'),
        content: const Text(
          'La app puede capturar una vista previa local de tu ubicación mientras la ruta está activa. El contrato para compartir GPS con el backend todavía está pendiente; no se enviará ninguna coordenada.',
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
      backgroundColor: Colors.white,
      body: SafeArea(child: _body()),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _navIndex,
        onDestinationSelected: (index) => setState(() => _navIndex = index),
        backgroundColor: Colors.white,
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
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        children: [
          _header(),
          const SizedBox(height: 18),
          _dateHeader(),
          const SizedBox(height: 12),
          if (_controller.realtimeError != null)
            _warning(_controller.realtimeError!),
          if (_controller.error != null) _errorCard(_controller.error!),
          _routeContent(),
        ],
      ),
    );
  }

  Widget _header() => Row(
    children: [
      const CircleAvatar(
        radius: 24,
        backgroundColor: AppColors.yellowSoft,
        child: Icon(Icons.person_rounded, color: AppColors.ink),
      ),
      const SizedBox(width: 12),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Ruta del repartidor',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: AppColors.ink,
              ),
            ),
            Text(
              _controller.driverId,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 12, color: AppColors.grey),
            ),
          ],
        ),
      ),
      IconButton(
        tooltip: 'Cerrar sesión',
        onPressed: _controller.isBusy ? null : _logout,
        icon: const Icon(Icons.logout_rounded),
      ),
    ],
  );

  Widget _dateHeader() => Row(
    children: [
      Expanded(
        child: Text(
          'Fecha: ${_controller.selectedDate}',
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w800,
            color: AppColors.ink,
          ),
        ),
      ),
      OutlinedButton.icon(
        onPressed: _controller.isBusy ? null : _selectDate,
        icon: const Icon(Icons.calendar_today_outlined, size: 17),
        label: const Text('Cambiar'),
      ),
      IconButton(
        tooltip: 'Actualizar',
        onPressed: _controller.isBusy ? null : _controller.refresh,
        icon: const Icon(Icons.refresh_rounded),
      ),
    ],
  );

  Widget _routeContent() {
    if (_controller.loadState == DriverLoadState.loading &&
        _controller.route == null) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 80),
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _summary(route),
        const SizedBox(height: 14),
        _gpsCard(),
        const SizedBox(height: 22),
        if (route.estado == 'Planificada') _startButton(route),
        const SizedBox(height: 14),
        ...route.paradas.map((stop) => _stopCard(stop, route)),
      ],
    );
  }

  Widget _summary(RutaDto route) {
    final done = route.completedCount;
    final total = route.paradas.length;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.ink,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.yellow,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              route.estado,
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800),
            ),
          ),
          const SizedBox(height: 14),
          Text(
            '$done de $total entregas',
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w800,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Ruta ${route.id}',
            style: TextStyle(fontSize: 12, color: Colors.white.withAlpha(180)),
          ),
          const SizedBox(height: 16),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: total == 0 ? 0 : done / total,
              minHeight: 8,
              backgroundColor: Colors.white.withAlpha(35),
              valueColor: const AlwaysStoppedAnimation<Color>(AppColors.yellow),
            ),
          ),
        ],
      ),
    );
  }

  Widget _startButton(RutaDto route) => FilledButton.icon(
    onPressed:
        _controller.loadState != DriverLoadState.loaded ||
            _controller.isBusy ||
            _controller.uncertainMutation
        ? null
        : _startRoute,
    icon: const Icon(Icons.play_arrow_rounded),
    label: const Text('Iniciar reparto'),
  );

  Widget _stopCard(ParadaDto stop, RutaDto route) {
    final order = stop.pedido;
    final canAct =
        _controller.loadState == DriverLoadState.loaded &&
        !_controller.isBusy &&
        !_controller.uncertainMutation &&
        route.estado == 'EnCurso' &&
        (order.estado == 'AsignadoARuta' || order.estado == 'EnCamino');
    final actionLabel = order.estado == 'AsignadoARuta'
        ? 'En camino'
        : 'Confirmar entrega';
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0F000000),
            blurRadius: 16,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppColors.yellowSoft,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Text(
                  '${stop.orden}',
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                  ),
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
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      order.estado,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.grey,
                      ),
                    ),
                  ],
                ),
              ),
              _statusChip(order.estado),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              const Icon(
                Icons.location_on_outlined,
                size: 18,
                color: AppColors.grey,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  order.direccion,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              IconButton(
                tooltip: 'Abrir mapa',
                onPressed: () =>
                    _openMap(order.ubicacion.latitud, order.ubicacion.longitud),
                icon: const Icon(Icons.map_outlined),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(
                order.horaEntrega,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
              IconButton(
                tooltip: 'Llamar al cliente',
                onPressed: order.clienteTelefono.isEmpty
                    ? null
                    : () => _call(order.clienteTelefono),
                icon: const Icon(Icons.phone_outlined),
              ),
              if (canAct)
                FilledButton(
                  onPressed: () => _actionFor(order.id),
                  child: Text(actionLabel),
                ),
              if (order.estado == 'Entregado')
                const Row(
                  children: [
                    Icon(
                      Icons.check_circle_rounded,
                      size: 20,
                      color: AppColors.green,
                    ),
                    SizedBox(width: 5),
                    Text(
                      'Completado',
                      style: TextStyle(
                        color: AppColors.green,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _statusChip(String state) {
    final delivered = state == 'Entregado';
    final enRoute = state == 'EnCamino';
    final color = delivered
        ? AppColors.green
        : enRoute
        ? const Color(0xFF1B5FAA)
        : const Color(0xFF9A6B00);
    final bg = delivered
        ? const Color(0xFFE2F5EA)
        : enRoute
        ? const Color(0xFFE3F0FF)
        : AppColors.yellowSoft;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        state,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w800,
          color: color,
        ),
      ),
    );
  }

  Widget _gpsCard() {
    final state = _controller.gpsState;
    final label = switch (state) {
      GpsState.active => 'GPS local activo',
      GpsState.waitingForSample => 'Esperando una ubicación válida',
      GpsState.serviceDisabled => 'Ubicación del teléfono apagada',
      GpsState.permissionDenied => 'Permiso de ubicación denegado',
      GpsState.permissionDeniedForever => 'Permiso bloqueado: revisa Ajustes',
      GpsState.accuracyInsufficient => 'Precisión insuficiente',
      GpsState.unavailable => 'GPS no disponible',
      _ => 'GPS preparado al iniciar',
    };
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Icon(
            state == GpsState.active ? Icons.gps_fixed : Icons.gps_not_fixed,
            color: state == GpsState.active ? AppColors.green : AppColors.grey,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 3),
                Text(
                  _controller.latestGpsSample == null
                      ? 'Vista previa local; el endpoint GPS del backend está pendiente.'
                      : 'Última muestra local: ${_controller.latestGpsSample!.capturedAtUtc.toLocal()}',
                  style: const TextStyle(fontSize: 11, color: AppColors.grey),
                ),
              ],
            ),
          ),
          if (state == GpsState.serviceDisabled ||
              state == GpsState.permissionDeniedForever)
            TextButton(
              onPressed: _controller.gps.openSettings,
              child: const Text('Ajustes'),
            ),
        ],
      ),
    );
  }

  Widget _emptyRoute() => const Padding(
    padding: EdgeInsets.symmetric(vertical: 80),
    child: Center(
      child: Column(
        children: [
          Icon(Icons.route_outlined, size: 54, color: AppColors.grey),
          SizedBox(height: 14),
          Text(
            'No hay ruta asignada para esta fecha',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
          ),
          SizedBox(height: 6),
          Text(
            'Puedes actualizar cuando recuperes la conexión.',
            style: TextStyle(color: AppColors.grey),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    ),
  );

  Widget _retry() => Center(
    child: Padding(
      padding: const EdgeInsets.symmetric(vertical: 40),
      child: FilledButton.icon(
        onPressed: _controller.refresh,
        icon: const Icon(Icons.refresh),
        label: const Text('Reintentar'),
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
      color: AppColors.yellowSoft,
      borderRadius: BorderRadius.circular(14),
    ),
    child: Row(
      children: [
        const Icon(Icons.sync_problem_outlined),
        const SizedBox(width: 10),
        Expanded(child: Text(value)),
        IconButton(
          tooltip: 'Reintentar tiempo real',
          onPressed: _controller.retryRealtime,
          icon: const Icon(Icons.sync),
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
        'La ubicación se captura solo localmente durante la ruta activa. El envío al backend espera un contrato autenticado.',
        style: TextStyle(color: AppColors.grey, height: 1.5),
      ),
      const SizedBox(height: 24),
      OutlinedButton.icon(
        onPressed: _controller.isBusy ? null : _logout,
        icon: const Icon(Icons.logout),
        label: const Text('Cerrar sesión'),
      ),
    ],
  );
}

extension _IterableFirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
