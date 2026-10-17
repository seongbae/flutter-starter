import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';

/// Navy-and-green palette taken from the Traqker logo. The board always
/// renders in light mode; the rest of the app keeps following the user's
/// theme choice.
class BoardColors {
  BoardColors._();

  static const Color navy = Color(0xFF253060); // logo navy
  static const Color green = Color(0xFF1DDB77); // logo green
  static const Color bg = Color(0xFFF4F5FA);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color ink = Color(0xFF1A2140);
  static const Color inkSoft = Color(0xFF5B6385);
  static const Color chip = Color(0xFFE5E8F1);
  static const Color line = Color(0xFFD9DDEA);
}

class BoardTheme {
  BoardTheme._();

  static final ThemeData data = AppTheme.build(
    brightness: Brightness.light,
    primary: BoardColors.navy,
    onPrimary: Colors.white,
    secondary: BoardColors.green,
    onSecondary: BoardColors.navy,
    bg: BoardColors.bg,
    surface: BoardColors.surface,
    ink: BoardColors.ink,
    inkSoft: BoardColors.inkSoft,
    chip: BoardColors.chip,
    line: BoardColors.line,
    navActive: BoardColors.navy,
  );
}
