import 'package:flutter/material.dart';
import 'pv_colors.dart';

class PvTheme {
  static ThemeData get dark => ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: PvColors.background,
        colorScheme: const ColorScheme.dark(
          primary: PvColors.tier4,
          secondary: PvColors.tier3,
          surface: PvColors.surface,
          error: PvColors.error,
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: PvColors.background,
          foregroundColor: PvColors.onBackground,
          elevation: 0,
          centerTitle: false,
        ),
        cardTheme: const CardThemeData(
          color: PvColors.surface,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(12)),
          ),
        ),
        dividerTheme: const DividerThemeData(
          color: PvColors.border,
          thickness: 1,
        ),
        textTheme: const TextTheme(
          headlineMedium: TextStyle(
            color: PvColors.onBackground,
            fontSize: 24,
            fontWeight: FontWeight.w700,
          ),
          titleMedium: TextStyle(
            color: PvColors.onBackground,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
          bodyMedium: TextStyle(color: PvColors.onSurface, fontSize: 15),
          bodySmall: TextStyle(color: PvColors.muted, fontSize: 13),
        ),
      );

  PvTheme._();
}
