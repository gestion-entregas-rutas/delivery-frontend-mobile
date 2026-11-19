import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';
import '../../theme/app_text.dart';

/// Pantalla vacía: dice qué pasa y qué hacer, con una acción clara.
class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 56, horizontal: 24),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 88,
          height: 88,
          decoration: const BoxDecoration(
            color: AppColors.brandSoft,
            shape: BoxShape.circle,
          ),
          child: Icon(icon, size: 42, color: AppColors.brand),
        ),
        const SizedBox(height: 22),
        Text(title, style: AppText.title, textAlign: TextAlign.center),
        const SizedBox(height: 8),
        Text(
          message,
          style: AppText.body.copyWith(color: AppColors.grey),
          textAlign: TextAlign.center,
        ),
        if (actionLabel != null) ...[
          const SizedBox(height: 24),
          OutlinedButton.icon(
            onPressed: onAction,
            icon: const Icon(Icons.refresh_rounded),
            label: Text(actionLabel!),
          ),
        ],
      ],
    ),
  );
}
