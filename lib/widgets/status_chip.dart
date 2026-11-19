import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_text.dart';

/// Estados que puede tener una parada o un aviso.
enum AppStatus { pending, active, done, warning, error }

extension AppStatusStyle on AppStatus {
  /// Color principal del estado (texto, icono y nodo).
  Color get color => switch (this) {
    AppStatus.pending => AppColors.grey,
    AppStatus.active => AppColors.brand,
    AppStatus.done => AppColors.done,
    AppStatus.warning => AppColors.amber,
    AppStatus.error => AppColors.red,
  };

  /// Fondo suave del estado.
  Color get softColor => switch (this) {
    AppStatus.pending => AppColors.paper,
    AppStatus.active => AppColors.brandSoft,
    AppStatus.done => AppColors.doneSoft,
    AppStatus.warning => AppColors.amberSoft,
    AppStatus.error => AppColors.redSoft,
  };

  IconData get icon => switch (this) {
    AppStatus.pending => Icons.schedule_rounded,
    AppStatus.active => Icons.navigation_rounded,
    AppStatus.done => Icons.check_circle_rounded,
    AppStatus.warning => Icons.warning_amber_rounded,
    AppStatus.error => Icons.error_outline_rounded,
  };
}

/// Etiqueta corta de estado. Lleva icono además del color, para que no
/// dependa solo del color.
class StatusChip extends StatelessWidget {
  const StatusChip({super.key, required this.status, required this.label});

  final AppStatus status;
  final String label;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
    decoration: BoxDecoration(
      color: status.softColor,
      borderRadius: BorderRadius.circular(999),
      border: status == AppStatus.pending
          ? Border.all(color: AppColors.border)
          : null,
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(status.icon, size: 14, color: status.color),
        const SizedBox(width: 5),
        Flexible(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppText.label.copyWith(color: status.color),
          ),
        ),
      ],
    ),
  );
}
