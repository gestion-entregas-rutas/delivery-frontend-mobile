import 'dart:async';

import 'package:flutter/material.dart';

import '../auth/auth_controller.dart';
import '../state/driver_controller.dart';
import 'change_credentials_screen.dart';
import 'home_screen.dart';
import 'login_screen.dart';
import 'splash_screen.dart';
import '../theme/app_text.dart';
import '../widgets/auth_shell.dart';
import '../widgets/primary_button.dart';

class SessionGate extends StatefulWidget {
  const SessionGate({super.key, required this.auth});

  final AuthController auth;

  @override
  State<SessionGate> createState() => _SessionGateState();
}

class _SessionGateState extends State<SessionGate> {
  AuthStatus? _lastStatus;
  bool _splashDone = false;

  // La ruta del repartidor se precarga mientras se ve el splash, para que la
  // pantalla principal ya tenga datos al abrirse.
  DriverController? _driver;
  String? _driverKey;

  @override
  void initState() {
    super.initState();
    // Se registra antes que el AnimatedBuilder del build, así el controlador
    // ya existe cuando se reconstruye la pantalla.
    widget.auth.addListener(_syncDriver);
    _syncDriver();
  }

  @override
  void dispose() {
    widget.auth.removeListener(_syncDriver);
    _driver?.removeListener(_onDriverChanged);
    _driver?.dispose();
    super.dispose();
  }

  void _onDriverChanged() {
    if (mounted) setState(() {});
  }

  void _syncDriver() {
    final id = widget.auth.driverId;
    final key = widget.auth.status == AuthStatus.signedIn && id != null
        ? '${widget.auth.user?.id}:$id'
        : null;
    if (key == _driverKey) return;
    final old = _driver;
    _driver = null;
    _driverKey = key;
    if (old != null) {
      old.removeListener(_onDriverChanged);
      // Se libera después del cuadro: la pantalla anterior aún puede leerlo.
      WidgetsBinding.instance.addPostFrameCallback((_) => old.dispose());
    }
    if (key == null || id == null) return;
    final controller = DriverController(
      repository: widget.auth.logisticsRepository,
      driverId: id,
      validateSession: widget.auth.validateCurrentSession,
    )..addListener(_onDriverChanged);
    _driver = controller;
    unawaited(controller.initialize());
  }

  /// Avance real de la precarga, de 0 a 1: la mitad es resolver la sesión y la
  /// otra mitad, tener los datos de la primera pantalla.
  double _preloadProgress(AuthStatus status) {
    final sessionReady =
        status != AuthStatus.unknown && status != AuthStatus.restoring;
    if (!sessionReady) return 0;
    final driver = _driver;
    if (driver == null) return 1;
    final dataReady =
        driver.loadState == DriverLoadState.loaded ||
        driver.loadState == DriverLoadState.empty ||
        driver.loadState == DriverLoadState.error;
    return dataReady ? 1 : 0.5;
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: widget.auth,
    builder: (context, _) {
      final status = widget.auth.status;
      if (_lastStatus != null &&
          _lastStatus != status &&
          (status == AuthStatus.signedOut ||
              status == AuthStatus.temporarilyUnavailable ||
              status == AuthStatus.needsCredentialChange ||
              status == AuthStatus.changingCredentials ||
              status == AuthStatus.signingOut)) {
        // Authentication can change while a confirmation dialog or an
        // external action is open. Remove those transient routes before
        // exposing the login/unavailable surface.
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          Navigator.of(context).popUntil((route) => route.isFirst);
        });
      }
      _lastStatus = status;
      return _page(status);
    },
  );

  Widget _page(AuthStatus status) {
    final restoring =
        status == AuthStatus.unknown || status == AuthStatus.restoring;
    // El splash se muestra completo aunque la sesión se restaure antes.
    if (restoring || !_splashDone) {
      return SplashScreen(
        auth: widget.auth,
        loadProgress: _preloadProgress(status),
        onDone: () {
          if (mounted) setState(() => _splashDone = true);
        },
      );
    }
    switch (status) {
      case AuthStatus.unknown:
      case AuthStatus.restoring:
        return const SizedBox.shrink();
      case AuthStatus.needsCredentialChange:
      case AuthStatus.changingCredentials:
        return ChangeCredentialsScreen(auth: widget.auth);
      case AuthStatus.signedIn:
        final id = widget.auth.driverId;
        return id == null
            ? LoginScreen(auth: widget.auth)
            : HomeScreen(
                key: ValueKey('${widget.auth.user?.id}:$id'),
                repository: widget.auth.logisticsRepository,
                driverId: id,
                controller: _driver,
                auth: widget.auth,
              );
      case AuthStatus.temporarilyUnavailable:
        return _Unavailable(auth: widget.auth);
      case AuthStatus.authenticating:
      case AuthStatus.signingOut:
      case AuthStatus.signedOut:
        return LoginScreen(auth: widget.auth);
    }
  }
}

class _Unavailable extends StatelessWidget {
  const _Unavailable({required this.auth});

  final AuthController auth;

  @override
  Widget build(BuildContext context) => AuthShell(
    showRoute: false,
    tagline: 'Sin conexión por ahora.',
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          width: 56,
          height: 56,
          alignment: Alignment.center,
          decoration: const BoxDecoration(
            color: AppColors.brandSoft,
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.cloud_off_rounded,
            size: 30,
            color: AppColors.brand,
          ),
        ),
        const SizedBox(height: 16),
        const Text('No se pudo validar la sesión', style: AppText.title),
        const SizedBox(height: 8),
        Text(
          auth.error?.message ?? 'Comprueba la conexión y vuelve a intentar.',
          style: AppText.body.copyWith(color: AppColors.grey),
        ),
        const SizedBox(height: 24),
        PrimaryButton(
          label: 'Reintentar',
          icon: Icons.refresh_rounded,
          onPressed: auth.retryRestore,
        ),
        const SizedBox(height: 8),
        TextButton(
          onPressed: auth.logout,
          child: const Text('Cerrar sesión local'),
        ),
      ],
    ),
  );
}
