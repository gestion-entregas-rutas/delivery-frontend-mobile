import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';
import '../../theme/app_text.dart';
import '../status_chip.dart';

/// Aviso dentro de la pantalla (error, advertencia o información) con una
/// acción opcional para resolverlo.
class InlineNotice extends StatelessWidget {
  const InlineNotice({
    super.key,
    required this.status,
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  final AppStatus status;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(bottom: 12),
    padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
    decoration: BoxDecoration(
      color: status.softColor,
      borderRadius: BorderRadius.circular(16),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 2),
          child: Icon(status.icon, color: status.color, size: 22),
        ),
        const SizedBox(width: 12),
        // El botón va debajo del mensaje: con letra grande o pantalla angosta
        // no compite con el texto por el ancho.
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: EdgeInsets.only(bottom: actionLabel == null ? 4 : 0),
                child: Text(
                  message,
                  style: AppText.bodySmall.copyWith(
                    color: AppColors.ink,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              if (actionLabel != null)
                TextButton(
                  onPressed: onAction,
                  style: TextButton.styleFrom(
                    padding: EdgeInsets.zero,
                    alignment: Alignment.centerLeft,
                    tapTargetSize: MaterialTapTargetSize.padded,
                  ),
                  child: Text(actionLabel!),
                ),
            ],
          ),
        ),
      ],
    ),
  );
}
