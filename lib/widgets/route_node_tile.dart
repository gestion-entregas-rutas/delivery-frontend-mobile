import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_text.dart';
import 'status_chip.dart';

/// Fila de la línea de ruta: un nodo a la izquierda, unido por una línea
/// vertical al nodo anterior y al siguiente, y el contenido a la derecha.
///
/// - Parada entregada: nodo verde con check; la línea que llega hasta ella
///   está rellena.
/// - Parada actual: nodo morado grande con su número.
/// - Parada pendiente: nodo vacío con borde gris.
///
/// La línea que sale de un nodo hacia el siguiente se rellena (morado) solo
/// cuando este nodo ya fue entregado, así el avance se lee de un vistazo.
class RouteNodeTile extends StatelessWidget {
  const RouteNodeTile({
    super.key,
    required this.status,
    required this.number,
    required this.child,
    this.isFirst = false,
    this.isLast = false,
  });

  final AppStatus status;

  /// Número de la parada, visible dentro del nodo si no está entregada.
  final int number;
  final Widget child;
  final bool isFirst;
  final bool isLast;

  static const double _nodeColumn = 40;

  @override
  Widget build(BuildContext context) {
    final active = status == AppStatus.active;
    final done = status == AppStatus.done;
    final nodeSize = active ? 40.0 : 28.0;
    // Entre dos nodos entregados la línea va rellena.
    final lineBefore = done || active ? AppColors.brand : AppColors.border;
    final lineAfter = done ? AppColors.brand : AppColors.border;

    // El contenido (a la derecha) define la altura; la columna del nodo se
    // dibuja encima, a la izquierda, ocupando todo ese alto. Un Stack evita
    // medir tamaños intrínsecos, así el contenido puede usar LayoutBuilder.
    return Stack(
      children: [
        // Alto mínimo: lo que ocupa el nodo, para que su columna nunca desborde
        // cuando el contenido es de una sola línea.
        ConstrainedBox(
          constraints: BoxConstraints(
            minHeight: 12 + nodeSize + (isLast ? 0 : 14),
          ),
          child: Padding(
            padding: EdgeInsets.only(
              left: _nodeColumn,
              bottom: isLast ? 0 : 14,
              top: 4,
            ),
            child: child,
          ),
        ),
        Positioned(
          left: 0,
          top: 0,
          bottom: 0,
          width: _nodeColumn,
          // El nodo se lee como "Parada 3, en camino"; la línea es decorativa.
          child: Semantics(
            label: 'Parada $number, ${_statusLabel(status)}',
            excludeSemantics: true,
            child: Column(
              children: [
                SizedBox(
                  height: 12,
                  child: isFirst ? null : _Line(color: lineBefore),
                ),
                _Node(status: status, number: number, size: nodeSize),
                Expanded(
                  child: isLast
                      ? const SizedBox.shrink()
                      : _Line(color: lineAfter),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

String _statusLabel(AppStatus status) => switch (status) {
  AppStatus.done => 'entregada',
  AppStatus.active => 'actual',
  AppStatus.pending => 'pendiente',
  AppStatus.warning => 'con aviso',
  AppStatus.error => 'cancelada',
};

class _Line extends StatelessWidget {
  const _Line({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) =>
      Center(child: Container(width: 3, color: color));
}

class _Node extends StatelessWidget {
  const _Node({required this.status, required this.number, required this.size});

  final AppStatus status;
  final int number;
  final double size;

  @override
  Widget build(BuildContext context) {
    final done = status == AppStatus.done;
    final active = status == AppStatus.active;
    final cancelled = status == AppStatus.error;
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: done
            ? AppColors.done
            : active
            ? AppColors.brand
            : cancelled
            ? AppColors.redSoft
            : AppColors.surface,
        border: Border.all(
          color: done
              ? AppColors.done
              : active
              ? AppColors.brand
              : cancelled
              ? AppColors.red
              : AppColors.border,
          width: 2.5,
        ),
        boxShadow: active
            ? const [
                BoxShadow(
                  color: Color(0x406A1B9A),
                  blurRadius: 12,
                  offset: Offset(0, 4),
                ),
              ]
            : null,
      ),
      child: done
          ? const Icon(Icons.check_rounded, size: 18, color: Colors.white)
          : cancelled
          ? const Icon(Icons.close_rounded, size: 18, color: AppColors.red)
          : Text(
              '$number',
              style: (active ? AppText.headline : AppText.label).copyWith(
                color: active ? Colors.white : AppColors.grey,
              ),
            ),
    );
  }
}
