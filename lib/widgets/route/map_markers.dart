import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';

/// Marca de una parada en el mapa: una caja (el pedido que hay que entregar).
///
/// - Entregada: morado profundo con check.
/// - Actual: caja grande en morado vivo.
/// - Pendiente: caja con borde morado sobre blanco.
class StopBoxMarker extends StatelessWidget {
  const StopBoxMarker({
    super.key,
    required this.delivered,
    required this.active,
    required this.semanticLabel,
    this.selected = false,
    this.onTap,
  });

  final bool delivered;
  final bool active;
  final bool selected;

  /// Lo que lee el lector de pantalla, por ejemplo "Parada 2, actual, Ana".
  final String semanticLabel;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final Color fill = delivered
        ? AppColors.done
        : active
        ? AppColors.brandBright
        : AppColors.surface;
    final Color ring = delivered || active ? Colors.white : AppColors.brand;
    final Color icon = delivered || active ? Colors.white : AppColors.brand;
    return Semantics(
      button: onTap != null,
      label: semanticLabel,
      excludeSemantics: true,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            color: fill,
            shape: BoxShape.circle,
            border: Border.all(color: ring, width: selected ? 4 : 3),
            boxShadow: const [
              BoxShadow(
                color: Color(0x40000000),
                blurRadius: 8,
                offset: Offset(0, 3),
              ),
            ],
          ),
          alignment: Alignment.center,
          child: FittedBox(
            child: Padding(
              padding: EdgeInsets.all(active ? 11 : 8),
              child: Icon(
                delivered ? Icons.check_rounded : Icons.inventory_2_rounded,
                color: icon,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// El repartidor en el mapa: una moto sobre un círculo morado, con un halo
/// suave que lo distingue de las cajas.
class DriverMarker extends StatelessWidget {
  const DriverMarker({super.key});

  @override
  Widget build(BuildContext context) => Semantics(
    label: 'Tu ubicación',
    excludeSemantics: true,
    child: Container(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: AppColors.brandBright.withAlpha(46),
      ),
      alignment: Alignment.center,
      child: Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          color: AppColors.brand,
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white, width: 3),
          boxShadow: const [
            BoxShadow(
              color: Color(0x40000000),
              blurRadius: 8,
              offset: Offset(0, 3),
            ),
          ],
        ),
        child: const Icon(
          Icons.two_wheeler_rounded,
          color: Colors.white,
          size: 22,
        ),
      ),
    ),
  );
}
