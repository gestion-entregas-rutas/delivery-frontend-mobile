import 'package:flutter/material.dart';

import '../../models/logistica_models.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text.dart';
import '../status_chip.dart';

/// Parada que no es la actual (entregada o pendiente): nombre, dirección y
/// hora, en pocas líneas. Va dentro de un `RouteNodeTile`.
class StopRow extends StatelessWidget {
  const StopRow({super.key, required this.stop});

  final ParadaDto stop;

  @override
  Widget build(BuildContext context) {
    final order = stop.pedido;
    final done = order.entregado;
    final cancelled = order.cancelado;
    return Opacity(
      opacity: done || cancelled ? 0.7 : 1,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              order.clienteNombre,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppText.body.copyWith(
                fontWeight: FontWeight.w700,
                color: AppColors.ink,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              order.direccion,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: AppText.bodySmall.copyWith(color: AppColors.grey),
            ),
            if (cancelled) ...[
              const SizedBox(height: 4),
              const StatusChip(status: AppStatus.error, label: 'Cancelado'),
            ] else if (!done) ...[
              const SizedBox(height: 2),
              Text(
                'Hora ${order.horaEntrega}',
                style: AppText.label.copyWith(color: AppColors.grey),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
