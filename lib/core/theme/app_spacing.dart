/// Spacing, radius and size scale (ported from the Cadence app).
///
/// One source of truth keeps padding and corners consistent on every screen.
class AppSpacing {
  AppSpacing._();

  // Spacing scale (logical pixels).
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 24;
  static const double xxl = 32;

  /// Screen edge padding.
  static const double page = 18;

  // Corner radii.
  static const double radiusLg = 20;
  static const double radiusMd = 14;
  static const double radiusSm = 10;
  static const double radiusXs = 6;
  static const double radiusPill = 999;

  // Common control sizes.
  static const double buttonHeight = 54;
  static const double compactButtonHeight = 48;
  static const double navBarHeight = 64;
}
