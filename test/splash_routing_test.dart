import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:be_human_app/core/theme/app_theme.dart';
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
  Widget wrap(Widget child) {
    final router = GoRouter(
      initialLocation: '/',
      routes: [
        GoRoute(path: '/', builder: (_, __) => child),
        GoRoute(path: '/login', builder: (_, __) => const Text('LOGIN')),
        GoRoute(path: '/no-internet', builder: (_, __) => const Text('OFFLINE')),
      ],
    );

    return ProviderScope(
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

  testWidgets('goes to login when online', (tester) async {
    mockConnectivity(online: true);

    await tester.pumpWidget(wrap(const SplashScreen()));
    await tester.pumpAndSettle(const Duration(seconds: 3));

    expect(find.text('LOGIN'), findsOneWidget);
  });

  testWidgets('goes to the offline screen when there is no connection',
      (tester) async {
    mockConnectivity(online: false);

    await tester.pumpWidget(wrap(const SplashScreen()));
    await tester.pumpAndSettle(const Duration(seconds: 3));

    expect(find.text('OFFLINE'), findsOneWidget);
  });
}
