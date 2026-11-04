import 'package:flutter/material.dart';

/// Paleta natural y sobria de Mirasol.
class MC {
  const MC._();

  static const ink = Color(0xFF26302A);
  static const cream = Color(0xFFF6F1E7);
  static const card = Color(0xFFFBF8F1);
  static const sand = Color(0xFFEAE2D0);
  static const line = Color(0xFFD9CFB9);
  static const olive = Color(0xFF4F6B4A);
  static const sage = Color(0xFFE9EFDD);
  static const leaf = Color(0xFFDCE5D2);
  static const terracotta = Color(0xFFC4704F);
  static const terraLight = Color(0xFFF3E3D6);
  static const terraDark = Color(0xFFA3492A);
  static const sun = Color(0xFFE7B84A);
  static const sunLight = Color(0xFFF3E6C4);
  static const muted = Color(0xFF5C665F);
  static const kitten = Color(0xFF9AA0A6);
}

const List<String> _serifFallback = ['Georgia', 'serif'];

TextStyle displayStyle(double size, {Color color = MC.ink}) => TextStyle(
      fontFamilyFallback: _serifFallback,
      fontWeight: FontWeight.w600,
      fontSize: size,
      color: color,
      height: 1.15,
    );

ThemeData buildTheme() {
  const scheme = ColorScheme.light(
    primary: MC.ink,
    onPrimary: MC.cream,
    secondary: MC.olive,
    onSecondary: MC.cream,
    surface: MC.card,
    onSurface: MC.ink,
    error: MC.terraDark,
    onError: MC.cream,
    outline: MC.line,
  );
  final base = ThemeData(useMaterial3: true, colorScheme: scheme);
  return base.copyWith(
    scaffoldBackgroundColor: MC.cream,
    canvasColor: MC.cream,
    dividerColor: MC.line,
    textTheme: base.textTheme.apply(bodyColor: MC.ink, displayColor: MC.ink),
    appBarTheme: const AppBarTheme(
      backgroundColor: MC.cream,
      foregroundColor: MC.ink,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: MC.ink,
        foregroundColor: MC.cream,
        minimumSize: const Size.fromHeight(52),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: MC.ink,
        minimumSize: const Size.fromHeight(48),
        side: const BorderSide(color: MC.ink, width: 1.5),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: MC.ink,
        minimumSize: const Size(48, 48),
        textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: MC.card,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: MC.line, width: 1.5),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: MC.line, width: 1.5),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: MC.olive, width: 1.5),
      ),
    ),
    sliderTheme: const SliderThemeData(
      activeTrackColor: MC.olive,
      thumbColor: MC.olive,
      inactiveTrackColor: MC.sand,
    ),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.all(MC.card),
      trackColor: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.selected) ? MC.olive : MC.line,
      ),
      trackOutlineColor: WidgetStateProperty.all(Colors.transparent),
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: MC.cream,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: MC.ink,
      contentTextStyle: const TextStyle(color: MC.cream, fontSize: 14),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    ),
  );
}
