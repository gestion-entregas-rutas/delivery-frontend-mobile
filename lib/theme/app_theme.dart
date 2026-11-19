import 'package:flutter/material.dart';

import 'app_colors.dart';
import 'app_text.dart';

/// Tema global. Las pantallas deberían usar estos estilos en lugar de repetir
/// colores y tamaños en línea.
class AppTheme {
  AppTheme._();

  /// Ancho máximo del contenido; en pantallas más anchas se centra.
  static const double maxContentWidth = 560;

  /// Altura mínima de cualquier control táctil.
  static const double minTouchTarget = 48;

  static ThemeData light() {
    final scheme =
        ColorScheme.fromSeed(
          seedColor: AppColors.brand,
          brightness: Brightness.light,
        ).copyWith(
          primary: AppColors.brand,
          onPrimary: Colors.white,
          primaryContainer: AppColors.brandSoft,
          onPrimaryContainer: AppColors.brandDeep,
          secondary: AppColors.brandBright,
          surface: AppColors.surface,
          onSurface: AppColors.ink,
          error: AppColors.red,
          outline: AppColors.border,
        );
    final shape16 = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(16),
    );
    OutlineInputBorder border(Color color, double width) => OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: BorderSide(color: color, width: width),
    );
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: AppColors.paper,
      fontFamily: AppFonts.body,
      textTheme: AppText.textTheme(AppColors.ink),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.brand,
          foregroundColor: Colors.white,
          minimumSize: const Size(64, 56),
          shape: const StadiumBorder(),
          textStyle: AppText.button,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.brand,
          minimumSize: const Size(64, minTouchTarget),
          side: const BorderSide(color: AppColors.border, width: 1.5),
          shape: shape16,
          textStyle: AppText.button.copyWith(fontSize: 15),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.brand,
          minimumSize: const Size(64, minTouchTarget),
          textStyle: AppText.button.copyWith(fontSize: 15),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.brandSoft.withAlpha(120),
        border: border(Colors.transparent, 0),
        enabledBorder: border(Colors.transparent, 0),
        focusedBorder: border(AppColors.brand, 2),
        errorBorder: border(AppColors.red, 1.5),
        focusedErrorBorder: border(AppColors.red, 2),
        labelStyle: AppText.body.copyWith(color: AppColors.grey),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        indicatorColor: AppColors.brandSoft,
        labelTextStyle: WidgetStatePropertyAll(
          AppText.label.copyWith(color: AppColors.ink),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppColors.ink,
        contentTextStyle: AppText.bodySmall.copyWith(color: Colors.white),
        shape: shape16,
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: AppColors.brand,
      ),
    );
  }
}
