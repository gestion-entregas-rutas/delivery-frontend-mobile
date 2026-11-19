import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_text.dart';

/// Botón principal de cada pantalla: ancho completo, forma de píldora, con
/// verbo claro ("Confirmar entrega"). Solo debería haber uno por estado.
///
/// Con [loading] se bloquea y muestra un indicador, de modo que no se pueda
/// pulsar dos veces mientras el servidor responde.
class PrimaryButton extends StatelessWidget {
  const PrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.loading = false,
    this.color = AppColors.brand,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool loading;

  /// Morado por defecto; verde para confirmar una entrega.
  final Color color;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null && !loading;
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: FilledButton(
        style: FilledButton.styleFrom(
          backgroundColor: color,
          disabledBackgroundColor: loading ? color.withAlpha(200) : null,
          foregroundColor: Colors.white,
          disabledForegroundColor: loading ? Colors.white : null,
        ),
        onPressed: enabled ? onPressed : null,
        child: loading
            ? Semantics(
                label: '$label, en proceso',
                child: const SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    color: Colors.white,
                  ),
                ),
              )
            : Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (icon != null) ...[
                    Icon(icon, size: 22),
                    const SizedBox(width: 10),
                  ],
                  Flexible(
                    child: Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppText.button,
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}
