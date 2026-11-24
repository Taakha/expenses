import 'package:flutter/material.dart';

import 'app_colors.dart';

class AppTheme {
  const AppTheme._();

  static ThemeData light() => _build(Brightness.light);

  static ThemeData dark() => _build(Brightness.dark);

  static ThemeData _build(Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    final foreground = isDark ? AppColors.darkText : AppColors.lightTextStrong;
    final muted = isDark ? AppColors.darkMuted : AppColors.lightText;
    final surface = isDark ? const Color(0xFF13383B) : Colors.white;
    final outline = isDark
        ? Colors.white.withValues(alpha: 0.13)
        : AppColors.teal.withValues(alpha: 0.12);
    final scheme = ColorScheme.fromSeed(
      seedColor: AppColors.teal,
      brightness: brightness,
      primary: isDark ? AppColors.aqua : AppColors.tealDark,
      surface: surface,
      error: AppColors.expense,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      scaffoldBackgroundColor: isDark
          ? AppColors.darkCanvas
          : AppColors.lightCanvas,
      fontFamily: 'Roboto',
      textTheme: TextTheme(
        displaySmall: TextStyle(
          color: foreground,
          fontSize: 28,
          height: 1.08,
          fontWeight: FontWeight.w800,
          letterSpacing: -0.8,
        ),
        headlineMedium: TextStyle(
          color: foreground,
          fontSize: 24,
          height: 1.12,
          fontWeight: FontWeight.w800,
          letterSpacing: -0.5,
        ),
        titleLarge: TextStyle(
          color: foreground,
          fontSize: 18,
          fontWeight: FontWeight.w700,
        ),
        titleMedium: TextStyle(
          color: foreground,
          fontSize: 15,
          fontWeight: FontWeight.w700,
        ),
        bodyLarge: TextStyle(color: foreground, fontSize: 14, height: 1.4),
        bodyMedium: TextStyle(color: muted, fontSize: 13, height: 1.4),
        bodySmall: TextStyle(color: muted, fontSize: 11, height: 1.35),
        labelLarge: TextStyle(
          color: foreground,
          fontSize: 13,
          fontWeight: FontWeight.w700,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: isDark
            ? const Color(0xFF0B2B2F)
            : Colors.white.withValues(alpha: 0.93),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 15,
          vertical: 13,
        ),
        labelStyle: TextStyle(color: muted, fontSize: 13),
        prefixIconColor: isDark ? AppColors.aqua : AppColors.tealDark,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),
          borderSide: BorderSide(color: outline),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),
          borderSide: BorderSide(color: outline),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),
          borderSide: BorderSide(color: scheme.primary, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),
          borderSide: const BorderSide(color: AppColors.expense),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(0, 48),
          backgroundColor: isDark ? AppColors.teal : AppColors.tealDark,
          foregroundColor: Colors.white,
          textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(0, 46),
          foregroundColor: scheme.primary,
          side: BorderSide(color: scheme.primary.withValues(alpha: 0.4)),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15),
          ),
        ),
      ),
      cardTheme: CardThemeData(
        color: surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: outline),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        height: 66,
        backgroundColor: surface.withValues(alpha: 0.96),
        indicatorColor: scheme.primary.withValues(alpha: 0.13),
        labelTextStyle: WidgetStateProperty.resolveWith(
          (states) => TextStyle(
            fontSize: 10,
            fontWeight: states.contains(WidgetState.selected)
                ? FontWeight.w700
                : FontWeight.w500,
            color: states.contains(WidgetState.selected)
                ? scheme.primary
                : muted,
          ),
        ),
      ),
      dividerTheme: DividerThemeData(color: outline, thickness: 1, space: 1),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    );
  }
}
