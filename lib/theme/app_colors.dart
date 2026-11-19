import 'package:flutter/material.dart';

/// Tokens de color de RutaExpress. El morado sale de la animación del splash.
///
/// Significado fijo: morado = lo que puedes hacer o está activo, verde =
/// hecho, ámbar = atención, rojo = error.
class AppColors {
  AppColors._();

  // Marca
  static const brand = Color(0xFF6A1B9A);
  static const brandBright = Color(0xFF7E23DF);
  static const brandDeep = Color(0xFF4A1273);
  static const brandSoft = Color(0xFFF1E6F8);

  // Sobre fondo morado: texto secundario (lavanda).
  static const lavender = Color(0xFFE1BEE7);
  static const lavenderMuted = Color(0xFFD1B3E0);

  // Superficies y texto (con un tinte violeta, no gris frío)
  static const paper = Color(0xFFFAF7FD);
  static const surface = Color(0xFFFFFFFF);
  static const ink = Color(0xFF1B1230);
  static const grey = Color(0xFF6B6478);
  static const border = Color(0xFFE6DFF0);

  // Estados
  // Entregado: morado profundo con check (sin verde, que le quitaba contraste
  // al resto de la paleta).
  static const done = brandDeep;
  static const doneSoft = Color(0xFFEADFF5);
  static const amber = Color(0xFF8F5600);
  static const amberSoft = Color(0xFFFFF1D6);
  static const red = Color(0xFFC62828);
  static const redSoft = Color(0xFFFDE8E8);

  // Nombres anteriores: se conservan para no tocar todas las pantallas a la
  // vez; apuntan a los tokens nuevos.
  static const canvas = paper;
  static const blue = brandBright;
  static const blueSoft = brandSoft;
  static const orange = amber;
  static const orangeSoft = amberSoft;
}
