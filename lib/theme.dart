import 'package:flutter/material.dart';

class AppTheme {
  final String name;
  final IconData icon;
  final Color primary;
  final Color secondary;
  final Color accent;
  final Color bgTop;
  final Color bgBottom;
  final Color surface;
  final Color surfaceVariant;
  final Color onSurface;
  final Color onSurfaceMuted;
  final Color danger;

  const AppTheme({
    required this.name,
    required this.icon,
    required this.primary,
    required this.secondary,
    required this.accent,
    required this.bgTop,
    required this.bgBottom,
    required this.surface,
    required this.surfaceVariant,
    required this.onSurface,
    required this.onSurfaceMuted,
    required this.danger,
  });

  LinearGradient get primaryGradient => LinearGradient(
        colors: [primary, secondary],
      );

  ThemeData get themeData => ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        colorScheme: ColorScheme.dark(
          primary: primary,
          secondary: secondary,
          tertiary: accent,
          surface: surface,
          onSurface: onSurface,
          error: danger,
        ),
        scaffoldBackgroundColor: bgTop,
        fontFamily: 'Segoe UI',
        textTheme: const TextTheme(
          displayLarge:
              TextStyle(fontFamily: 'Consolas', fontWeight: FontWeight.w200),
          displayMedium:
              TextStyle(fontFamily: 'Consolas', fontWeight: FontWeight.w300),
          displaySmall:
              TextStyle(fontFamily: 'Consolas', fontWeight: FontWeight.w300),
          headlineMedium: TextStyle(fontWeight: FontWeight.w600),
          titleLarge: TextStyle(fontWeight: FontWeight.w600),
          titleMedium: TextStyle(fontWeight: FontWeight.w500),
          bodyLarge: TextStyle(fontWeight: FontWeight.w400),
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.transparent,
          elevation: 0,
          scrolledUnderElevation: 0,
        ),
      );
}

const List<AppTheme> appThemes = [
  AppTheme(
    name: 'Cyber',
    icon: Icons.bolt,
    primary: Color(0xFF00E5FF),
    secondary: Color(0xFFFF006E),
    accent: Color(0xFF7B2CBF),
    bgTop: Color(0xFF050814),
    bgBottom: Color(0xFF0A0E27),
    surface: Color(0xFF141829),
    surfaceVariant: Color(0xFF1E2340),
    onSurface: Color(0xFFF0F4FF),
    onSurfaceMuted: Color(0xFF8B92B8),
    danger: Color(0xFFFF3B5C),
  ),
  AppTheme(
    name: 'Sunset',
    icon: Icons.wb_twilight,
    primary: Color(0xFFFF6B35),
    secondary: Color(0xFFF7931E),
    accent: Color(0xFFFFD23F),
    bgTop: Color(0xFF1A0E1F),
    bgBottom: Color(0xFF2D1B2E),
    surface: Color(0xFF2D1B2E),
    surfaceVariant: Color(0xFF3D2B3E),
    onSurface: Color(0xFFFFF4E6),
    onSurfaceMuted: Color(0xFFB8A08B),
    danger: Color(0xFFFF3B5C),
  ),
  AppTheme(
    name: 'Forest',
    icon: Icons.forest,
    primary: Color(0xFF00FF9D),
    secondary: Color(0xFF00B8A9),
    accent: Color(0xFF48CAE4),
    bgTop: Color(0xFF05120A),
    bgBottom: Color(0xFF0A1E0F),
    surface: Color(0xFF1A2E1F),
    surfaceVariant: Color(0xFF2A3E2F),
    onSurface: Color(0xFFF0FFF4),
    onSurfaceMuted: Color(0xFF8BB8A0),
    danger: Color(0xFFFF5C7A),
  ),
  AppTheme(
    name: 'Arctic',
    icon: Icons.ac_unit,
    primary: Color(0xFF4FC3F7),
    secondary: Color(0xFF81D4FA),
    accent: Color(0xFFB3E5FC),
    bgTop: Color(0xFF0D1B2A),
    bgBottom: Color(0xFF1B263B),
    surface: Color(0xFF1B263B),
    surfaceVariant: Color(0xFF2B365B),
    onSurface: Color(0xFFE6F4FF),
    onSurfaceMuted: Color(0xFF8BA8B8),
    danger: Color(0xFFFF5C7A),
  ),
];
