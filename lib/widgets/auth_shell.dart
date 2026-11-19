import 'package:flutter/material.dart';

import '../screens/animated_route.dart';
import '../theme/app_colors.dart';
import '../theme/app_text.dart';

/// Marco común de las pantallas de acceso (login y cambio de credenciales).
///
/// - Teléfono: fondo morado con la marca y la ruta animada arriba, y una hoja
///   blanca con el formulario que sube desde abajo.
/// - Pantalla ancha: dos paneles, morado con la marca a la izquierda y el
///   formulario centrado a la derecha.
class AuthShell extends StatelessWidget {
  const AuthShell({
    super.key,
    required this.child,
    this.showRoute = true,
    this.tagline = 'Haz tu ruta. Entrega a tiempo.',
  });

  /// El formulario.
  final Widget child;

  /// Muestra la ruta animada arriba (se oculta sola con el teclado abierto).
  final bool showRoute;
  final String tagline;

  static const double wideBreakpoint = 840;
  static const double _maxWidth = 560;

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: AppColors.brand,
    body: LayoutBuilder(
      builder: (context, constraints) => constraints.maxWidth >= wideBreakpoint
          ? _wide(context, constraints)
          : _narrow(context, constraints),
    ),
  );

  Widget _narrow(BuildContext context, BoxConstraints constraints) {
    final keyboard = MediaQuery.viewInsetsOf(context).bottom > 0;
    final padding = MediaQuery.paddingOf(context);
    return Stack(
      children: [
        // Relleno blanco fijo en la mitad inferior: si el formulario es corto,
        // la hoja parece llegar hasta el borde sin forzar su altura. Las
        // esquinas redondeadas de la hoja quedan siempre sobre el morado.
        Positioned.fill(
          child: Align(
            alignment: Alignment.bottomCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: _maxWidth),
              child: SizedBox(
                height: constraints.maxHeight * .5,
                width: double.infinity,
                child: const ColoredBox(color: AppColors.surface),
              ),
            ),
          ),
        ),
        // fill: un SingleChildScrollView suelto en un Stack se ajusta a su
        // contenido y dejaría el Stack más bajo que la pantalla.
        Positioned.fill(
          child: SingleChildScrollView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: _maxWidth),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Padding(
                      padding: EdgeInsets.fromLTRB(24, padding.top + 18, 24, 0),
                      child: const _Lockup(),
                    ),
                    if (showRoute)
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 250),
                        height: keyboard
                            ? 70
                            : (constraints.maxHeight * .26).clamp(130.0, 230.0),
                        child: const AnimatedRoute(),
                      )
                    else
                      const SizedBox(height: 24),
                    Container(
                      padding: EdgeInsets.fromLTRB(
                        24,
                        28,
                        24,
                        24 + padding.bottom,
                      ),
                      decoration: const BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.vertical(
                          top: Radius.circular(36),
                        ),
                      ),
                      child: child,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _wide(BuildContext context, BoxConstraints constraints) => Row(
    children: [
      Expanded(
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(48),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const _Lockup(),
                if (showRoute)
                  // SizedBox.expand: sin tamaño tight el CustomPaint mediría 0.
                  const Expanded(
                    child: Padding(
                      padding: EdgeInsets.symmetric(vertical: 24),
                      child: SizedBox.expand(child: AnimatedRoute()),
                    ),
                  )
                else
                  const Spacer(),
                Text(
                  tagline,
                  style: AppText.title.copyWith(color: Colors.white),
                ),
              ],
            ),
          ),
        ),
      ),
      Expanded(
        child: ColoredBox(
          color: AppColors.surface,
          child: SafeArea(
            child: Center(
              child: SingleChildScrollView(
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                padding: const EdgeInsets.all(48),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 440),
                  child: child,
                ),
              ),
            ),
          ),
        ),
      ),
    ],
  );
}

/// Marca: icono en una ficha blanca y el nombre.
class _Lockup extends StatelessWidget {
  const _Lockup();

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Icon(
          Icons.route_rounded,
          size: 24,
          color: AppColors.brand,
        ),
      ),
      const SizedBox(width: 10),
      Flexible(
        child: Text(
          'RutaExpress',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: AppText.headline.copyWith(
            color: Colors.white,
            fontSize: 24,
            letterSpacing: -0.8,
          ),
        ),
      ),
    ],
  );
}
