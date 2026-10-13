import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Brand palette sampled from the reference screens.
class AppColors {
  static const cream = Color(0xFFF4EDE4);
  static const creamLight = Color(0xFFFAF6F0);
  static const card = Color(0xFFFBF7F2);
  static const border = Color(0xFFE8DDCF);
  static const chip = Color(0xFFEDE3D6);
  static const maroon = Color(0xFF6B1520);
  static const maroonDark = Color(0xFF4E0E16);
  static const maroonSoft = Color(0xFFF3DFDC);
  static const gold = Color(0xFFC6A06A);
  static const goldText = Color(0xFFA9824C);
  static const goldButton = Color(0xFFC39D66);
  static const ink = Color(0xFF1E1916);
  static const grey = Color(0xFF6F665F);
  static const greyLight = Color(0xFF9C928A);
  static const green = Color(0xFF1F4A2C);
  static const greenSoft = Color(0xFFE5E8DA);
  static const greenStock = Color(0xFF1E6B3A);
  static const dark = Color(0xFF130D0A);
  static const darkGreen = Color(0xFF0F1A12);
  static const beigeSoft = Color(0xFFEFE3D2);
}

/// Text helpers. The bundled fonts are variable fonts, so weight is set via
/// the `wght` axis as well as [FontWeight].
class T {
  static TextStyle serif(double size,
      {FontWeight weight = FontWeight.w500,
      Color color = AppColors.ink,
      bool italic = false,
      double? height,
      double spacing = -0.3}) {
    return TextStyle(
      fontFamily: 'Playfair',
      fontSize: size,
      fontWeight: weight,
      fontStyle: italic ? FontStyle.italic : FontStyle.normal,
      fontVariations: [FontVariation('wght', weight.value.toDouble())],
      color: color,
      height: height,
      letterSpacing: spacing,
    );
  }

  static TextStyle sans(double size,
      {FontWeight weight = FontWeight.w500,
      Color color = AppColors.ink,
      double? height,
      double spacing = 0}) {
    return TextStyle(
      fontFamily: 'Manrope',
      fontSize: size,
      fontWeight: weight,
      fontVariations: [FontVariation('wght', weight.value.toDouble())],
      color: color,
      height: height,
      letterSpacing: spacing,
    );
  }
}

class AppTheme {
  /// [light] with phone metrics on every browser. Desktop browsers would
  /// otherwise get Material's compact density and shrink-wrapped tap
  /// targets, which changes the layouts the app is designed (and tested) for.
  static ThemeData get web => light.copyWith(
        visualDensity: VisualDensity.standard,
        materialTapTargetSize: MaterialTapTargetSize.padded,
      );

  static ThemeData get light {
    final base = ThemeData(
      useMaterial3: true,
      fontFamily: 'Manrope',
      scaffoldBackgroundColor: AppColors.cream,
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.maroon,
        primary: AppColors.maroon,
        secondary: AppColors.gold,
        surface: AppColors.cream,
      ),
      splashFactory: InkRipple.splashFactory,
    );
    return base.copyWith(
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        systemOverlayStyle: SystemUiOverlayStyle.dark,
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: AppColors.ink,
        behavior: SnackBarBehavior.floating,
        contentTextStyle: T.sans(14, color: Colors.white),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      textSelectionTheme: const TextSelectionThemeData(
        cursorColor: AppColors.maroon,
        selectionHandleColor: AppColors.maroon,
      ),
    );
  }
}

String rupees(num v) {
  final s = v.round().toString();
  // Indian digit grouping: 1,23,456
  if (s.length <= 3) return '₹$s';
  final last3 = s.substring(s.length - 3);
  var rest = s.substring(0, s.length - 3);
  final parts = <String>[];
  while (rest.length > 2) {
    parts.insert(0, rest.substring(rest.length - 2));
    rest = rest.substring(0, rest.length - 2);
  }
  if (rest.isNotEmpty) parts.insert(0, rest);
  return '₹${parts.join(',')},$last3';
}
