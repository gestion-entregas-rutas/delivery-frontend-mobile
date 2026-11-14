import 'package:flutter/material.dart';

import '../auth/auth_controller.dart';
import 'change_credentials_screen.dart';
import 'home_screen.dart';
import 'login_screen.dart';
import 'splash_screen.dart';

class SessionGate extends StatefulWidget {
  const SessionGate({super.key, required this.auth});

  final AuthController auth;

  @override
  State<SessionGate> createState() => _SessionGateState();
}

class _SessionGateState extends State<SessionGate> {
  AuthStatus? _lastStatus;

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
    switch (status) {
      case AuthStatus.unknown:
      case AuthStatus.restoring:
        return SplashScreen(auth: widget.auth, hold: true);
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
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: AppColors.yellow,
    body: SafeArea(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.cloud_off_rounded, size: 52),
                  const SizedBox(height: 18),
                  const Text(
                    'No se pudo validar la sesión',
                    style: TextStyle(fontSize: 21, fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    auth.error?.message ??
                        'Comprueba la conexión y vuelve a intentar.',
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 20),
                  FilledButton.icon(
                    onPressed: auth.retryRestore,
                    icon: const Icon(Icons.refresh),
                    label: const Text('Reintentar'),
                  ),
                  TextButton(
                    onPressed: auth.logout,
                    child: const Text('Cerrar sesión local'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  );
}
