import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:be_human_app/core/router/app_router.dart';
import 'package:be_human_app/core/services/push_service.dart';
import 'package:be_human_app/features/auth/domain/entities/app_user.dart';
import 'package:be_human_app/features/auth/presentation/providers/auth_provider.dart';

/// Records this device against whoever is signed in, so push notifications
/// know where to go.
///
/// It wraps the whole app rather than living on a screen: registration has to
/// happen once per session no matter where the user lands after signing in,
/// and it must survive navigation.
class PushRegistrar extends ConsumerStatefulWidget {
  const PushRegistrar({required this.child, super.key});

  final Widget child;

  @override
  ConsumerState<PushRegistrar> createState() => _PushRegistrarState();
}

class _PushRegistrarState extends ConsumerState<PushRegistrar> {
  /// The uid already registered, so a profile stream that re-emits — which it
  /// does on every avatar or role change — does not re-request permission.
  String? _registeredUid;

  StreamSubscription<String>? _openedSubscription;

  @override
  void dispose() {
    _openedSubscription?.cancel();
    super.dispose();
  }

  /// Starts listening for notification taps, once per session.
  ///
  /// Without this an alert opened the app and left it wherever it happened to
  /// be — the point of tapping "a proposal was submitted" is to arrive at the
  /// proposal, not at the home screen.
  void _listenForTaps() {
    if (_openedSubscription != null) return;

    try {
      final push = ref.read(pushServiceProvider);
      _openedSubscription = push.openedRoutes.listen(_go);

      // A tap that launched the app from cold has no stream to arrive on; it
      // is collected once, here.
      push.initialRoute().then((route) {
        if (route != null) _go(route);
      });
    } catch (_) {
      // No messaging on this build. In-app notifications are unaffected.
    }
  }

  void _go(String route) {
    if (!mounted) return;
    // Deferred: a tap can be delivered mid-frame, and the router must not be
    // driven from inside a build.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) ref.read(routerProvider).go(route);
    });
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<AsyncValue<AppUser?>>(currentUserStreamProvider, (_, next) {
      final uid = next.valueOrNull?.uid;
      if (uid == null || uid == _registeredUid) return;

      _registeredUid = uid;

      // Deferred to after the frame: registering asks the OS for notification
      // permission and talks to Google Play services, and neither belongs in
      // the middle of building the first screen.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        // Reading the provider is inside the guard too: on a build with no
        // Firebase messaging available it throws on construction, and a
        // missing push channel must never take the app down with it.
        try {
          ref.read(pushServiceProvider).register(uid);
        } catch (_) {
          // In-app notifications still work; only closed-app alerts are lost.
        }
        _listenForTaps();
      });
    });

    return widget.child;
  }
}
