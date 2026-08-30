import 'package:flutter/material.dart';

/// Light palette. Cold places sit in sage and recede; a place warms through
/// coral and settles on red once it is yours.
abstract final class Ember {
  static const red = Color(0xFFE26868);
  static const coral = Color(0xFFFF8787);
  static const sage = Color(0xFFD8D9CF);
  static const paper = Color(0xFFEDEDED);
  static const card = Color(0xFFFFFFFF);

  /// Derived from the four palette colours; the source set carries no dark
  /// value, and text needs one.
  static const deepRed = Color(0xFFB94F4F);
  static const ink = Color(0xFF2E2E2B);
  static const muted = Color(0xFF87887E);
  static const line = Color(0xFFCFD0C6);
}

ThemeData emberTheme() {
  const scheme = ColorScheme.light(
    primary: Ember.red,
    onPrimary: Colors.white,
    secondary: Ember.sage,
    onSecondary: Ember.ink,
    surface: Ember.card,
    onSurface: Ember.ink,
    error: Ember.deepRed,
  );

  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: Ember.paper,
    textTheme: const TextTheme(
      displayLarge: TextStyle(fontWeight: FontWeight.w900, letterSpacing: -1, color: Ember.ink),
      titleLarge: TextStyle(fontWeight: FontWeight.w800, color: Ember.ink),
      titleMedium: TextStyle(fontWeight: FontWeight.w700, color: Ember.ink),
      bodyMedium: TextStyle(color: Ember.ink),
      labelSmall: TextStyle(
        color: Ember.muted,
        letterSpacing: 1.8,
        fontWeight: FontWeight.w600,
        fontSize: 10,
      ),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: Ember.card,
      indicatorColor: Ember.coral.withValues(alpha: 0.28),
      labelTextStyle: const WidgetStatePropertyAll(
        TextStyle(fontSize: 10, letterSpacing: 1.2, color: Ember.muted),
      ),
    ),
    bottomSheetTheme: const BottomSheetThemeData(backgroundColor: Ember.card),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: Ember.red,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(9)),
        padding: const EdgeInsets.symmetric(vertical: 15),
        textStyle: const TextStyle(
          fontWeight: FontWeight.w800,
          letterSpacing: 1.4,
          fontSize: 13,
        ),
      ),
    ),
  );
}
