import 'package:flutter/material.dart';

class AppTheme {
  static const Color brand = Color(0xFF0B5C4D);
  static const Color brandSoft = Color(0xFF147A66);
  static const Color splashOnBrand = Color(0xFFFFFFFF);
  static const Color errorAccent = Color(0xFFE53935);
  static const Color mintSurface = Color(0xFFE8F5F1);

  static const List<Color> seeds = <Color>[
    Color(0xFF0B5C4D),
    Color(0xFF1B7A4C),
    Color(0xFF7DB8A5),
    Color(0xFFE2C48A),
    Color(0xFF9E9E9E),
  ];

  static ThemeData light(Color seed) {
    final scheme = ColorScheme.fromSeed(
      seedColor: seed,
      brightness: Brightness.light,
    );
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme.copyWith(primary: seed),
      scaffoldBackgroundColor: const Color(0xFFF4F7F6),
      appBarTheme: AppBarTheme(
        backgroundColor: seed,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      navigationBarTheme: NavigationBarThemeData(
        indicatorColor: seed.withValues(alpha: 0.18),
        labelTextStyle: WidgetStatePropertyAll(
          TextStyle(fontSize: 11, color: seed),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: seed,
          foregroundColor: Colors.white,
          minimumSize: const Size.fromHeight(48),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    );
  }

  static ThemeData dark(Color seed) {
    final scheme = ColorScheme.fromSeed(
      seedColor: seed,
      brightness: Brightness.dark,
    );
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      appBarTheme: AppBarTheme(
        backgroundColor: seed,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
    );
  }
}
