import 'package:flutter/material.dart';

/// Familias tipográficas. Si los archivos no están declarados en pubspec.yaml,
/// Flutter usa la fuente del sistema sin fallar.
class AppFonts {
  AppFonts._();

  /// Títulos y números de parada: con carácter y legible a distancia.
  static const display = 'BricolageGrotesque';

  /// Texto corrido.
  static const body = 'Figtree';
}

/// Escala tipográfica: 12, 14, 16, 20, 28 y 40.
class AppText {
  AppText._();

  static const display = TextStyle(
    fontFamily: AppFonts.display,
    fontSize: 40,
    height: 1.05,
    fontWeight: FontWeight.w800,
    letterSpacing: -1.2,
  );
  static const title = TextStyle(
    fontFamily: AppFonts.display,
    fontSize: 28,
    height: 1.1,
    fontWeight: FontWeight.w800,
    letterSpacing: -0.8,
  );
  static const headline = TextStyle(
    fontFamily: AppFonts.display,
    fontSize: 20,
    height: 1.2,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.3,
  );
  static const body = TextStyle(
    fontFamily: AppFonts.body,
    fontSize: 16,
    height: 1.4,
    fontWeight: FontWeight.w500,
  );
  static const bodySmall = TextStyle(
    fontFamily: AppFonts.body,
    fontSize: 14,
    height: 1.4,
    fontWeight: FontWeight.w500,
  );
  static const label = TextStyle(
    fontFamily: AppFonts.body,
    fontSize: 12,
    height: 1.3,
    fontWeight: FontWeight.w700,
  );
  static const button = TextStyle(
    fontFamily: AppFonts.display,
    fontSize: 17,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.2,
  );

  /// Material usa estos estilos como base de todos los textos.
  static TextTheme textTheme(Color color) => TextTheme(
    displayLarge: display.copyWith(color: color),
    headlineLarge: title.copyWith(color: color),
    headlineMedium: headline.copyWith(color: color),
    titleLarge: headline.copyWith(color: color),
    titleMedium: body.copyWith(color: color, fontWeight: FontWeight.w700),
    bodyLarge: body.copyWith(color: color),
    bodyMedium: bodySmall.copyWith(color: color),
    bodySmall: label.copyWith(color: color),
    labelLarge: button.copyWith(color: color),
    labelMedium: label.copyWith(color: color),
  );
}
