import 'package:flutter/material.dart';

import '../../location/gps_service.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text.dart';

/// Estado del GPS con lo que hay que hacer para arreglarlo: un punto de color
/// y, si hace falta, un botón ("Activar", "Permitir", "Reintentar" o
/// "Ajustes"). Sin textos técnicos.
class GpsStatus extends StatelessWidget {
  const GpsStatus({
    super.key,
    required this.state,
    this.onOpenSettings,
    this.onEnable,
  });

  final GpsState state;

  /// Abre los ajustes del teléfono (ubicación apagada o permiso bloqueado).
  final VoidCallback? onOpenSettings;

  /// Enciende el GPS (o vuelve a intentarlo), pidiendo el permiso si falta.
  final VoidCallback? onEnable;

  bool get _attention =>
      state == GpsState.serviceDisabled ||
      state == GpsState.permissionDenied ||
      state == GpsState.permissionDeniedForever ||
      state == GpsState.accuracyInsufficient ||
      state == GpsState.unavailable;

  bool get _searching =>
      state == GpsState.waitingForSample || state == GpsState.checking;

  String get label => switch (state) {
    GpsState.active => 'Ubicación activa',
    GpsState.waitingForSample || GpsState.checking => 'Buscando tu ubicación…',
    GpsState.serviceDisabled => 'Enciende la ubicación del teléfono',
    GpsState.permissionDenied => 'Permite la ubicación para ver tu posición',
    GpsState.permissionDeniedForever =>
      'Permiso bloqueado: actívalo en Ajustes',
    GpsState.accuracyInsufficient => 'Señal débil: sal a un lugar abierto',
    GpsState.unavailable => 'No se pudo obtener la ubicación',
    GpsState.stopped => 'Ubicación apagada',
  };

  /// Texto y acción del botón según el estado; `null` si no hay nada que
  /// pulsar.
  ({String text, VoidCallback action})? get _button {
    switch (state) {
      case GpsState.serviceDisabled:
      case GpsState.permissionDeniedForever:
        final open = onOpenSettings;
        return open == null ? null : (text: 'Ajustes', action: open);
      case GpsState.permissionDenied:
        final enable = onEnable;
        return enable == null ? null : (text: 'Permitir', action: enable);
      case GpsState.accuracyInsufficient:
      case GpsState.unavailable:
        final enable = onEnable;
        return enable == null ? null : (text: 'Reintentar', action: enable);
      case GpsState.stopped:
        final enable = onEnable;
        return enable == null ? null : (text: 'Activar', action: enable);
      case GpsState.active:
      case GpsState.waitingForSample:
      case GpsState.checking:
        return null;
    }
  }

  Color get _color => state == GpsState.active
      ? AppColors.brandBright
      : _attention
      ? AppColors.amber
      : AppColors.grey;

  @override
  Widget build(BuildContext context) {
    final button = _button;
    final Widget leading;
    if (_attention) {
      leading = Icon(Icons.location_off_rounded, size: 20, color: _color);
    } else if (_searching) {
      leading = const SizedBox(
        width: 12,
        height: 12,
        child: CircularProgressIndicator(strokeWidth: 2),
      );
    } else {
      leading = Container(
        width: 10,
        height: 10,
        decoration: BoxDecoration(color: _color, shape: BoxShape.circle),
      );
    }
    final text = Text(
      label,
      style: _attention
          ? AppText.bodySmall.copyWith(
              color: AppColors.ink,
              fontWeight: FontWeight.w600,
            )
          : AppText.bodySmall.copyWith(color: AppColors.grey),
    );
    // Wrap: si el texto y el botón no caben juntos (pantalla angosta o letra
    // grande), el botón baja a la línea siguiente en vez de cortarse.
    final content = Wrap(
      alignment: WrapAlignment.spaceBetween,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            leading,
            SizedBox(width: _attention ? 10 : 8),
            Flexible(child: text),
          ],
        ),
        if (button != null)
          TextButton(onPressed: button.action, child: Text(button.text)),
      ],
    );
    if (!_attention) {
      return Semantics(label: 'GPS: $label', child: content);
    }
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 10, 8, 10),
      decoration: BoxDecoration(
        color: AppColors.amberSoft,
        borderRadius: BorderRadius.circular(16),
      ),
      child: content,
    );
  }
}
