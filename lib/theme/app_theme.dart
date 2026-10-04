import 'package:flutter/material.dart';

/// Soft, low-stimulation colours. Each task colour has a light and a dark
/// variant, both chosen so dark/light text on them stays readable.
class TaskPalette {
  static const _light = <Color>[
    Color(0xFFFFD8B5), // apricot
    Color(0xFFC9E4C5), // sage
    Color(0xFFBFDDF5), // sky
    Color(0xFFE2D1F7), // lilac
    Color(0xFFFBE3A2), // butter
    Color(0xFFF7C6D0), // rose
    Color(0xFFB9E6E0), // mint
    Color(0xFFD9D4CC), // stone
  ];

  static const _dark = <Color>[
    Color(0xFF7A4A2A),
    Color(0xFF3F5E3B),
    Color(0xFF2F5675),
    Color(0xFF574174),
    Color(0xFF6E5A1E),
    Color(0xFF74404C),
    Color(0xFF2E625B),
    Color(0xFF55504A),
  ];

  static const names = [
    'Apricot',
    'Sage',
    'Sky',
    'Lilac',
    'Butter',
    'Rose',
    'Mint',
    'Stone',
  ];

  static int get length => _light.length;

  static Color of(BuildContext context, int index) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final list = dark ? _dark : _light;
    return list[index.abs() % list.length];
  }

  /// Text colour to use on top of [of].
  static Color onColor(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark
      ? const Color(0xFFF5F1EA)
      : const Color(0xFF2B2622);
}

class AppTheme {
  static const seed = Color(0xFFE8875B);

  static ThemeData light() => _build(Brightness.light);
  static ThemeData dark() => _build(Brightness.dark);

  static ThemeData _build(Brightness brightness) {
    final scheme = ColorScheme.fromSeed(
      seedColor: seed,
      brightness: brightness,
      surface: brightness == Brightness.light
          ? const Color(0xFFFFFBF6)
          : const Color(0xFF1C1917),
    );
    final base = ThemeData(
      colorScheme: scheme,
      useMaterial3: true,
      brightness: brightness,
      scaffoldBackgroundColor: scheme.surface,
    );
    return base.copyWith(
      appBarTheme: AppBarTheme(
        backgroundColor: scheme.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: base.textTheme.titleLarge?.copyWith(
          fontWeight: FontWeight.w700,
          color: scheme.onSurface,
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: scheme.surfaceContainerLow,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        margin: EdgeInsets.zero,
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: scheme.primary,
        foregroundColor: scheme.onPrimary,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
      chipTheme: base.chipTheme.copyWith(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: scheme.surfaceContainerHighest.withValues(alpha: 0.5),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(64, 52),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        showDragHandle: true,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
      ),
      snackBarTheme: const SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}
