import 'package:flutter/material.dart';

import 'beef_colors.dart';

/// BEEF dark theme — bold type, high-contrast campy warmth. Original look, not
/// Grindr's trade dress. Typography leans on heavy weights + wide tracking for
/// the "cut above the rest" display voice (bundling the Unbounded / Space
/// Grotesk TTFs from design/store is a later polish step).
abstract final class BeefTheme {
  static ThemeData get dark {
    final ColorScheme scheme = ColorScheme.fromSeed(
      seedColor: BeefColors.steak,
      brightness: Brightness.dark,
    ).copyWith(
      primary: BeefColors.steak,
      onPrimary: BeefColors.cream,
      secondary: BeefColors.sizzle,
      onSecondary: BeefColors.char,
      tertiary: BeefColors.berry,
      onTertiary: BeefColors.cream,
      surface: BeefColors.char,
      onSurface: BeefColors.cream,
      error: BeefColors.steak,
      onError: BeefColors.cream,
      outline: BeefColors.cream.withValues(alpha: 0.25),
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: scheme,
      scaffoldBackgroundColor: BeefColors.char,
      appBarTheme: const AppBarTheme(
        backgroundColor: BeefColors.char,
        foregroundColor: BeefColors.cream,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: TextStyle(
          color: BeefColors.cream,
          fontSize: 20,
          fontWeight: FontWeight.w900,
          letterSpacing: 2,
        ),
      ),
      textTheme: const TextTheme(
        displayLarge: TextStyle(
          color: BeefColors.cream,
          fontSize: 56,
          fontWeight: FontWeight.w900,
          letterSpacing: 4,
          height: 1.0,
        ),
        displayMedium: TextStyle(
          color: BeefColors.cream,
          fontSize: 40,
          fontWeight: FontWeight.w900,
          letterSpacing: 2,
          height: 1.1,
        ),
        headlineMedium: TextStyle(
          color: BeefColors.cream,
          fontSize: 28,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.5,
          height: 1.2,
        ),
        titleLarge: TextStyle(
          color: BeefColors.cream,
          fontSize: 22,
          fontWeight: FontWeight.w800,
          height: 1.3,
        ),
        bodyLarge: TextStyle(
          color: BeefColors.cream,
          fontSize: 16,
          height: 1.4,
        ),
        bodyMedium: TextStyle(
          color: BeefColors.cream,
          fontSize: 14,
          height: 1.4,
        ),
        labelLarge: TextStyle(
          color: BeefColors.cream,
          fontSize: 16,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.5,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: BeefColors.cream.withValues(alpha: 0.06),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 20,
          vertical: 18,
        ),
        labelStyle: const TextStyle(color: BeefColors.cream),
        hintStyle: TextStyle(color: BeefColors.cream.withValues(alpha: 0.45)),
        prefixIconColor: BeefColors.sizzle,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(
            color: BeefColors.cream.withValues(alpha: 0.15),
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: BeefColors.sizzle, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: BeefColors.steak),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: BeefColors.steak, width: 2),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: BeefColors.steak,
          foregroundColor: BeefColors.cream,
          minimumSize: const Size.fromHeight(56),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          textStyle: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.5,
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(foregroundColor: BeefColors.lime),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: BeefColors.cream,
          minimumSize: const Size.fromHeight(56),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
    );
  }
}
