import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';
import '../../theme/app_text.dart';

/// Un ajuste del teléfono: qué es, cómo está ahora y, si hay algo que hacer,
/// un botón para hacerlo. Pensado para listarse dentro de [SettingsCard].
class SettingTile extends StatelessWidget {
  const SettingTile({
    super.key,
    required this.icon,
    required this.title,
    required this.description,
    required this.statusLabel,
    required this.statusOk,
    this.buttonLabel,
    this.onPressed,
    this.loading = false,
  });

  final IconData icon;
  final String title;

  /// Para qué sirve, en una línea.
  final String description;

  /// Cómo está ahora: "Activada", "Apagada"…
  final String statusLabel;

  /// Si está bien (punto morado) o necesita atención (punto ámbar).
  final bool statusOk;

  /// Texto del botón; sin él no hay nada que pulsar.
  final String? buttonLabel;
  final VoidCallback? onPressed;

  /// Esperando la respuesta del sistema: el botón se bloquea.
  final bool loading;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 14),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Un solo nodo para lectores de pantalla: "Ubicación (GPS): Activada",
        // con la descripción como pista. El botón queda aparte y accesible.
        Semantics(
          container: true,
          label: '$title: $statusLabel',
          hint: description,
          excludeSemantics: true,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ExcludeSemantics(
                child: Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: statusOk ? AppColors.brandSoft : AppColors.amberSoft,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    icon,
                    size: 22,
                    color: statusOk ? AppColors.brand : AppColors.amber,
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: AppText.body.copyWith(
                        fontWeight: FontWeight.w700,
                        color: AppColors.ink,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      description,
                      style: AppText.bodySmall.copyWith(color: AppColors.grey),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        // Estado y botón en su propia línea: con letra grande o pantalla
        // angosta bajan sin cortarse.
        Padding(
          padding: const EdgeInsets.only(left: 58, top: 6),
          child: Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            runSpacing: 4,
            children: [
              ExcludeSemantics(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        color: statusOk
                            ? AppColors.brandBright
                            : AppColors.amber,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        statusLabel,
                        style: AppText.bodySmall.copyWith(
                          fontWeight: FontWeight.w700,
                          color: AppColors.ink,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              if (buttonLabel != null)
                loading
                    ? const Padding(
                        padding: EdgeInsets.all(12),
                        child: SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2.5),
                        ),
                      )
                    : FilledButton.tonal(
                        onPressed: onPressed,
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.brandSoft,
                          foregroundColor: AppColors.brand,
                          minimumSize: const Size(64, 44),
                          padding: const EdgeInsets.symmetric(horizontal: 18),
                          textStyle: AppText.button.copyWith(fontSize: 15),
                        ),
                        child: Text(buttonLabel!),
                      ),
            ],
          ),
        ),
      ],
    ),
  );
}

/// Tarjeta que agrupa varios [SettingTile] con una línea entre ellos.
class SettingsCard extends StatelessWidget {
  const SettingsCard({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 16),
    decoration: BoxDecoration(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: AppColors.border),
    ),
    child: Column(
      children: [
        for (var i = 0; i < children.length; i++) ...[
          if (i > 0) const Divider(height: 1, color: AppColors.border),
          children[i],
        ],
      ],
    ),
  );
}
