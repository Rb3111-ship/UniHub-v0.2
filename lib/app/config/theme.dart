import 'package:flutter/material.dart';

/// UniHub look: "Clean & Calm" in light mode, "After Dark" in dark mode.
/// Both share the font, shapes and spacing; only the colours differ.
class AppTheme {
  static const fontFamily = 'PlusJakartaSans';

  // Light ("Clean & Calm")
  static const lightBackground = Color(0xFFF6F7FB);
  static const lightText = Color(0xFF12141C);
  static const lightMuted = Color(0xFF5B6070);
  static const lightChip = Color(0xFFECEEF5);

  // Dark ("After Dark")
  static const darkBackground = Color(0xFF0D0D12);
  static const darkCard = Color(0xFF17171F);
  static const darkBorder = Color(0xFF2A2A36);
  static const darkText = Color(0xFFF4F4F8);
  static const darkMuted = Color(0xFFA3A3B5);
  static const neon = Color(0xFFC8F04A); // main accent in dark mode
  static const violet = Color(0xFF8B7CFF);

  // Status colours used on cards (each passes 4.5:1 on its tint).
  static const urgentText = Color(0xFFB4232A);
  static const urgentTint = Color(0xFFFFE9E9);
  static const urgentTextDark = Color(0xFFFFB4A8);
  static const okText = Color(0xFF137A50);
  static const okTint = Color(0xFFE3F6EE);

  static ThemeData getLightTheme(Color primary) {
    final scheme = ColorScheme.fromSeed(
      seedColor: primary,
      brightness: Brightness.light,
      primary: primary,
      onPrimary: Colors.white,
      secondary: lightMuted,
      tertiary: const Color(0xFFF15A24),
      surface: lightBackground,
      onSurface: lightText,
      surfaceContainer: lightChip,
    );
    return _build(scheme, background: lightBackground, card: Colors.white, border: null, muted: lightMuted);
  }

  /// The university colour stays for official badges; buttons and highlights
  /// use the neon accent in dark mode.
  static ThemeData getDarkTheme(Color universityColor) {
    final scheme = ColorScheme.fromSeed(
      seedColor: universityColor,
      brightness: Brightness.dark,
      primary: neon,
      onPrimary: darkBackground,
      primaryContainer: const Color(0xFF2E3A10),
      onPrimaryContainer: neon,
      secondary: darkMuted,
      tertiary: violet,
      surface: darkBackground,
      onSurface: darkText,
      surfaceContainer: const Color(0xFF1C1C26),
      outlineVariant: darkBorder,
    );
    return _build(scheme, background: darkBackground, card: darkCard, border: darkBorder, muted: darkMuted);
  }

  static ThemeData _build(
    ColorScheme scheme, {
    required Color background,
    required Color card,
    required Color? border,
    required Color muted,
  }) {
    final onSurface = scheme.onSurface;
    final light = border == null;
    final base = ThemeData(useMaterial3: true, colorScheme: scheme, fontFamily: fontFamily);
    return base.copyWith(
      scaffoldBackgroundColor: background,
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          fontFamily: fontFamily,
          fontSize: 22,
          fontWeight: FontWeight.w800,
          letterSpacing: -0.4,
          color: onSurface,
        ),
        iconTheme: IconThemeData(color: onSurface),
      ),
      cardTheme: CardThemeData(
        elevation: light ? 1.5 : 0,
        shadowColor: const Color(0x1A12141C),
        surfaceTintColor: Colors.transparent,
        color: card,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: light ? BorderSide.none : BorderSide(color: border),
        ),
      ),
      chipTheme: base.chipTheme.copyWith(
        backgroundColor: card,
        side: light ? BorderSide.none : BorderSide(color: border),
        shape: const StadiumBorder(),
        labelStyle: TextStyle(fontFamily: fontFamily, fontWeight: FontWeight.w600, color: onSurface),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(64, 48),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          textStyle: const TextStyle(fontFamily: fontFamily, fontWeight: FontWeight.w700, fontSize: 15),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          elevation: 0,
          backgroundColor: scheme.primary,
          foregroundColor: scheme.onPrimary,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          textStyle: const TextStyle(fontFamily: fontFamily, fontWeight: FontWeight.w700),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(64, 48),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          side: BorderSide(color: border ?? const Color(0xFFD5D9E5)),
          textStyle: const TextStyle(fontFamily: fontFamily, fontWeight: FontWeight.w700),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: card,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: light ? BorderSide.none : BorderSide(color: border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: border ?? const Color(0xFFE3E6EF)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: scheme.primary, width: 2),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: light ? Colors.white : const Color(0xFF121219),
        surfaceTintColor: Colors.transparent,
        elevation: light ? 3 : 0,
        shadowColor: const Color(0x1A12141C),
        indicatorColor: scheme.primary.withOpacity(0.16),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return TextStyle(
            fontFamily: fontFamily,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
            fontSize: 12,
            color: selected ? (light ? scheme.primary : onSurface) : muted,
          );
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return IconThemeData(color: selected ? scheme.primary : muted, size: 24);
        }),
      ),
      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: light ? Colors.white : const Color(0xFF121219),
        indicatorColor: scheme.primary.withOpacity(0.16),
        labelType: NavigationRailLabelType.all,
        selectedLabelTextStyle: TextStyle(
            fontFamily: fontFamily, fontWeight: FontWeight.w700, fontSize: 12, color: light ? scheme.primary : onSurface),
        unselectedLabelTextStyle: TextStyle(fontFamily: fontFamily, fontWeight: FontWeight.w600, fontSize: 12, color: muted),
        selectedIconTheme: IconThemeData(color: scheme.primary, size: 24),
        unselectedIconTheme: IconThemeData(color: muted, size: 24),
      ),
      tabBarTheme: TabBarThemeData(
        labelColor: light ? scheme.primary : onSurface,
        unselectedLabelColor: muted,
        indicatorColor: scheme.primary,
        dividerColor: Colors.transparent,
        labelStyle: const TextStyle(fontFamily: fontFamily, fontWeight: FontWeight.w700, fontSize: 13),
        unselectedLabelStyle: const TextStyle(fontFamily: fontFamily, fontWeight: FontWeight.w600, fontSize: 13),
      ),
      textTheme: base.textTheme
          .copyWith(
            headlineLarge: const TextStyle(fontSize: 32, fontWeight: FontWeight.w800, letterSpacing: -0.8),
            headlineMedium: const TextStyle(fontSize: 26, fontWeight: FontWeight.w800, letterSpacing: -0.6),
            titleLarge: const TextStyle(fontSize: 19, fontWeight: FontWeight.w800, letterSpacing: -0.3),
            titleMedium: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            bodyLarge: const TextStyle(fontSize: 16, height: 1.5),
            bodyMedium: const TextStyle(fontSize: 14, height: 1.45),
          )
          .apply(fontFamily: fontFamily, bodyColor: onSurface, displayColor: onSurface)
          .copyWith(
            labelLarge: TextStyle(fontFamily: fontFamily, fontSize: 14, fontWeight: FontWeight.w700, color: scheme.primary),
          ),
    );
  }

  /// Colour for the main call-to-action on a screen (Register, Save, ...).
  static Color accent(BuildContext context) => Theme.of(context).colorScheme.primary;
  static Color onAccent(BuildContext context) => Theme.of(context).colorScheme.onPrimary;
}
