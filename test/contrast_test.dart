import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:frontend_mobile/theme/app_colors.dart';

double _channel(double c) =>
    c <= 0.03928 ? c / 12.92 : math.pow((c + 0.055) / 1.055, 2.4).toDouble();

double _luminance(Color color) =>
    0.2126 * _channel(color.r) +
    0.7152 * _channel(color.g) +
    0.0722 * _channel(color.b);

/// Relación de contraste WCAG entre dos colores opacos.
double contrast(Color a, Color b) {
  final l1 = _luminance(a);
  final l2 = _luminance(b);
  final lighter = math.max(l1, l2);
  final darker = math.min(l1, l2);
  return (lighter + 0.05) / (darker + 0.05);
}

void main() {
  // (texto, fondo, dónde se usa)
  final pairs = <(Color, Color, String)>[
    (AppColors.ink, AppColors.paper, 'texto principal sobre papel'),
    (AppColors.ink, AppColors.surface, 'texto principal sobre blanco'),
    (AppColors.ink, AppColors.brandSoft, 'artículos sobre morado suave'),
    (AppColors.grey, AppColors.paper, 'texto secundario sobre papel'),
    (AppColors.grey, AppColors.surface, 'texto secundario sobre blanco'),
    (AppColors.brand, AppColors.surface, 'enlaces y botones de texto'),
    (AppColors.brand, AppColors.brandSoft, 'chip activo'),
    (AppColors.brandDeep, AppColors.brandSoft, 'título "Para entregar"'),
    (AppColors.surface, AppColors.brand, 'botón principal'),
    (AppColors.done, AppColors.doneSoft, 'chip entregada'),
    (AppColors.done, AppColors.surface, 'texto de ruta completada'),
    (AppColors.surface, AppColors.done, 'check sobre nodo entregado'),
    (AppColors.amber, AppColors.amberSoft, 'aviso de GPS'),
    (AppColors.red, AppColors.redSoft, 'aviso de error'),
    (AppColors.ink, AppColors.amberSoft, 'texto del aviso'),
    (AppColors.ink, AppColors.redSoft, 'texto del error'),
    (AppColors.surface, AppColors.brand, 'texto del splash'),
    (AppColors.lavender, AppColors.brand, 'subtítulo del splash'),
    (AppColors.lavenderMuted, AppColors.brand, 'crédito del splash'),
  ];

  group('contraste AA (4,5:1) en texto', () {
    for (final (fg, bg, usage) in pairs) {
      test(usage, () {
        final ratio = contrast(fg, bg);
        expect(
          ratio,
          greaterThanOrEqualTo(4.5),
          reason: '$usage: ${ratio.toStringAsFixed(2)}:1',
        );
      });
    }
  });
}
