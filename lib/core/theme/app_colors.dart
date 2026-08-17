import 'package:flutter/material.dart';

/// The palette, in one place.
///
/// Screens used to invent their own colours — `Colors.blue` here, a hex code
/// there — so the same idea (an expense, a rejected proposal) looked different
/// depending on where you saw it. Everything visual now comes from here.
abstract final class AppColors {
  /// The foundation's blue, kept from the logo.
  static const Color brand = Color(0xFF4A90D9);
  static const Color brandDeep = Color(0xFF2D6A9F);

  /// Meaning, not decoration: these three carry status everywhere in the app.
  static const Color success = Color(0xFF22C55E);
  static const Color warning = Color(0xFFF59E0B);
  static const Color danger = Color(0xFFEF4444);

  // Light surfaces.
  static const Color lightBackground = Color(0xFFEDF3FB);
  static const Color lightBackgroundAlt = Color(0xFFDCE7F6);
  static const Color lightInk = Color(0xFF0F2138);

  // Dark surfaces.
  static const Color darkBackground = Color(0xFF060D1A);
  static const Color darkBackgroundAlt = Color(0xFF0E2038);
  static const Color darkInk = Color(0xFFEAF2FB);

  /// Fill and edge of a glass panel. Glass is a thin translucent layer over a
  /// blurred backdrop, so both are deliberately faint — the depth comes from
  /// the blur and the border catching the light, not from opacity.
  static Color glassFill(bool dark) =>
      dark ? Colors.white.withOpacity(0.07) : Colors.white.withOpacity(0.62);

  static Color glassStroke(bool dark) =>
      dark ? Colors.white.withOpacity(0.14) : Colors.white.withOpacity(0.85);

  static Color glassShadow(bool dark) =>
      dark ? Colors.black.withOpacity(0.45) : const Color(0xFF1B3A5C).withOpacity(0.10);
}

/// One radius scale. Cards were previously 12, 16, 20 and 24 in different
/// screens, which reads as carelessness even when nobody can name why.
abstract final class AppRadius {
  static const double small = 12;
  static const double card = 20;
  static const double button = 16;
  static const double pill = 999;
}

/// One spacing scale, so gaps line up across screens.
abstract final class AppSpacing {
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 24;
  static const double xxl = 32;
}
