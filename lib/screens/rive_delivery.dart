import 'package:flutter/material.dart';
import 'package:rive/rive.dart' as rive;

import 'animated_route.dart';

const String kDeliveryRiveAsset =
    'assets/rive/28286-53434-project-covers-34-courier-app.riv';

/// Relación de aspecto del artboard (1080 x 480).
const double kDeliveryRiveAspect = 1080 / 480;

/// Lo que dura un ciclo completo de la animación con `hover` activo.
const Duration kDeliveryRiveCycle = Duration(seconds: 10);

/// Reproduce "Project covers 3/4. Courier app" (rusvdo, CC BY).
/// La animación solo avanza mientras el booleano `hover` del view model
/// está en true, así que lo activamos al cargar.
/// Si el archivo no carga, o el usuario pidió reducir animaciones,
/// muestra [AnimatedRoute] como respaldo.
class RiveDelivery extends StatefulWidget {
  const RiveDelivery({
    super.key,
    this.fallback = const AnimatedRoute(),
    this.onReady,
    this.fit = rive.Fit.cover,
    this.alignment = Alignment.center,
  });

  /// Los tests lo apagan: la librería nativa de Rive no corre bajo FakeAsync.
  static bool enabled = true;

  final Widget fallback;

  /// Cómo se acomoda el artboard (1080x480) en el espacio disponible.
  final rive.Fit fit;
  final Alignment alignment;

  /// Se llama una vez cuando ya se ve la animación (`true`) o su respaldo
  /// (`false`).
  final ValueChanged<bool>? onReady;

  @override
  State<RiveDelivery> createState() => _RiveDeliveryState();
}

class _RiveDeliveryState extends State<RiveDelivery> {
  rive.FileLoader? _loader;
  rive.File? _file;
  bool _failed = false;
  bool _notified = false;

  @override
  void initState() {
    super.initState();
    if (RiveDelivery.enabled) {
      _load();
    } else {
      _failed = true;
      WidgetsBinding.instance.addPostFrameCallback((_) => _notifyReady());
    }
  }

  Future<void> _load() async {
    try {
      final file = await rive.File.asset(
        kDeliveryRiveAsset,
        riveFactory: rive.Factory.rive,
      );
      if (!mounted) {
        file?.dispose();
        return;
      }
      if (file == null) throw StateError('Archivo Rive vacío');
      setState(() {
        _file = file;
        _loader = rive.FileLoader.fromFile(
          file,
          riveFactory: rive.Factory.rive,
        );
      });
    } on Object catch (e) {
      debugPrint('RiveDelivery: $e');
      if (!mounted) return;
      setState(() => _failed = true);
      _notifyReady();
    }
  }

  void _notifyReady({bool animated = false}) {
    if (_notified) return;
    _notified = true;
    widget.onReady?.call(animated);
  }

  @override
  void dispose() {
    _loader?.dispose();
    _file?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.disableAnimationsOf(context)) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _notifyReady());
      return widget.fallback;
    }
    final loader = _loader;
    if (_failed) return widget.fallback;
    if (loader == null) return const SizedBox.shrink();
    return ExcludeSemantics(
      child: IgnorePointer(
        child: rive.RiveWidgetBuilder(
          fileLoader: loader,
          dataBind: rive.DataBind.auto(),
          onLoaded: (state) {
            state.viewModelInstance?.boolean('hover')?.value = true;
            _notifyReady(animated: true);
          },
          onFailed: (error, _) {
            debugPrint('RiveDelivery: $error');
            _notifyReady();
          },
          builder: (context, state) => switch (state) {
            rive.RiveLoading() => const SizedBox.shrink(),
            rive.RiveFailed() => widget.fallback,
            rive.RiveLoaded(:final controller) => rive.RiveWidget(
              controller: controller,
              fit: widget.fit,
              alignment: widget.alignment,
            ),
          },
        ),
      ),
    );
  }
}
