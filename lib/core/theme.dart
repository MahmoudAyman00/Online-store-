import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Single design system for the whole app.
/// Every screen must use these colors / radii / text styles — no hardcoded
/// brand colors in screens anymore.
///
/// DARK MODE contract: brand accents (primary/accent/success/error) are the
/// SAME constants in both modes. Only surfaces + text + soft fills adapt via
/// [BuildContext.cs] (ColorScheme). Screens must use `context.cs.onSurface`
/// instead of `AppColors.textDark`, etc.
class AppColors {
  const AppColors._();

  static const primary = Color(0xFF4F46E5); // indigo-600
  static const primaryDark = Color(0xFF3730A3);
  static const primarySoft = Color(0xFFEEF2FF);
  static const accent = Color(0xFFF59E0B); // amber-500 (stars, highlights)
  static const success = Color(0xFF16A34A);
  static const error = Color(0xFFDC2626);
  static const background = Color(0xFFF5F6FA);
  static const surface = Colors.white;
  static const outline = Color(0xFFE5E7EB);
  static const textDark = Color(0xFF111827);
  static const textMuted = Color(0xFF6B7280);

  // Auth gradient (kept from brand, modernized)
  static const authTop = Color(0xFF4F46E5);
  static const authBottom = Color(0xFF7C3AED);
}

/// Theme-aware surface/text colors — use these in screens, never the
/// light-only AppColors.textDark / textMuted / primarySoft / outline.
extension AppThemeX on BuildContext {
  ColorScheme get cs => Theme.of(this).colorScheme;
  Color get onSurface => cs.onSurface;
  Color get muted => cs.onSurfaceVariant;
  Color get softFill => cs.primaryContainer;
  Color get line => cs.outline;
}

/// Persisted light/dark mode.
class ThemeController {
  static final ValueNotifier<ThemeMode> mode =
      ValueNotifier(ThemeMode.light);
  static const _key = 'themeMode';

  static Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final dark = prefs.getBool(_key) ?? false;
    mode.value = dark ? ThemeMode.dark : ThemeMode.light;
  }

  static Future<void> toggle() async {
    final next =
        mode.value == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark;
    mode.value = next;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_key, next == ThemeMode.dark);
  }
}

class AppRadius {
  const AppRadius._();
  static const card = 16.0;
  static const button = 14.0;
  static const input = 14.0;
}

ThemeData buildAppTheme() {
  const scheme = ColorScheme(
    brightness: Brightness.light,
    primary: AppColors.primary,
    onPrimary: Colors.white,
    primaryContainer: AppColors.primarySoft,
    onPrimaryContainer: AppColors.primaryDark,
    secondary: AppColors.accent,
    onSecondary: Colors.white,
    error: AppColors.error,
    onError: Colors.white,
    surface: AppColors.surface,
    onSurface: AppColors.textDark,
    surfaceContainerHighest: AppColors.background,
    onSurfaceVariant: AppColors.textMuted,
    outline: AppColors.outline,
  );

  return _baseTheme(scheme);
}

ThemeData buildDarkTheme() {
  const scheme = ColorScheme(
    brightness: Brightness.dark,
    primary: Color(0xFF818CF8),
    onPrimary: Color(0xFF141126),
    primaryContainer: Color(0xFF2E2A6E),
    onPrimaryContainer: Color(0xFFE0E7FF),
    secondary: AppColors.accent,
    onSecondary: Color(0xFF1A1206),
    error: Color(0xFFF87171),
    onError: Color(0xFF1A0B0B),
    surface: Color(0xFF1E1F26),
    onSurface: Color(0xFFECECF1),
    surfaceContainerHighest: Color(0xFF131419),
    onSurfaceVariant: Color(0xFFA7AAB5),
    outline: Color(0xFF3A3D47),
  );

  return _baseTheme(scheme);
}

ThemeData _baseTheme(ColorScheme scheme) {
  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: scheme.surfaceContainerHighest,
    fontFamily: 'Roboto',
    appBarTheme: AppBarTheme(
      backgroundColor: scheme.surface,
      foregroundColor: scheme.onSurface,
      elevation: 0,
      centerTitle: true,
      titleTextStyle: TextStyle(
        fontFamily: 'Roboto',
        fontSize: 20,
        fontWeight: FontWeight.bold,
        color: scheme.onSurface,
      ),
    ),
    cardTheme: CardThemeData(
      color: scheme.surface,
      elevation: 2,
      shadowColor: Colors.black.withValues(alpha: 0.08),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.card),
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: scheme.primary,
        foregroundColor: scheme.onPrimary,
        textStyle: const TextStyle(
          fontFamily: 'Roboto',
          fontSize: 16,
          fontWeight: FontWeight.bold,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 15),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.button),
        ),
        elevation: 2,
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: scheme.primary,
        textStyle: const TextStyle(
          fontFamily: 'Roboto',
          fontSize: 15,
          fontWeight: FontWeight.w600,
        ),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: scheme.surface,
      hintStyle: TextStyle(color: scheme.onSurfaceVariant, fontSize: 14),
      contentPadding:
          const EdgeInsets.symmetric(vertical: 15, horizontal: 16),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.input),
        borderSide: BorderSide(color: scheme.outline),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.input),
        borderSide: BorderSide(color: scheme.outline),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.input),
        borderSide: BorderSide(color: scheme.primary, width: 1.6),
      ),
      prefixIconColor: scheme.primary,
    ),
    checkboxTheme: CheckboxThemeData(
      fillColor: WidgetStateProperty.resolveWith(
        (states) =>
            states.contains(WidgetState.selected) ? scheme.primary : null,
      ),
    ),
    progressIndicatorTheme: ProgressIndicatorThemeData(
      color: scheme.primary,
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
    ),
    dividerTheme: DividerThemeData(color: scheme.outline),
    dialogTheme: DialogThemeData(
      backgroundColor: scheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
    ),
  );
}
