import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';

import 'package:be_human_app/core/languages/app_localizations.dart';
import 'package:be_human_app/core/widgets/glass.dart';
import 'package:be_human_app/core/utils/connectivity.dart';
import 'package:be_human_app/features/auth/presentation/providers/auth_provider.dart';

/// Branded launch screen.
///
/// Runs the connectivity check behind the logo animation rather than after it,
/// so the wait is the animation's length and not the sum of both.
class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen>
    with SingleTickerProviderStateMixin {
  static const _animationDuration = Duration(milliseconds: 1600);

  late final AnimationController _controller;
  late final Animation<double> _logoScale;
  late final Animation<double> _logoFade;
  late final Animation<double> _textFade;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(vsync: this, duration: _animationDuration);

    // The logo settles with a slight overshoot, then the wordmark fades in
    // behind it — a sequence rather than everything appearing at once.
    _logoFade = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.0, 0.45, curve: Curves.easeOut),
    );
    _logoScale = Tween<double>(begin: 0.82, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.55, curve: Curves.easeOutBack),
      ),
    );
    _textFade = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.4, 0.8, curve: Curves.easeOut),
    );

    _controller.forward();
    _decideNextRoute();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _decideNextRoute() async {
    // The animation is the only thing held for now. Connectivity used to be
    // checked here to decide whether to show a blocking screen; nothing is
    // blocked on it any more, so waiting on it would only delay the app.
    await Future<void>.delayed(_animationDuration);
    if (!mounted) return;

    final isSignedIn = ref.read(isSignedInProvider);

    // An already-signed-in user can keep working offline: Firestore serves
    // reads from its cache and queues writes until the network returns. Only
    // someone who still has to authenticate is actually blocked, since that
    // round-trip cannot be cached — and the login screen says so itself now,
    // rather than a whole screen standing in front of the app.
    context.go(isSignedIn ? '/home' : '/login');
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: Colors.transparent,
      // The launch screens paint their own backdrop: they sit outside the
      // shell, above which the app-wide one is installed.
      body: AppBackground(
        child: SafeArea(
          child: Stack(
            children: [
              Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    FadeTransition(
                      opacity: _logoFade,
                      child: ScaleTransition(
                        scale: _logoScale,
                        child: Container(
                          padding: EdgeInsets.all(28.r),
                          decoration: BoxDecoration(
                            // The logo mark is dark navy, so it needs a light
                            // disc behind it in both themes — on a translucent
                            // dark circle it nearly disappears.
                            shape: BoxShape.circle,
                            color: Colors.white,
                            boxShadow: [
                              BoxShadow(
                                color: scheme.primary.withOpacity(isDark ? 0.25 : 0.18),
                                blurRadius: 40.r,
                                spreadRadius: 4.r,
                              ),
                            ],
                          ),
                          child: Image.asset(
                            'assets/images/logo.png',
                            width: 132.w,
                            height: 132.w,
                            fit: BoxFit.contain,
                            errorBuilder: (_, __, ___) => Icon(
                              Icons.volunteer_activism,
                              size: 96.w,
                              color: scheme.primary,
                            ),
                          ),
                        ),
                      ),
                    ),
                    SizedBox(height: 32.h),
                    FadeTransition(
                      opacity: _textFade,
                      child: Column(
                        children: [
                          Text(
                            AppLocalizations.of(context, 'splash_title'),
                            style: TextStyle(
                              fontSize: 30.sp,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1.2,
                              color: scheme.primary,
                            ),
                          ),
                          SizedBox(height: 8.h),
                          Text(
                            AppLocalizations.of(context, 'app_title'),
                            style: TextStyle(
                              fontSize: 14.sp,
                              color: scheme.onSurface.withOpacity(0.55),
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              Positioned(
                left: 0,
                right: 0,
                bottom: 48.h,
                child: FadeTransition(
                  opacity: _textFade,
                  child: Center(
                    child: SizedBox(
                      width: 28.w,
                      height: 28.w,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.4,
                        valueColor: AlwaysStoppedAnimation(
                          scheme.primary.withOpacity(0.7),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
