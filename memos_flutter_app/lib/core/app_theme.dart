import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../data/models/app_preferences.dart';
import 'memoflow_palette.dart';

const List<String> _windowsDefaultFonts = [
  'Microsoft YaHei',
  'Microsoft YaHei UI',
  '寰蒋闆呴粦',
];
const List<String> _windowsDefaultFontFallback = [
  'Microsoft YaHei UI',
  '寰蒋闆呴粦',
];

bool _shouldForceWindowsDefaultFont(AppPreferences prefs) {
  if (kIsWeb || defaultTargetPlatform != TargetPlatform.windows) return false;
  final family = prefs.fontFamily?.trim() ?? '';
  return family.isEmpty;
}

TextTheme _applyLineHeight(TextTheme theme, double height) {
  TextStyle? apply(TextStyle? style) => style?.copyWith(height: height);
  return theme.copyWith(
    bodyLarge: apply(theme.bodyLarge),
    bodyMedium: apply(theme.bodyMedium),
    bodySmall: apply(theme.bodySmall),
    titleLarge: apply(theme.titleLarge),
    titleMedium: apply(theme.titleMedium),
    titleSmall: apply(theme.titleSmall),
  );
}

TextTheme _applyFontFamily(
  TextTheme theme, {
  String? family,
  List<String>? fallback,
}) {
  if (family == null && (fallback == null || fallback.isEmpty)) return theme;
  return theme.apply(fontFamily: family, fontFamilyFallback: fallback);
}

ThemeData buildAppTheme(Brightness brightness) {
  final scaffoldBackgroundColor = brightness == Brightness.dark
      ? MemoFlowPalette.backgroundDark
      : MemoFlowPalette.backgroundLight;
  final seedColor = brightness == Brightness.dark
      ? MemoFlowPalette.primaryDark
      : MemoFlowPalette.primary;
  final baseScheme = ColorScheme.fromSeed(
    seedColor: seedColor,
    brightness: brightness,
  );
  final onPrimary =
      ThemeData.estimateBrightnessForColor(seedColor) == Brightness.dark
          ? Colors.white
          : Colors.black;
  final colorScheme = baseScheme.copyWith(
    primary: seedColor,
    onPrimary: onPrimary,
  );

  return ThemeData(
    colorScheme: colorScheme,
    useMaterial3: true,
    scaffoldBackgroundColor: scaffoldBackgroundColor,
    appBarTheme: AppBarTheme(
      centerTitle: false,
      backgroundColor: scaffoldBackgroundColor.withValues(alpha: 0.9),
      elevation: 0,
      scrolledUnderElevation: 0,
      surfaceTintColor: Colors.transparent,
    ),
    cardTheme: CardThemeData(
      color: brightness == Brightness.dark ? MemoFlowPalette.cardDark : MemoFlowPalette.cardLight,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
      elevation: 0,
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: colorScheme.surfaceContainerHighest,
      contentTextStyle: TextStyle(color: colorScheme.onSurface),
      actionTextColor: colorScheme.primary,
    ),
  );
}

ThemeData applyPreferencesToTheme(ThemeData theme, AppPreferences prefs) {
  final forceWindowsDefault = _shouldForceWindowsDefaultFont(prefs);
  final fontFamily =
      forceWindowsDefault ? _windowsDefaultFonts.first : prefs.fontFamily;
  final fontFallback =
      forceWindowsDefault ? _windowsDefaultFontFallback : null;
  final lineHeight = lineHeightFor(prefs.lineHeight);
  final textTheme = _applyLineHeight(
    _applyFontFamily(
      theme.textTheme,
      family: fontFamily,
      fallback: fontFallback,
    ),
    lineHeight,
  );
  final primaryTextTheme = _applyLineHeight(
    _applyFontFamily(
      theme.primaryTextTheme,
      family: fontFamily,
      fallback: fontFallback,
    ),
    lineHeight,
  );

  return theme.copyWith(
    textTheme: textTheme,
    primaryTextTheme: primaryTextTheme,
  );
}

double textScaleFor(AppFontSize v) {
  return switch (v) {
    AppFontSize.standard => 1.0,
    AppFontSize.large => 1.12,
    AppFontSize.small => 0.92,
  };
}

double lineHeightFor(AppLineHeight v) {
  return switch (v) {
    AppLineHeight.classic => 1.55,
    AppLineHeight.compact => 1.35,
    AppLineHeight.relaxed => 1.75,
  };
}

ThemeMode themeModeFor(AppThemeMode mode) {
  return switch (mode) {
    AppThemeMode.system => ThemeMode.system,
    AppThemeMode.light => ThemeMode.light,
    AppThemeMode.dark => ThemeMode.dark,
  };
}
