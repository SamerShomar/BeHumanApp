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
    return Stack(
      children: [
        // Rasterised once and reused. Four overlapping gradients — one linear,
        // three radial — is not cheap to draw, and without a boundary they are
        // redrawn on every frame the app above them animates or scrolls. They
        // never change, so a boundary turns that per-frame cost into a texture
        // the GPU simply blits.
        const RepaintBoundary(child: _Backdrop()),
        child,
      ],
    );
  }
}

class _Backdrop extends StatelessWidget {
  const _Backdrop();

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

        // Colour pools. They are the only reason a panel shows any variation
        // across its surface.
        //
        // These are radial gradients that fade to nothing, not circles behind
        // a blur. A full-screen BackdropFilter used to sit over them to soften
        // the edges — it looked the same and cost a whole-screen GPU filter on
        // every frame, underneath the entire app. On a mid-range Android phone
        // that, stacked with the panels' own filters, was enough to take the
        // process down.
        _Blob(
          alignment: const Alignment(-1.1, -0.85),
          color: AppColors.brand.withOpacity(dark ? 0.26 : 0.22),
          size: 460,
        ),
        _Blob(
          alignment: const Alignment(1.2, -0.35),
          color: AppColors.brandDeep.withOpacity(dark ? 0.24 : 0.17),
          size: 420,
        ),
        _Blob(
          alignment: const Alignment(-0.8, 1.1),
          color: (dark ? AppColors.success : AppColors.brand).withOpacity(dark ? 0.14 : 0.15),
          size: 440,
        ),
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
/// [blurred] defaults to **off**, and that is deliberate. A `BackdropFilter`
/// is a full GPU pass over whatever is behind it; a screen carrying seven of
/// them crashed mid-range Android phones outright. The translucent fill and
/// the lit edge already read as glass over the gradient, which is why the
/// list rows have always looked right without one.
///
/// Turn it on for a *single large panel* that the eye rests on — the sign-in
/// card, a settings group — and never for something that repeats.
class GlassCard extends StatelessWidget {
  const GlassCard({
    required this.child,
    this.padding = const EdgeInsets.all(AppSpacing.lg),
    this.radius = AppRadius.card,
    this.blurred = false,
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

    // A blurred shadow is drawn per card, and a list shows several at once —
    // this was a 24px blur offset 10px down, which is a wide, soft shadow and
    // the most expensive thing a row does. Tightened to roughly half the blur
    // and a shorter drop: the card still lifts off the backdrop, at a fraction
    // of the cost, and the difference is barely visible on a soft gradient.
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: shape,
        boxShadow: [
          BoxShadow(
            color: AppColors.glassShadow(dark),
            blurRadius: 13,
            offset: const Offset(0, 5),
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

    // The blur runs on every frame the app draws — this bar is always on
    // screen, so it is a full-width GPU pass behind every scroll and every
    // animation. Blur cost rises with sigma, and over a backdrop that is
    // already a soft gradient, halving it is close to invisible. Kept rather
    // than removed: content really does scroll under this bar, and the blur is
    // what separates the two.
    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 9, sigmaY: 9),
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
