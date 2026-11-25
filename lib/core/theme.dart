import 'package:flutter/material.dart';
import 'brand.dart';

/// Design System موحد: الأخضر غالب، والأحمر للإبراز فقط.
class AppTheme {
  static ThemeData light() => _build(
        ColorScheme.light(
          primary: Brand.green,
          onPrimary: Brand.white,
          secondary: Brand.red,
          onSecondary: Brand.white,
          surface: Brand.white,
          onSurface: Brand.gray900,
          error: Brand.error,
          outline: Brand.gray200,
          surfaceContainerHighest: Brand.gray50,
        ),
        scaffold: Brand.gray50,
      );

  static ThemeData dark() => _build(
        ColorScheme.dark(
          primary: Brand.greenLight,
          onPrimary: Brand.white,
          secondary: Brand.red,
          onSecondary: Brand.white,
          surface: const Color(0xFF151A17),
          onSurface: const Color(0xFFE8ECEA),
          error: const Color(0xFFF2B8B5),
          outline: const Color(0xFF38403B),
          surfaceContainerHighest: const Color(0xFF1E2521),
        ),
        scaffold: const Color(0xFF0F1311),
      );

  static ThemeData _build(ColorScheme cs, {required Color scaffold}) {
    final radius = BorderRadius.circular(12);
    return ThemeData(
      useMaterial3: true,
      colorScheme: cs,
      scaffoldBackgroundColor: scaffold,
      fontFamily: 'Cairo', // يرجع للخط الافتراضي إن لم يُضمَّن
      cardTheme: CardThemeData(
        elevation: 0,
        color: cs.surface,
        shape: RoundedRectangleBorder(
          borderRadius: radius,
          side: BorderSide(color: cs.outline),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: cs.surfaceContainerHighest,
        border: OutlineInputBorder(borderRadius: radius, borderSide: BorderSide(color: cs.outline)),
        enabledBorder: OutlineInputBorder(borderRadius: radius, borderSide: BorderSide(color: cs.outline)),
        focusedBorder: OutlineInputBorder(borderRadius: radius, borderSide: BorderSide(color: cs.primary, width: 2)),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(64, 48), // هدف لمس مناسب للأجهزة اللمسية (Android)
          shape: RoundedRectangleBorder(borderRadius: radius),
        ),
      ),
      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: cs.surface,
        indicatorColor: cs.primary.withValues(alpha: 0.12),
      ),
    );
  }
}
