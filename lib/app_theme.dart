import 'package:flutter/material.dart';

class AppColors {
  static const background = Color(0xFFF6F4EF);
  static const card = Color(0xFFFFFFFF);
  static const ink = Color(0xFF262C36);
  static const muted = Color(0xFF7E8490);
  static const line = Color(0xFFE8E3D8);
  static const accent = Color(0xFFA5814F);
  static const accentSoft = Color(0xFFF3ECDF);
  static const navy = Color(0xFF1B2740);
  static const navyLight = Color(0xFF2A3A5F);
  static const danger = Color(0xFFB4453C);
  static const gold = Color(0xFFC9A86A);
}

ThemeData buildTheme() {
  final scheme = ColorScheme.fromSeed(
    seedColor: AppColors.navy,
    brightness: Brightness.light,
    primary: AppColors.navy,
    secondary: AppColors.accent,
    surface: AppColors.card,
    error: AppColors.danger,
  );
  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: AppColors.background,
    fontFamily: 'Microsoft YaHei',
    dividerColor: AppColors.line,
    cardTheme: CardThemeData(
      color: AppColors.card,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: AppColors.line),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: const Color(0xFFFDFCFB),
      border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppColors.line)),
      enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppColors.line)),
      focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppColors.accent, width: 1.4)),
    ),
    snackBarTheme: const SnackBarThemeData(behavior: SnackBarBehavior.floating),
  );
}
