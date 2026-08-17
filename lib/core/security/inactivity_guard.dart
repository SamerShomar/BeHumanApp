import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:be_human_app/core/security/security_settings.dart';
import 'package:be_human_app/features/auth/presentation/providers/auth_provider.dart';

/// Signs the user out after a period with no interaction.
///
/// An unlocked phone with the app already open is full access to the
/// organisation's records, so leaving a session open indefinitely is the
/// weakest point once a device is out of its owner's hands.
///
/// Wrap the app once, above the router.
class InactivityGuard extends ConsumerStatefulWidget {
  const InactivityGuard({
    super.key,
    required this.child,
    this.timeout = SecuritySettings.inactivityTimeout,
  });

  final Widget child;
  final Duration timeout;

  @override
  ConsumerState<InactivityGuard> createState() => _InactivityGuardState();
}

class _InactivityGuardState extends ConsumerState<InactivityGuard> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _restart();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _restart() {
    _timer?.cancel();
    _timer = Timer(widget.timeout, _signOut);
  }

  Future<void> _signOut() async {
    final auth = ref.read(firebaseAuthProvider);
    if (auth.currentUser == null) return;

    // The router listens to the auth stream, so signing out is enough to send
    // the user back to the login screen.
    await SecuritySettings.signOutAndClearCache(auth);
  }

  @override
  Widget build(BuildContext context) {
    // `behavior: deferToChild` would miss taps on empty areas, and a Listener
    // observes pointer events without competing with the widgets below it.
    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: (_) => _restart(),
      onPointerSignal: (_) => _restart(),
      child: widget.child,
    );
  }
}
