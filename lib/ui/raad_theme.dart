import 'package:flutter/material.dart';

abstract final class RaadColors {
  static const background = Color(0xFF07080D);
  static const surface = Color(0xFF10141E);
  static const surfaceElevated = Color(0xFF161B28);
  static const cardBorder = Color(0x1FFFFFFF);
  static const cyanAccent = Color(0xFF00E5FF);
  static const cyanGlow = Color(0x3300E5FF);
  static const electricBlue = Color(0xFF38B6FF);
  static const textPrimary = Color(0xFFF8FAFC);
  static const textSecondary = Color(0xFF94A3B8);
  static const textMuted = Color(0xFF64748B);
  static const success = Color(0xFF10B981);
  static const error = Color(0xFFFF5252);
}

final class RaadTheme {
  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: RaadColors.background,
      colorScheme: const ColorScheme.dark(
        primary: RaadColors.cyanAccent,
        onPrimary: RaadColors.background,
        secondary: RaadColors.electricBlue,
        surface: RaadColors.surface,
        onSurface: RaadColors.textPrimary,
        error: RaadColors.error,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: RaadColors.background,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        iconTheme: IconThemeData(color: RaadColors.textPrimary),
        titleTextStyle: TextStyle(
          color: RaadColors.textPrimary,
          fontSize: 20,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.3,
        ),
      ),
      cardTheme: CardThemeData(
        color: RaadColors.surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: RaadColors.cardBorder),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: RaadColors.surface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: RaadColors.cardBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: RaadColors.cardBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(
            color: RaadColors.cyanAccent,
            width: 1.6,
          ),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: RaadColors.error),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: RaadColors.error, width: 1.6),
        ),
        labelStyle: const TextStyle(color: RaadColors.textSecondary),
        floatingLabelStyle: const TextStyle(color: RaadColors.cyanAccent),
        hintStyle: const TextStyle(color: RaadColors.textMuted),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 18,
          vertical: 16,
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: RaadColors.cyanAccent,
          foregroundColor: RaadColors.background,
          disabledBackgroundColor: RaadColors.cyanAccent.withValues(
            alpha: 0.25,
          ),
          disabledForegroundColor: RaadColors.background.withValues(alpha: 0.5),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          textStyle: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.2,
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: RaadColors.textSecondary,
          textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: RaadColors.surfaceElevated,
        labelStyle: const TextStyle(
          color: RaadColors.cyanAccent,
          fontSize: 12,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.5,
        ),
        side: const BorderSide(color: Color(0x3300E5FF)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }
}
