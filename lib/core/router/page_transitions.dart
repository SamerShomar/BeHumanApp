import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Motion shared by every route in the app.
///
/// Two kinds, because tabs and drill-downs mean different things.
///
/// Switching tabs is not travel — the destination is not "further in", it is
/// somewhere else at the same level. Sliding a whole screen across for it is
/// what made the bar feel slow, which is why these used to have no transition
/// at all. A **fade through** is the middle ground: the outgoing screen leaves
/// before the incoming one arrives, so the two never smear across each other,
/// and the new screen settles up from a hair under full size.
///
/// Opening a document or a folder *is* travel, so it keeps a directional
/// push — from the end of the reading direction, so an Arabic screen enters
/// from the left where it belongs.
abstract final class AppTransitions {
  /// Long enough to read as motion, short enough not to be a wait. Under about
  /// 200ms a fade reads as a flicker; over about 350ms a bottom bar feels
  /// unresponsive.
  static const Duration tabDuration = Duration(milliseconds: 260);
  static const Duration pushDuration = Duration(milliseconds: 320);

  /// A tab, faded through.
  static Page<void> tab(LocalKey key, Widget child) {
    return CustomTransitionPage<void>(
      key: key,
      child: child,
      transitionDuration: tabDuration,
      // Faster on the way out than in: the screen being left should not hold
      // the eye while its replacement is already arriving.
      reverseTransitionDuration: const Duration(milliseconds: 180),
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        // The incoming screen waits out the first third, which is what stops
        // the two overlapping mid-fade and reading as a smear.
        final fade = CurvedAnimation(
          parent: animation,
          curve: const Interval(0.35, 1, curve: Curves.easeOut),
          reverseCurve: const Interval(0, 1, curve: Curves.easeIn),
        );
        final scale = Tween<double>(begin: 0.97, end: 1).animate(
          CurvedAnimation(parent: animation, curve: Curves.easeOutCubic),
        );

        return FadeTransition(
          opacity: fade,
          child: ScaleTransition(scale: scale, child: child),
        );
      },
    );
  }

  /// A screen opened from another one, pushed in from the end edge.
  static Page<void> push(LocalKey key, Widget child) {
    return CustomTransitionPage<void>(
      key: key,
      child: child,
      transitionDuration: pushDuration,
      reverseTransitionDuration: const Duration(milliseconds: 240),
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        // Directional: `1.0` is the end edge, which is the right in English
        // and the left in Arabic. A hardcoded offset would have an Arabic
        // screen arriving from the side it is read towards.
        final slide = Tween<Offset>(
          begin: const Offset(1, 0),
          end: Offset.zero,
        ).animate(CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutCubic,
          reverseCurve: Curves.easeInCubic,
        ));

        // The screen underneath drifts back a little rather than sitting still,
        // so the new one reads as arriving on top of it.
        final settle = Tween<Offset>(
          begin: Offset.zero,
          end: const Offset(-0.18, 0),
        ).animate(CurvedAnimation(
          parent: secondaryAnimation,
          curve: Curves.easeOutCubic,
        ));

        return SlideTransition(
          position: settle,
          child: SlideTransition(
            position: slide,
            child: FadeTransition(opacity: animation, child: child),
          ),
        );
      },
    );
  }
}
