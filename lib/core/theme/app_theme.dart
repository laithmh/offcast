import 'package:flutter/material.dart';

class AppTheme {
  AppTheme._();

  // Neumorphic Neutral Colors
  static const Color background = Color(0xFFE9ECEF);
  static const Color surface = Color(0xFFEDF2F7);
  static const Color surfaceElevated = Color(0xFFF1F5F9);
  static const Color surfaceSunken = Color(0xFFE2E8F0);

  // Shadows
  static const Color shadowLight = Color(0xFFFFFFFF);
  static const Color shadowDark = Color(0xFFB8C4D6);

  // Primary & Accent Colors
  static const Color primary = Color(0xFF0284C7); // Glacier Sky Blue
  static const Color primaryLight = Color(0xFFE0F2FE);
  static const Color accent = Color(0xFF6366F1); // Indigo
  static const Color accentLight = Color(0xFFEEF2FF);

  // Status & Feedback Colors
  static const Color success = Color(0xFF10B981); // Emerald Green
  static const Color successLight = Color(0xFFD1FAE5);
  static const Color warning = Color(0xFFF59E0B); // Amber
  static const Color warningLight = Color(0xFFFEF3C7);
  static const Color error = Color(0xFFEF4444); // Rose Red
  static const Color errorLight = Color(0xFFFEE2E2);

  // Typography Colors
  static const Color textPrimary = Color(0xFF1E293B);
  static const Color textSecondary = Color(0xFF64748B);
  static const Color textMuted = Color(0xFF94A3B8);

  // Neumorphic Decorations
  static List<BoxShadow> get neumorphicShadowElevated => const [
    BoxShadow(
      color: shadowLight,
      offset: Offset(-4, -4),
      blurRadius: 8,
      spreadRadius: 1,
    ),
    BoxShadow(
      color: shadowDark,
      offset: Offset(4, 4),
      blurRadius: 8,
      spreadRadius: 1,
    ),
  ];

  static List<BoxShadow> get neumorphicShadowSunken => const [
    BoxShadow(
      color: shadowDark,
      offset: Offset(2, 2),
      blurRadius: 4,
      spreadRadius: 0,
    ),
    BoxShadow(
      color: shadowLight,
      offset: Offset(-2, -2),
      blurRadius: 4,
      spreadRadius: 0,
    ),
  ];

  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      scaffoldBackgroundColor: background,
      colorScheme: const ColorScheme.light(
        primary: primary,
        secondary: accent,
        surface: surface,
        error: error,
        onPrimary: Colors.white,
        onSecondary: Colors.white,
        onSurface: textPrimary,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: background,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        iconTheme: IconThemeData(color: textPrimary),
        titleTextStyle: TextStyle(
          color: textPrimary,
          fontSize: 18,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.3,
        ),
      ),
      cardTheme: CardThemeData(
        color: surface,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          textStyle: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.4,
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surfaceSunken,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 20,
          vertical: 16,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: primary, width: 2),
        ),
        labelStyle: const TextStyle(
          color: textSecondary,
          fontWeight: FontWeight.w500,
        ),
        hintStyle: const TextStyle(color: textMuted),
      ),
    );
  }
}
