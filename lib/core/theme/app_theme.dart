import 'package:flutter/material.dart';

import 'package:be_human_app/core/theme/app_colors.dart';

/// The app's visual system.
///
/// Everything a screen needs — text sizes, button shapes, card radii — is
/// defined once here. Screens should read from `Theme.of(context)` rather than
/// hard-coding a `fontSize` or a colour, which is how the app previously ended
/// up with five different heading sizes and four card radii.
class AppTheme {
  const AppTheme._();

  static ThemeData lightTheme(BuildContext context) => _build(dark: false);

  static ThemeData darkTheme(BuildContext context) => _build(dark: true);

  static ThemeData _build({required bool dark}) {
    final scheme = dark
        ? const ColorScheme.dark(
            primary: AppColors.brand,
            secondary: AppColors.brandDeep,
            surface: Color(0xFF0D1B2A),
            onPrimary: Colors.white,
            onSurface: AppColors.darkInk,
            error: AppColors.danger,
          )
        : const ColorScheme.light(
            primary: AppColors.brand,
            secondary: AppColors.brandDeep,
            surface: Colors.white,
            onPrimary: Colors.white,
            onSurface: AppColors.lightInk,
            error: AppColors.danger,
          );

    final ink = scheme.onSurface;

    // One scale, used everywhere. Weight carries hierarchy, not size alone:
    // when every label was bold, nothing stood out.
    //
    // Built by copying the platform's own styles rather than constructing bare
    // TextStyles, so each one keeps the font family and fallback chain the
    // device provides — which is what renders Arabic correctly.
    final base = dark
        ? Typography.material2021().white
        : Typography.material2021().black;

    final text = TextTheme(
      displaySmall: base.displaySmall!.copyWith(fontSize: 30, fontWeight: FontWeight.w700, color: ink, height: 1.2),
      headlineMedium: base.headlineMedium!.copyWith(fontSize: 24, fontWeight: FontWeight.w700, color: ink, height: 1.25),
      headlineSmall: base.headlineSmall!.copyWith(fontSize: 20, fontWeight: FontWeight.w700, color: ink, height: 1.3),
      titleLarge: base.titleLarge!.copyWith(fontSize: 18, fontWeight: FontWeight.w600, color: ink, height: 1.35),
      titleMedium: base.titleMedium!.copyWith(fontSize: 16, fontWeight: FontWeight.w600, color: ink, height: 1.4),
      titleSmall: base.titleSmall!.copyWith(fontSize: 14, fontWeight: FontWeight.w600, color: ink, height: 1.4),
      bodyLarge: base.bodyLarge!.copyWith(fontSize: 16, fontWeight: FontWeight.w400, color: ink, height: 1.5),
      bodyMedium: base.bodyMedium!.copyWith(fontSize: 14, fontWeight: FontWeight.w400, color: ink.withOpacity(0.78), height: 1.5),
      bodySmall: base.bodySmall!.copyWith(fontSize: 12, fontWeight: FontWeight.w400, color: ink.withOpacity(0.62), height: 1.45),
      labelLarge: base.labelLarge!.copyWith(fontSize: 14, fontWeight: FontWeight.w600, color: ink, height: 1.2),
      labelSmall: base.labelSmall!.copyWith(fontSize: 11, fontWeight: FontWeight.w600, color: ink.withOpacity(0.7), height: 1.2),
    );

    return ThemeData(
      useMaterial3: true,
      brightness: dark ? Brightness.dark : Brightness.light,
      colorScheme: scheme,
      textTheme: text,

      // Screens sit on the app's gradient backdrop, so the Scaffold itself
      // must not paint over it.
      scaffoldBackgroundColor: Colors.transparent,

      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        iconTheme: IconThemeData(color: ink),
        titleTextStyle: text.headlineSmall,
      ),

      cardTheme: CardThemeData(
        color: AppColors.glassFill(dark),
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.card),
          side: BorderSide(color: AppColors.glassStroke(dark)),
        ),
      ),

      // A filled, unmistakable primary action. Before this, "change password"
      // and "log out" were rendered identically by the M3 defaults.
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.brand,
          foregroundColor: Colors.white,
          disabledBackgroundColor: AppColors.brand.withOpacity(0.4),
          disabledForegroundColor: Colors.white70,
          elevation: 0,
          minimumSize: const Size.fromHeight(52),
          textStyle: text.labelLarge,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.button),
          ),
        ),
      ),

      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: ink,
          minimumSize: const Size.fromHeight(52),
          textStyle: text.labelLarge,
          side: BorderSide(color: ink.withOpacity(0.22)),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.button),
          ),
        ),
      ),

      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.brand,
          textStyle: text.labelLarge,
        ),
      ),

      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: AppColors.brand,
        foregroundColor: Colors.white,
        // Elevation draws a hard dark ring over the dark backdrop; the button
        // is already the only saturated block on the screen.
        elevation: 0,
        focusElevation: 0,
        hoverElevation: 0,
        highlightElevation: 0,
        extendedTextStyle: text.labelLarge?.copyWith(color: Colors.white),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.button),
        ),
      ),

      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: dark ? Colors.white.withOpacity(0.06) : Colors.white.withOpacity(0.7),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.button),
          borderSide: BorderSide(color: AppColors.glassStroke(dark)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.button),
          borderSide: BorderSide(color: ink.withOpacity(0.14)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.button),
          borderSide: const BorderSide(color: AppColors.brand, width: 1.6),
        ),
        labelStyle: text.bodyMedium,
        hintStyle: text.bodySmall,
      ),

      dialogTheme: DialogThemeData(
        backgroundColor: dark ? const Color(0xFF122238) : Colors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.card),
          side: BorderSide(color: AppColors.glassStroke(dark)),
        ),
        titleTextStyle: text.titleLarge,
        contentTextStyle: text.bodyMedium,
      ),

      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: dark ? const Color(0xFF14273F) : const Color(0xFF12263C),
        contentTextStyle: text.bodyMedium?.copyWith(color: Colors.white),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.button),
        ),
      ),

      listTileTheme: ListTileThemeData(
        titleTextStyle: text.titleMedium,
        subtitleTextStyle: text.bodySmall,
        iconColor: ink.withOpacity(0.7),
      ),

      dividerTheme: DividerThemeData(
        color: ink.withOpacity(0.08),
        thickness: 1,
        space: 1,
      ),

      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected) ? Colors.white : null,
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected) ? AppColors.brand : null,
        ),
      ),

      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: AppColors.brand,
      ),
    );
  }
}
