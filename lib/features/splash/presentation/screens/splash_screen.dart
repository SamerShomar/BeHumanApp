import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:be_human_app/core/languages/app_localizations.dart';
import 'package:be_human_app/core/theme/app_colors.dart';
import 'package:be_human_app/core/widgets/glass.dart';
import 'package:be_human_app/core/providers/auth_state_provider.dart';

/// Branded launch screen.
///
/// It leaves when the app knows where to go, not when a timer says so — with
/// a floor so the animation is never cut off, and a ceiling so a stalled sign
/// -in check cannot strand anyone here.
class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen>
    with SingleTickerProviderStateMixin {
  /// How long the animation runs, and the shortest this screen is shown.
  static const _animationDuration = Duration(milliseconds: 1500);

  /// The longest anyone waits for Firebase to say who is signed in. Past this
  /// the app continues as signed-out; if the answer arrives later the router's
  /// own redirect moves them on, so nothing is lost but the wait.
  static const _authTimeout = Duration(seconds: 4);

  late final AnimationController _controller;
  late final Animation<double> _markFade;
  late final Animation<double> _markScale;
  late final Animation<double> _ringSweep;
  late final Animation<double> _textFade;
  late final Animation<double> _textRise;

  bool _navigated = false;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(vsync: this, duration: _animationDuration);

    _markFade = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.0, 0.40, curve: Curves.easeOut),
    );
    _markScale = Tween<double>(begin: 0.88, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.55, curve: Curves.easeOutCubic),
      ),
    );
    // A ring that draws itself around the mark. It is the loading indicator —
    // which is why the separate spinner at the bottom is gone: two things
    // saying "wait" is one more than the screen needs.
    _ringSweep = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.10, 0.85, curve: Curves.easeInOut),
    );
    _textFade = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.35, 0.75, curve: Curves.easeOut),
    );
    _textRise = Tween<double>(begin: 14, end: 0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.35, 0.80, curve: Curves.easeOutCubic),
      ),
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
    // Both, not one after the other: the animation is a floor on the wait, not
    // an addition to it.
    //
    // Waiting for the auth state matters. It used to read whatever the
    // provider happened to hold after a fixed delay — and on a cold start
    // Firebase often has not answered by then, so an already-signed-in user
    // was sent to the login screen and bounced to the home screen a moment
    // later by the router's redirect. That flash is what made this screen look
    // like it was misbehaving.
    final signedIn = await Future.wait([
      _resolveSignedIn(),
      Future<void>.delayed(_animationDuration),
    ]).then((results) => results.first as bool);

    if (!mounted || _navigated) return;
    _navigated = true;
    context.go(signedIn ? '/home' : '/login');
  }

  /// Waits for Firebase to report who is signed in, giving up after
  /// [_authTimeout].
  Future<bool> _resolveSignedIn() async {
    try {
      return await ref
          .read(signedInResolvedProvider.future)
          .timeout(_authTimeout);
    } catch (_) {
      // A timeout, or a stream that failed. Neither should hold the app here:
      // continue as signed-out, and let the router's redirect move them on if
      // the answer turns up later.
      return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: Colors.transparent,
      // The launch screen paints its own backdrop: it sits outside the shell,
      // above which the app-wide one is installed.
      body: AppBackground(
        child: SafeArea(
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                FadeTransition(
                  opacity: _markFade,
                  child: ScaleTransition(
                    scale: _markScale,
                    child: _Mark(sweep: _ringSweep, dark: dark),
                  ),
                ),
                const SizedBox(height: 36),
                AnimatedBuilder(
                  animation: _controller,
                  builder: (context, child) => Opacity(
                    opacity: _textFade.value,
                    child: Transform.translate(
                      offset: Offset(0, _textRise.value),
                      child: child,
                    ),
                  ),
                  child: Column(
                    children: [
                      Text(
                        AppLocalizations.of(context, 'splash_title'),
                        textAlign: TextAlign.center,
                        style: theme.textTheme.headlineMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: 10),
                      // A hairline between the name and the tagline, the width
                      // of neither — it reads as a mark rather than a divider.
                      Container(
                        width: 44,
                        height: 2,
                        decoration: BoxDecoration(
                          color: AppColors.brand.withOpacity(0.55),
                          borderRadius: BorderRadius.circular(AppRadius.pill),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 40),
                        child: Text(
                          AppLocalizations.of(context, 'app_title'),
                          textAlign: TextAlign.center,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurface.withOpacity(0.6),
                            letterSpacing: 0.4,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The logo on its disc, with a ring that draws itself around it.
class _Mark extends StatelessWidget {
  const _Mark({required this.sweep, required this.dark});

  final Animation<double> sweep;
  final bool dark;

  static const double _size = 168;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: _size,
      height: _size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // The progress ring, doubling as the only "please wait" on screen.
          AnimatedBuilder(
            animation: sweep,
            builder: (context, _) => CustomPaint(
              size: const Size.square(_size),
              painter: _RingPainter(
                progress: sweep.value,
                trackColor: AppColors.brand.withOpacity(dark ? 0.16 : 0.12),
                color: AppColors.brand,
              ),
            ),
          ),
          Container(
            width: _size - 34,
            height: _size - 34,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              // White in both themes: the mark is dark navy and disappears on
              // a translucent dark disc.
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: AppColors.brand.withOpacity(dark ? 0.28 : 0.18),
                  blurRadius: 36,
                  spreadRadius: 2,
                ),
              ],
            ),
            padding: const EdgeInsets.all(22),
            child: Image.asset(
              'assets/images/logo.png',
              fit: BoxFit.contain,
              errorBuilder: (_, __, ___) => const Icon(
                Icons.volunteer_activism,
                size: 64,
                color: AppColors.brand,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  const _RingPainter({
    required this.progress,
    required this.color,
    required this.trackColor,
  });

  final double progress;
  final Color color;
  final Color trackColor;

  @override
  void paint(Canvas canvas, Size size) {
    const stroke = 3.0;
    final rect = Offset.zero & size;
    final center = rect.center;
    final radius = (size.shortestSide - stroke) / 2;

    final track = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..color = trackColor;
    canvas.drawCircle(center, radius, track);

    if (progress <= 0) return;

    final arc = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round
      ..color = color;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      // From the top, clockwise.
      -1.5707963267948966,
      6.283185307179586 * progress,
      false,
      arc,
    );
  }

  @override
  bool shouldRepaint(_RingPainter oldDelegate) =>
      oldDelegate.progress != progress ||
      oldDelegate.color != color ||
      oldDelegate.trackColor != trackColor;
}
