import 'package:flutter/material.dart';
import 'app_theme.dart';

/// Palette ported from the Cadence app (super8b-mobile).
class CadenceColors {
  CadenceColors._();

  static const Color primary = Color(0xFFA5CE53); // muted lime green
  static const Color accent = Color(0xFFEE7E4F); // soft coral orange
  static const Color onPrimary = Color(0xFF0B0C0B);

  /// [primary] is too pale to read on white, so the light theme uses a deeper
  /// green for the selected tab and text buttons.
  static const Color navActiveLight = Color(0xFF5C8A1E);

  static const Color lightBg = Color(0xFFF1F3F0);
  static const Color lightSurface = Color(0xFFFFFFFF);
  static const Color lightInk = Color(0xFF0E1110);
  static const Color lightInkSoft = Color(0xFF6B7177);
  static const Color lightChip = Color(0xFFE9ECE7);
  static const Color lightLine = Color(0xFFE1E5DF);

  static const Color darkBg = Color(0xFF0B0C0B);
  static const Color darkSurface = Color(0xFF15171A);
  static const Color darkInk = Color(0xFFF2F4F2);
  static const Color darkInkSoft = Color(0xFF878D92);
  static const Color darkChip = Color(0xFF1C1F22);
  static const Color darkLine = Color(0xFF2A2E31);
}

class CadenceTheme {
  CadenceTheme._();

  static ThemeData get light => AppTheme.build(
        brightness: Brightness.light,
        primary: CadenceColors.primary,
        onPrimary: CadenceColors.onPrimary,
        secondary: CadenceColors.accent,
        onSecondary: CadenceColors.onPrimary,
        bg: CadenceColors.lightBg,
        surface: CadenceColors.lightSurface,
        ink: CadenceColors.lightInk,
        inkSoft: CadenceColors.lightInkSoft,
        chip: CadenceColors.lightChip,
        line: CadenceColors.lightLine,
        navActive: CadenceColors.navActiveLight,
      );

  static ThemeData get dark => AppTheme.build(
        brightness: Brightness.dark,
        primary: CadenceColors.primary,
        onPrimary: CadenceColors.onPrimary,
        secondary: CadenceColors.accent,
        onSecondary: CadenceColors.onPrimary,
        bg: CadenceColors.darkBg,
        surface: CadenceColors.darkSurface,
        ink: CadenceColors.darkInk,
        inkSoft: CadenceColors.darkInkSoft,
        chip: CadenceColors.darkChip,
        line: CadenceColors.darkLine,
        navActive: CadenceColors.primary,
      );
}
