import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

class AppTheme {
  static ThemeData darkTheme(BuildContext context) {
    return ThemeData(
      useMaterial3: true,
      scaffoldBackgroundColor: const Color(0xFF0A1628),
      colorScheme: const ColorScheme.dark(
        primary: Color(0xFF4A90D9),
        secondary: Color(0xFF2D6A9F),
        surface: Color(0xFF0D1B2A),
        onPrimary: Colors.white,
        onSurface: Colors.white,
        error: Colors.redAccent,
      ),
    );
  }

  static ThemeData lightTheme(BuildContext context) {
    return ThemeData(
      useMaterial3: true,
      scaffoldBackgroundColor: const Color(0xFFF0F4F8),
      colorScheme: const ColorScheme.light(
        primary: Color(0xFF4A90D9),
        secondary: Color(0xFF5BA0F2),
        surface: Colors.white,
        onPrimary: Colors.white,
        onSurface: Colors.black87,
        error: Colors.redAccent,
      ),
    );
  }

  static BoxDecoration glassCardDark() {
    return BoxDecoration(
      color: Colors.white.withOpacity(0.05),
      borderRadius: BorderRadius.circular(16.r),
      border: Border.all(color: Colors.white.withOpacity(0.1)),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(0.2),
          blurRadius: 10.r,
          offset: const Offset(0, 4),
        ),
      ],
    );
  }

  static BoxDecoration glassCardLight() {
    return BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16.r),
      border: Border.all(color: Colors.grey.withOpacity(0.2)),
      boxShadow: [
        BoxShadow(
          color: Colors.grey.withOpacity(0.1),
          blurRadius: 4.r,
          offset: const Offset(0, 2),
        ),
      ],
    );
  }

  static BoxDecoration statCardDark(Color color) {
    return BoxDecoration(
      color: color.withOpacity(0.1),
      borderRadius: BorderRadius.circular(12.r),
      border: Border.all(color: color.withOpacity(0.3)),
      boxShadow: [
        BoxShadow(
          color: color.withOpacity(0.2),
          blurRadius: 8.r,
          offset: const Offset(0, 2),
        ),
      ],
    );
  }

  static BoxDecoration statCardLight(Color color) {
    return BoxDecoration(
      color: color.withOpacity(0.1),
      borderRadius: BorderRadius.circular(12.r),
      border: Border.all(color: color.withOpacity(0.2)),
      boxShadow: [
        BoxShadow(
          color: color.withOpacity(0.1),
          blurRadius: 4.r,
          offset: const Offset(0, 1),
        ),
      ],
    );
  }
}