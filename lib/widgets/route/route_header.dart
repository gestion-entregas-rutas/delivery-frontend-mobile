import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';
import '../../theme/app_text.dart';

/// Cabecera compacta de la ruta: título, fecha con acción para cambiarla y
/// avance de entregas. Reemplaza al bloque alto con contadores.
class RouteHeader extends StatelessWidget {
  const RouteHeader({
    super.key,
    required this.dateLabel,
    required this.done,
    required this.total,
    required this.onChangeDate,
    required this.onRefresh,
    this.busy = false,
  });

  /// Fecha ya formateada, por ejemplo "Hoy · 2026-10-17".
  final String dateLabel;
  final int done;
  final int total;
  final VoidCallback? onChangeDate;
  final VoidCallback? onRefresh;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final hasRoute = total > 0;
    final finished = hasRoute && done == total;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(child: Text('Mi ruta', style: AppText.title)),
            IconButton.filledTonal(
              tooltip: 'Actualizar',
              onPressed: busy ? null : onRefresh,
              style: IconButton.styleFrom(
                backgroundColor: AppColors.brandSoft,
                foregroundColor: AppColors.brand,
                minimumSize: const Size(48, 48),
              ),
              icon: const Icon(Icons.refresh_rounded),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Semantics(
          button: true,
          label: 'Cambiar fecha. Fecha actual: $dateLabel',
          excludeSemantics: true,
          child: InkWell(
            onTap: busy ? null : onChangeDate,
            borderRadius: BorderRadius.circular(12),
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 48),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.calendar_today_rounded,
                    size: 18,
                    color: AppColors.brand,
                  ),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      dateLabel,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppText.body.copyWith(
                        fontWeight: FontWeight.w700,
                        color: AppColors.ink,
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                  const Icon(
                    Icons.expand_more_rounded,
                    size: 22,
                    color: AppColors.brand,
                  ),
                ],
              ),
            ),
          ),
        ),
        if (hasRoute) ...[
          const SizedBox(height: 8),
          // El texto va arriba de la barra: con letra grande ocupa todo el ancho
          // sin competir con ella.
          Text(
            finished ? 'Ruta completada' : '$done de $total entregas',
            style: AppText.bodySmall.copyWith(
              fontWeight: FontWeight.w700,
              color: finished ? AppColors.done : AppColors.ink,
            ),
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: done / total,
              semanticsLabel: '$done de $total entregas completadas',
              minHeight: 8,
              backgroundColor: AppColors.brandSoft,
              color: finished ? AppColors.done : AppColors.brand,
            ),
          ),
        ],
      ],
    );
  }
}
