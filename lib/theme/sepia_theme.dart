import 'package:flutter/material.dart';

import '../models/app_settings.dart';

VisualDensity _densityFor(double uiScale) {
  final base = VisualDensity.adaptivePlatformDensity;
  final offset = (uiScale - 1) * 4;
  return VisualDensity(
    horizontal: (base.horizontal + offset).clamp(
      VisualDensity.minimumDensity,
      VisualDensity.maximumDensity,
    ),
    vertical: (base.vertical + offset).clamp(
      VisualDensity.minimumDensity,
      VisualDensity.maximumDensity,
    ),
  );
}

ThemeData buildSepiaTheme(AppSettings settings, Brightness brightness) {
  final requestedDark = brightness == Brightness.dark;
  final isAmoled = requestedDark && settings.amoledTheme;
  final background = isAmoled
      ? Colors.black
      : requestedDark
      ? settings.darkAppBackground
      : settings.appBackground;
  final effectiveBrightness = ThemeData.estimateBrightnessForColor(background);
  final isDark = effectiveBrightness == Brightness.dark;
  final foreground = _foregroundFor(background);
  final generated = ColorScheme.fromSeed(
    seedColor: settings.seedColor,
    brightness: effectiveBrightness,
  );
  final surfaces = _surfaceScale(background, isDark: isDark, amoled: isAmoled);
  final scheme = generated.copyWith(
    surface: background,
    onSurface: foreground,
    onSurfaceVariant: foreground.withValues(alpha: .72),
    surfaceDim: surfaces.dim,
    surfaceBright: surfaces.bright,
    surfaceContainerLowest: surfaces.lowest,
    surfaceContainerLow: surfaces.low,
    surfaceContainer: surfaces.container,
    surfaceContainerHigh: surfaces.high,
    surfaceContainerHighest: surfaces.highest,
    outline: foreground.withValues(alpha: .46),
    outlineVariant: foreground.withValues(alpha: .2),
  );
  return ThemeData(
    useMaterial3: true,
    brightness: effectiveBrightness,
    colorScheme: scheme,
    scaffoldBackgroundColor: background,
    canvasColor: background,
    fontFamily: 'Inter',
    // Controls are sized around their text, so the same scale has to reach
    // them: without this, turning the interface up grew the labels inside
    // buttons that stayed the same height.
    //
    // Offset from the platform's own default rather than from zero. On
    // desktop — and so in the web build, which is how this is mostly read —
    // that default is `compact`, and starting from zero silently loosened
    // every button, ListTile and Chip with no way to get the old spacing
    // back.
    visualDensity: _densityFor(settings.uiScale),
    appBarTheme: AppBarTheme(
      backgroundColor: background,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
    ),
    cardTheme: CardThemeData(
      color: scheme.surfaceContainerLow,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        side: BorderSide(color: scheme.outlineVariant.withValues(alpha: .55)),
        borderRadius: BorderRadius.circular(20),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: scheme.surfaceContainerLow,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(
          color: scheme.outlineVariant.withValues(alpha: .6),
        ),
      ),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      // A floating bar that still clears the gesture navigation area, so a
      // notification reads as something laid over the app rather than stuck
      // to the very bottom of the screen.
      insetPadding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    ),
    dividerTheme: DividerThemeData(
      color: scheme.outlineVariant.withValues(alpha: .6),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: scheme.surfaceContainer,
      surfaceTintColor: Colors.transparent,
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: scheme.surfaceContainerLow,
      surfaceTintColor: Colors.transparent,
    ),
    popupMenuTheme: PopupMenuThemeData(
      color: scheme.surfaceContainerHigh,
      surfaceTintColor: Colors.transparent,
    ),
  );
}

Color _foregroundFor(Color background) =>
    ThemeData.estimateBrightnessForColor(background) == Brightness.dark
    ? const Color(0xFFF7F3EE)
    : const Color(0xFF211A16);

({
  Color dim,
  Color bright,
  Color lowest,
  Color low,
  Color container,
  Color high,
  Color highest,
})
_surfaceScale(Color background, {required bool isDark, required bool amoled}) {
  if (amoled) {
    return (
      dim: Colors.black,
      bright: Colors.black,
      lowest: Colors.black,
      low: Colors.black,
      container: Colors.black,
      high: Colors.black,
      highest: Colors.black,
    );
  }
  if (isDark) {
    return (
      dim: _blend(background, Colors.black, .16),
      bright: _blend(background, Colors.white, .14),
      lowest: _blend(background, Colors.black, .12),
      low: _blend(background, Colors.white, .035),
      container: _blend(background, Colors.white, .065),
      high: _blend(background, Colors.white, .095),
      highest: _blend(background, Colors.white, .14),
    );
  }
  return (
    dim: _blend(background, Colors.black, .08),
    bright: _blend(background, Colors.white, .55),
    lowest: _blend(background, Colors.white, .62),
    low: _blend(background, Colors.black, .018),
    container: _blend(background, Colors.black, .035),
    high: _blend(background, Colors.black, .06),
    highest: _blend(background, Colors.black, .095),
  );
}

Color _blend(Color base, Color overlay, double amount) =>
    Color.alphaBlend(overlay.withValues(alpha: amount), base);
