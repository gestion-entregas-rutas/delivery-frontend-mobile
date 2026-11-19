import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../auth/auth_controller.dart';
import 'home_screen.dart' show AppColors, kAppName;
import 'login_screen.dart';
import 'animated_route.dart';
import 'rive_delivery.dart';

/// Morado de marca; también es el fondo nativo de arranque en Android.
const Color kSplashBackground = AppColors.brand;

/// Relación de aspecto de la ventana del mapa. Recorta el artboard (1080x480)
/// a su tramo central-izquierdo: ahí está el auto durante toda la animación,
/// y así el mapa se ve ~50 % más grande que ajustado al ancho.
const double kSplashMapAspect = 1.46;

class SplashScreen extends StatefulWidget {
  const SplashScreen({
    super.key,
    this.auth,
    this.hold = false,
    this.onDone,
    this.loadProgress = 1,
  });

  final AuthController? auth;
  final bool hold;

  /// Si se da, el splash avisa al terminar en vez de navegar él mismo.
  final VoidCallback? onDone;

  /// Avance real de lo que la app prepara por detrás (sesión y datos de la
  /// primera pantalla), de 0 a 1. El splash no termina hasta que llega a 1.
  final double loadProgress;

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  Timer? _minTimer;
  Timer? _capTimer;

  /// Duración mínima (ciclo de la animación); null hasta que está lista.
  Duration? _progress;
  bool _animReady = false;
  bool _minElapsed = false;
  bool _finished = false;

  @override
  void initState() {
    super.initState();
    // Tope de seguridad: si algo por detrás se atasca (red caída, por
    // ejemplo), el splash termina igual y la pantalla siguiente muestra su
    // propio estado de carga o error.
    _capTimer = Timer(const Duration(seconds: 25), _finish);
  }

  /// Arranca el tiempo mínimo de pantalla desde que la animación ya se ve:
  /// un ciclo completo si es la animación Rive, un momento corto si es el
  /// respaldo.
  void _onAnimationReady(bool animated) {
    final duration = animated
        ? kDeliveryRiveCycle
        : const Duration(milliseconds: 2500);
    setState(() {
      _progress = duration;
      _animReady = true;
    });
    _minTimer?.cancel();
    _minTimer = Timer(duration, () {
      _minElapsed = true;
      _maybeFinish();
    });
  }

  @override
  void didUpdateWidget(SplashScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    // didUpdateWidget corre durante la construcción del padre: avisar con
    // onDone ahí haría setState en pleno build ("setState() called during
    // build"). Se difiere al final del cuadro.
    WidgetsBinding.instance.addPostFrameCallback((_) => _maybeFinish());
  }

  /// La animación cuenta 20 %; lo que se prepara por detrás, 80 %.
  double get _real =>
      (_animReady ? 0.2 : 0) + 0.8 * widget.loadProgress.clamp(0.0, 1.0);

  String get _stage => widget.loadProgress < 0.5
      ? 'Verificando tu sesión…'
      : widget.loadProgress < 1
      ? 'Cargando tu ruta…'
      : 'Todo listo';

  void _maybeFinish() {
    if (_minElapsed && widget.loadProgress >= 1) _finish();
  }

  void _finish() {
    if (_finished || !mounted || widget.hold) return;
    _finished = true;
    if (widget.onDone != null) {
      widget.onDone!();
      return;
    }
    Navigator.of(context).pushReplacement(
      PageRouteBuilder<void>(
        transitionDuration: Duration(
          milliseconds: MediaQuery.disableAnimationsOf(context) ? 0 : 450,
        ),
        pageBuilder: (_, animation, secondaryAnimation) =>
            LoginScreen(auth: widget.auth),
        transitionsBuilder: (_, animation, secondaryAnimation, child) =>
            FadeTransition(opacity: animation, child: child),
      ),
    );
  }

  @override
  void dispose() {
    _minTimer?.cancel();
    _capTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: kSplashBackground,
    body: Column(
      children: [
        Expanded(flex: 3, child: SafeArea(bottom: false, child: _brand())),
        AspectRatio(
          aspectRatio: kSplashMapAspect,
          child: ColoredBox(
            color: Colors.white,
            child: RiveDelivery(
              onReady: _onAnimationReady,
              alignment: const Alignment(-0.71, 0),
              fallback: const ColoredBox(
                color: AppColors.brand,
                child: AnimatedRoute(),
              ),
            ),
          ),
        ),
        Expanded(flex: 4, child: _infoPanel()),
      ],
    ),
  );

  Widget _brand() => Center(
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
          ),
          child: const Icon(
            Icons.route_rounded,
            size: 30,
            color: AppColors.brand,
          ),
        ),
        const SizedBox(width: 12),
        const Text(
          kAppName,
          style: TextStyle(
            fontSize: 34,
            fontWeight: FontWeight.w900,
            letterSpacing: -1.5,
            color: Colors.white,
          ),
        ),
      ],
    ),
  );

  Widget _infoPanel() => SafeArea(
    top: false,
    child: LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(28, 28, 28, 16),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            minHeight: math.max(0, constraints.maxHeight - 44),
          ),
          child: IntrinsicHeight(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Haz tu ruta.',
                  style: TextStyle(
                    fontSize: 30,
                    height: 1.1,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -1,
                    color: Colors.white,
                  ),
                ),
                const Text(
                  'Entrega a tiempo.',
                  style: TextStyle(
                    fontSize: 30,
                    height: 1.1,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -1,
                    color: AppColors.lavender,
                  ),
                ),
                const SizedBox(height: 22),
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: SizedBox(
                    height: 6,
                    child: _progress == null
                        ? const ColoredBox(color: Color(0x33FFFFFF))
                        : TweenAnimationBuilder<double>(
                            tween: Tween(begin: 0, end: 1),
                            duration: _progress!,
                            builder: (context, time, _) =>
                                LinearProgressIndicator(
                                  // No llega al final hasta que el tiempo
                                  // mínimo Y la carga real terminan.
                                  value: math.min(time, _real),
                                  backgroundColor: const Color(0x33FFFFFF),
                                  valueColor: const AlwaysStoppedAnimation(
                                    Colors.white,
                                  ),
                                ),
                          ),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  _stage,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.lavender,
                  ),
                ),
                const Spacer(),
                const Text(
                  'Animación "Project covers 3/4. Courier app" por rusvdo · CC BY',
                  style: TextStyle(
                    fontSize: 10,
                    color: AppColors.lavenderMuted,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}
