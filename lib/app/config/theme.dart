import 'package:flutter/material.dart';

class AppTheme {
  // Brand color palette - Deep indigo/violet with vibrant teal/cyan highlights
  static const Color secondaryColor = Color(0xFF03DAC5);
  static const Color accentColor = Color(0xFFF15A24);

  static ThemeData getLightTheme(Color primarySeedColor) {
    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: primarySeedColor,
        brightness: Brightness.light,
        primary: primarySeedColor,
        secondary: const Color(0xFF5C6175),
        tertiary: accentColor,
        surface: const Color(0xFFF9FAFC),
        surfaceContainer: const Color(0xFFF0F2F8),
      ),
      scaffoldBackgroundColor: const Color(0xFFF9FAFC),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w700,
          color: Color(0xFF1E2022),
        ),
        iconTheme: IconThemeData(color: Color(0xFF1E2022)),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: Color(0xFFE5E7EB), width: 1),
        ),
        color: Colors.white,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: Colors.white,
        indicatorColor: primarySeedColor.withOpacity(0.15),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return TextStyle(fontWeight: FontWeight.w600, fontSize: 12, color: primarySeedColor);
          }
          return const TextStyle(fontWeight: FontWeight.w500, fontSize: 12, color: Color(0xFF6B7280));
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return IconThemeData(color: primarySeedColor, size: 24);
          }
          return const IconThemeData(color: Color(0xFF6B7280), size: 24);
        }),
      ),
      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: Colors.white,
        indicatorColor: primarySeedColor.withOpacity(0.15),
        labelType: NavigationRailLabelType.all,
        selectedLabelTextStyle: TextStyle(fontWeight: FontWeight.w600, fontSize: 12, color: primarySeedColor),
        unselectedLabelTextStyle: const TextStyle(fontWeight: FontWeight.w500, fontSize: 12, color: Color(0xFF6B7280)),
        selectedIconTheme: IconThemeData(color: primarySeedColor, size: 24),
        unselectedIconTheme: const IconThemeData(color: Color(0xFF6B7280), size: 24),
      ),
      textTheme: TextTheme(
        headlineLarge: const TextStyle(fontSize: 32, fontWeight: FontWeight.w800),
        headlineMedium: const TextStyle(fontSize: 24, fontWeight: FontWeight.w700),
        titleLarge: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        bodyLarge: const TextStyle(fontSize: 16, height: 1.5),
        bodyMedium: const TextStyle(fontSize: 14, height: 1.4),
        labelLarge: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: primarySeedColor),
      ),
    );
  }

  static ThemeData getDarkTheme(Color primarySeedColor) {
    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: primarySeedColor,
        brightness: Brightness.dark,
        secondary: const Color(0xFF9CA3AF),
        tertiary: accentColor,
        surface: const Color(0xFF121214),
        surfaceContainer: const Color(0xFF1F1F23),
      ),
      scaffoldBackgroundColor: const Color(0xFF121214),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w700,
          color: Colors.white,
        ),
        iconTheme: IconThemeData(color: Colors.white),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: Color(0xFF2E2E35), width: 1),
        ),
        color: const Color(0xFF1E1E22),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: const Color(0xFF18181C),
        indicatorColor: primarySeedColor.withOpacity(0.15),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return TextStyle(fontWeight: FontWeight.w600, fontSize: 12, color: primarySeedColor);
          }
          return const TextStyle(fontWeight: FontWeight.w500, fontSize: 12, color: Color(0xFF9CA3AF));
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return IconThemeData(color: primarySeedColor, size: 24);
          }
          return const IconThemeData(color: Color(0xFF9CA3AF), size: 24);
        }),
      ),
      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: const Color(0xFF18181C),
        indicatorColor: primarySeedColor.withOpacity(0.15),
        labelType: NavigationRailLabelType.all,
        selectedLabelTextStyle: TextStyle(fontWeight: FontWeight.w600, fontSize: 12, color: primarySeedColor),
        unselectedLabelTextStyle: const TextStyle(fontWeight: FontWeight.w500, fontSize: 12, color: Color(0xFF9CA3AF)),
        selectedIconTheme: IconThemeData(color: primarySeedColor, size: 24),
        unselectedIconTheme: const IconThemeData(color: Color(0xFF9CA3AF), size: 24),
      ),
      textTheme: TextTheme(
        headlineLarge: const TextStyle(fontSize: 32, fontWeight: FontWeight.w800),
        headlineMedium: const TextStyle(fontSize: 24, fontWeight: FontWeight.w700),
        titleLarge: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        bodyLarge: const TextStyle(fontSize: 16, height: 1.5),
        bodyMedium: const TextStyle(fontSize: 14, height: 1.4),
        labelLarge: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: primarySeedColor),
      ),
    );
  }
}
