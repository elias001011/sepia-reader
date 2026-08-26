import 'package:flutter/material.dart';

import '../models/app_settings.dart';

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
    visualDensity: VisualDensity(
      horizontal: ((settings.uiScale - 1) * 4).clamp(-2.0, 2.0),
      vertical: ((settings.uiScale - 1) * 4).clamp(-2.0, 2.0),
    ),
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
