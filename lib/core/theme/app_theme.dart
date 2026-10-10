import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../constants/colors.dart';
import 'app_spacing.dart';
import 'cadence_theme.dart';
import 'nav_bar_style.dart';

/// Builds the app's [ThemeData].
///
/// Every color option shares the same typography, shapes and spacing (the
/// Cadence look); only the palette changes. [ColorSeed.cadence] uses
/// Cadence's hand-tuned palette, the others derive one from their seed color.
class AppTheme {
  AppTheme._();

  static ThemeData light(ColorSeed seed) => seed == ColorSeed.cadence
      ? CadenceTheme.light
      : _fromSeed(seed.color, Brightness.light);

  static ThemeData dark(ColorSeed seed) => seed == ColorSeed.cadence
      ? CadenceTheme.dark
      : _fromSeed(seed.color, Brightness.dark);

  static ThemeData _fromSeed(Color seed, Brightness brightness) {
    final scheme =
        ColorScheme.fromSeed(seedColor: seed, brightness: brightness);
    final isLight = brightness == Brightness.light;
    return build(
      brightness: brightness,
      primary: scheme.primary,
      onPrimary: scheme.onPrimary,
      secondary: scheme.secondary,
      onSecondary: scheme.onSecondary,
      bg: isLight ? scheme.surfaceContainerLow : scheme.surface,
      surface: isLight ? scheme.surfaceContainerLowest : scheme.surfaceContainer,
      ink: scheme.onSurface,
      inkSoft: scheme.onSurfaceVariant,
      chip: scheme.surfaceContainerHigh,
      line: scheme.outlineVariant,
      navActive: scheme.primary,
    );
  }

  /// Headings in Archivo (athletic grotesque), body in Inter.
  static TextTheme _textTheme(Color ink, Color inkSoft) {
    TextStyle heading(double size, FontWeight weight) => GoogleFonts.archivo(
          fontSize: size,
          fontWeight: weight,
          color: ink,
          height: 1.04,
          letterSpacing: -0.5,
        );

    TextStyle body(double size, FontWeight weight, {Color? color}) =>
        GoogleFonts.inter(
          fontSize: size,
          fontWeight: weight,
          color: color ?? ink,
          height: 1.4,
        );

    return TextTheme(
      displayLarge: heading(42, FontWeight.w800),
      displayMedium: heading(36, FontWeight.w800),
      displaySmall: heading(32, FontWeight.w800),
      headlineLarge: heading(30, FontWeight.w800),
      headlineMedium: heading(24, FontWeight.w700),
      headlineSmall: heading(20, FontWeight.w700),
      titleLarge: heading(18, FontWeight.w700),
      titleMedium: body(16, FontWeight.w600),
      titleSmall: body(14, FontWeight.w600),
      bodyLarge: body(16, FontWeight.w500),
      bodyMedium: body(14, FontWeight.w500),
      bodySmall: body(12, FontWeight.w500, color: inkSoft),
      labelLarge: body(14, FontWeight.w600),
      labelMedium: body(12, FontWeight.w600),
      labelSmall: body(11, FontWeight.w500, color: inkSoft),
    );
  }

