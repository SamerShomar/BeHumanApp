import 'dart:ui';

import 'package:flutter/material.dart';

import 'package:be_human_app/core/theme/app_colors.dart';

/// The backdrop every screen sits on.
///
/// Glass only reads as glass when there is something behind it worth blurring.
/// A flat colour would make every panel look like a grey rectangle, so the app
/// paints a gradient with a few soft colour pools underneath, and the panels
/// blur whatever lands behind them.
class AppBackground extends StatelessWidget {
  const AppBackground({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;

    return Stack(
      children: [
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: dark
                    ? const [AppColors.darkBackground, AppColors.darkBackgroundAlt]
                    : const [AppColors.lightBackground, AppColors.lightBackgroundAlt],
              ),
            ),
          ),
        ),

        // Colour pools. They are the only reason a blurred panel shows any
        // variation across its surface.
        _Blob(
          alignment: const Alignment(-1.1, -0.85),
          color: AppColors.brand.withOpacity(dark ? 0.30 : 0.26),
          size: 320,
        ),
        _Blob(
          alignment: const Alignment(1.2, -0.35),
          color: AppColors.brandDeep.withOpacity(dark ? 0.28 : 0.20),
          size: 280,
        ),
        _Blob(
          alignment: const Alignment(-0.8, 1.1),
          color: (dark ? AppColors.success : AppColors.brand).withOpacity(dark ? 0.16 : 0.18),
          size: 300,
        ),

        // One wide blur over the pools softens them into light rather than
        // three visible circles.
        Positioned.fill(
          child: IgnorePointer(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 60, sigmaY: 60),
              child: const ColoredBox(color: Colors.transparent),
            ),
          ),
        ),

        child,
      ],
    );
  }
}

class _Blob extends StatelessWidget {
  const _Blob({required this.alignment, required this.color, required this.size});

  final Alignment alignment;
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: alignment,
      child: IgnorePointer(
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(colors: [color, color.withOpacity(0)]),
          ),
        ),
      ),
    );
  }
}

/// A frosted panel: the app's one card.
///
/// [blurred] can be turned off inside long scrolling lists, where a separate
/// backdrop filter per row costs more than it adds — the translucent fill and
/// the lit edge already read as glass over the gradient.
class GlassCard extends StatelessWidget {
  const GlassCard({
    required this.child,
    this.padding = const EdgeInsets.all(AppSpacing.lg),
    this.radius = AppRadius.card,
    this.blurred = true,
    this.onTap,
    this.tint,
    super.key,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final double radius;
  final bool blurred;
  final VoidCallback? onTap;

  /// Washes the panel with a meaning colour — an unread notification, an
  /// income total — without turning it into a solid block.
  final Color? tint;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final shape = BorderRadius.circular(radius);

    Widget surface = DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: shape,
        color: tint == null
            ? AppColors.glassFill(dark)
            : Color.alphaBlend(tint!.withOpacity(dark ? 0.20 : 0.16), AppColors.glassFill(dark)),
        border: Border.all(
          color: tint == null
              ? AppColors.glassStroke(dark)
              : tint!.withOpacity(dark ? 0.45 : 0.35),
        ),
      ),
      child: Padding(padding: padding, child: child),
    );

    if (blurred) {
      surface = ClipRRect(
        borderRadius: shape,
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
          child: surface,
        ),
      );
    }

    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: shape,
        boxShadow: [
          BoxShadow(
            color: AppColors.glassShadow(dark),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: onTap == null
          ? surface
          : Material(
              color: Colors.transparent,
              borderRadius: shape,
              clipBehavior: Clip.antiAlias,
              child: InkWell(onTap: onTap, child: surface),
            ),
    );
  }
}

/// A frosted app bar that lets the backdrop show through as content scrolls
/// underneath it.
class GlassAppBar extends StatelessWidget implements PreferredSizeWidget {
  const GlassAppBar({
    required this.title,
    this.actions = const [],
    this.leading,
    this.automaticallyImplyLeading = true,
    super.key,
  });

  final String title;
  final List<Widget> actions;
  final Widget? leading;
  final bool automaticallyImplyLeading;

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;

    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: dark
                ? Colors.white.withOpacity(0.04)
                : Colors.white.withOpacity(0.30),
            border: Border(
              bottom: BorderSide(color: AppColors.glassStroke(dark).withOpacity(0.6)),
            ),
          ),
          child: AppBar(
            title: Text(title),
            actions: actions,
            leading: leading,
            automaticallyImplyLeading: automaticallyImplyLeading,
          ),
        ),
      ),
    );
  }
}
