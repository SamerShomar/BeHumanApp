import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:be_human_app/core/providers/auth_state_provider.dart';
import 'package:be_human_app/core/theme/app_theme.dart';
import 'package:be_human_app/features/auth/presentation/providers/auth_provider.dart';
import 'package:be_human_app/features/splash/presentation/screens/splash_screen.dart';

/// The splash screen decides where the app starts. These checks are pixel
/// independent, so unlike the golden tests they run everywhere.
void main() {
  /// connectivity_plus reaches for platform channels that do not exist on the
  /// test host, so both the one-shot check and the change stream are stubbed.
  void mockConnectivity({required bool online}) {
    final status = online ? 'wifi' : 'none';
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('dev.fluttercommunity.plus/connectivity'),
      (call) async => <String>[status],
    );
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockStreamHandler(
      const EventChannel('dev.fluttercommunity.plus/connectivity_status'),
      MockStreamHandler.inline(onListen: (arguments, sink) {}),
    );
  }

  /// Stub destinations, so the screen's real `context.go` resolves instead of
  /// throwing and leaving a timer pending.
  Widget wrap(Widget child, {bool signedIn = false}) {
    final router = GoRouter(
      initialLocation: '/',
      routes: [
        GoRoute(path: '/', builder: (_, __) => child),
        GoRoute(path: '/login', builder: (_, __) => const Text('LOGIN')),
        GoRoute(path: '/home', builder: (_, __) => const Text('HOME')),
      ],
    );

    return ProviderScope(
      overrides: [
        isSignedInProvider.overrideWithValue(signedIn),
        // What the splash actually waits on: the settled answer, not the
        // live one.
        signedInResolvedProvider.overrideWith((ref) async => signedIn),
      ],
      child: ScreenUtilInit(
        designSize: const Size(390, 844),
        minTextAdapt: true,
        builder: (context, _) => MaterialApp.router(
          debugShowCheckedModeBanner: false,
          theme: AppTheme.darkTheme(context),
          routerConfig: router,
        ),
      ),
    );
  }

  testWidgets('an already-signed-in user goes straight to the app, even offline',
      (tester) async {
    // Firestore serves reads from its cache and queues writes, so being
    // offline must not block someone who is already authenticated.
    mockConnectivity(online: false);

    await tester.pumpWidget(wrap(const SplashScreen(), signedIn: true));
    await tester.pumpAndSettle(const Duration(seconds: 3));

    expect(find.text('HOME'), findsOneWidget);
  });

  testWidgets('goes to login when online', (tester) async {
    mockConnectivity(online: true);

    await tester.pumpWidget(wrap(const SplashScreen()));
    await tester.pumpAndSettle(const Duration(seconds: 3));

    expect(find.text('LOGIN'), findsOneWidget);
  });

  testWidgets('goes to login when offline, not to a blocking screen',
      (tester) async {
    // There is no offline screen any more. Sign-in is the one thing that
    // genuinely needs the network, so someone who is not signed in still lands
    // on the login screen — which says so itself — rather than on a wall.
    mockConnectivity(online: false);

    await tester.pumpWidget(wrap(const SplashScreen()));
    await tester.pumpAndSettle(const Duration(seconds: 3));

    expect(find.text('LOGIN'), findsOneWidget);
  });
}