  static ThemeData build({
    required Brightness brightness,
    required Color primary,
    required Color onPrimary,
    required Color secondary,
    required Color onSecondary,
    required Color bg,
    required Color surface,
    required Color ink,
    required Color inkSoft,
    required Color chip,
    required Color line,
    required Color navActive,
  }) {
    // Pin the surface containers to the palette's neutrals so seeded
    // components don't pick up an unexpected tint.
    final scheme = ColorScheme.fromSeed(
      seedColor: primary,
      brightness: brightness,
    ).copyWith(
      primary: primary,
      onPrimary: onPrimary,
      secondary: secondary,
      onSecondary: onSecondary,
      surface: surface,
      onSurface: ink,
      onSurfaceVariant: inkSoft,
      surfaceContainerLowest: surface,
      surfaceContainerLow: surface,
      surfaceContainer: chip,
      surfaceContainerHigh: chip,
      surfaceContainerHighest: chip,
      outlineVariant: line,
    );

    final textTheme = _textTheme(ink, inkSoft);
    final cardShape = RoundedRectangleBorder(
      side: BorderSide(color: line),
      borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
    );
    final buttonShape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
    );
    OutlineInputBorder inputBorder(Color color, [double width = 1]) =>
        OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
          borderSide: BorderSide(color: color, width: width),
        );

    WidgetStateProperty<T> navState<T>(T Function(Color color) build) =>
        WidgetStateProperty.resolveWith(
          (states) => build(
            states.contains(WidgetState.selected) ? navActive : inkSoft,
          ),
        );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      scaffoldBackgroundColor: bg,
      canvasColor: bg,
      cardColor: surface,
      textTheme: textTheme,
      primaryColor: primary,
      dividerColor: line,
      dividerTheme: DividerThemeData(color: line, thickness: 1, space: 1),
      extensions: [NavBarStyle(topBorderColor: line)],
      appBarTheme: AppBarTheme(
        backgroundColor: bg,
        foregroundColor: ink,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: textTheme.titleLarge,
        surfaceTintColor: Colors.transparent,
      ),
      navigationBarTheme: NavigationBarThemeData(
        height: AppSpacing.navBarHeight,
        backgroundColor: surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        indicatorColor: Colors.transparent,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        iconTheme: navState((c) => IconThemeData(size: 24, color: c)),
        labelTextStyle: navState((c) => textTheme.labelSmall!.copyWith(color: c)),
      ),
      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: surface,
        indicatorColor: Colors.transparent,
        selectedIconTheme: IconThemeData(size: 24, color: navActive),
        unselectedIconTheme: IconThemeData(size: 24, color: inkSoft),
        selectedLabelTextStyle:
            textTheme.labelMedium!.copyWith(color: navActive),
        unselectedLabelTextStyle:
            textTheme.labelMedium!.copyWith(color: inkSoft),
      ),
      cardTheme: CardThemeData(
        color: surface,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        clipBehavior: Clip.antiAlias,
        shape: cardShape,
      ),
      listTileTheme: ListTileThemeData(
        titleTextStyle: textTheme.titleSmall,
        subtitleTextStyle: textTheme.bodySmall,
        iconColor: ink,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
        minLeadingWidth: 20,
      ),
      chipTheme: ChipThemeData(
        backgroundColor: chip,
        selectedColor: primary,
        labelStyle: textTheme.labelLarge!,
        side: BorderSide.none,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSpacing.radiusPill),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surface,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.lg,
        ),
        hintStyle: textTheme.bodyMedium!.copyWith(color: inkSoft),
        border: inputBorder(line),
        enabledBorder: inputBorder(line),
        focusedBorder: inputBorder(primary, 1.5),
        errorBorder: inputBorder(scheme.error),
        focusedErrorBorder: inputBorder(scheme.error, 1.5),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: onPrimary,
          elevation: 0,
          // Height only — an infinite min-width explodes inside Rows.
          minimumSize: const Size(0, AppSpacing.buttonHeight),
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
          textStyle: textTheme.titleMedium,
          shape: buttonShape,
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(0, AppSpacing.compactButtonHeight),
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
          textStyle: textTheme.labelLarge,
          shape: buttonShape,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: ink,
          minimumSize: const Size(0, AppSpacing.compactButtonHeight),
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
          textStyle: textTheme.labelLarge,
          side: BorderSide(color: line),
          shape: buttonShape,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: navActive,
          textStyle: textTheme.labelLarge,
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: surface,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: textTheme.titleLarge,
        contentTextStyle: textTheme.bodyMedium,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
        ),
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: surface,
        surfaceTintColor: Colors.transparent,
        textStyle: textTheme.bodyMedium,
        shape: RoundedRectangleBorder(
          side: BorderSide(color: line),
          borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
        ),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: surface,
        surfaceTintColor: Colors.transparent,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(AppSpacing.radiusLg),
          ),
        ),
      ),
    );
  }
}
