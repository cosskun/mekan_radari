import 'package:flutter/material.dart';

class AppColors {
  // Light Background & Surface Palette
  static const Color background = Color(0xFFF8FAFC); // Soft clean off-white
  static const Color surface = Colors.white;         // Crisp card white
  static const Color surfaceElevated = Color(0xFFFFFFFF);
  static const Color headerBackground = Colors.white;
  static const Color cardBorder = Color(0xFFE2E8F0);  // Subtle refined border
  static const Color divider = Color(0xFFE2E8F0);
  static const Color inputBackground = Color(0xFFF1F5F9); // Light pill background

  // Text Hierarchy
  static const Color textPrimary = Color(0xFF0F172A);   // Deep readable slate
  static const Color textSecondary = Color(0xFF475569); // Muted slate
  static const Color textTertiary = Color(0xFF64748B);  // Subtle captions
  static const Color textDisabled = Color(0xFF94A3B8);

  // Brand & Warm Accents
  static const Color primary = Color(0xFFF59E0B);       // Warm amber/gold
  static const Color primaryDark = Color(0xFFD97706);
  static const Color primaryLight = Color(0xFFFEF3C7);  // Warm soft chip bg

  // Supporting Accents
  static const Color blue = Color(0xFF0284C7);          // Distance / Geolocation
  static const Color blueLight = Color(0xFFE0F2FE);     // Blue chip bg
  static const Color green = Color(0xFF16A34A);         // Open now status
  static const Color greenLight = Color(0xFFDCFCE7);    // Green chip bg
  static const Color red = Color(0xFFEF4444);           // Favorites / Closed
  static const Color redLight = Color(0xFFFEE2E2);

  // Subtle shadows for cards
  static const List<BoxShadow> cardShadow = [
    BoxShadow(
      color: Color(0x0A000000),
      blurRadius: 10,
      offset: Offset(0, 4),
    ),
  ];

  static const List<BoxShadow> elevatedShadow = [
    BoxShadow(
      color: Color(0x12000000),
      blurRadius: 16,
      offset: Offset(0, 6),
    ),
  ];
}

class AppTheme {
  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      scaffoldBackgroundColor: AppColors.background,
      fontFamily: null,
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.primary,
        brightness: Brightness.light,
        primary: AppColors.primary,
        secondary: AppColors.blue,
        surface: AppColors.surface,
        onSurface: AppColors.textPrimary,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.surface,
        elevation: 0,
        scrolledUnderElevation: 1,
        surfaceTintColor: Colors.transparent,
        iconTheme: IconThemeData(color: AppColors.textPrimary),
        titleTextStyle: TextStyle(
          color: AppColors.textPrimary,
          fontSize: 18,
          fontWeight: FontWeight.bold,
        ),
      ),
      cardTheme: CardThemeData(
        color: AppColors.surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: const BorderSide(color: AppColors.cardBorder),
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: AppColors.divider,
        thickness: 1,
      ),
    );
  }
}
