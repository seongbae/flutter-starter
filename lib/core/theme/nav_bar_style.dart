import 'package:flutter/material.dart';

/// Theme-driven tweaks for the bottom navigation bar that
/// [NavigationBarThemeData] can't express (e.g. a hairline top border).
class NavBarStyle extends ThemeExtension<NavBarStyle> {
  const NavBarStyle({this.topBorderColor});

  /// Draws a 1px line above the bar when non-null.
  final Color? topBorderColor;

  @override
  NavBarStyle copyWith({Color? topBorderColor}) =>
      NavBarStyle(topBorderColor: topBorderColor ?? this.topBorderColor);

  @override
  NavBarStyle lerp(NavBarStyle? other, double t) => NavBarStyle(
        topBorderColor: Color.lerp(topBorderColor, other?.topBorderColor, t),
      );
}
