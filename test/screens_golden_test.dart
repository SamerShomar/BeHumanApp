@Tags(['golden'])
library;

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:be_human_app/core/theme/app_theme.dart';
import 'package:be_human_app/features/auth/presentation/providers/auth_provider.dart';
import 'package:be_human_app/features/splash/presentation/screens/splash_screen.dart';

/// Renders the launch screens so their layout can be reviewed as an image.
///
/// Golden images are rasterised with the fonts installed on the machine that
/// produced them. The committed images were generated on Linux, so these tests
/// skip elsewhere rather than failing on font differences that say nothing
/// about the app — Windows showed a 21% pixel diff on the text-heavy screen.
///
/// Regenerate after a design change, on Linux:
///
///   flutter test --update-goldens test/screens_golden_test.dart
///
/// The routing behaviour these exercised incidentally is covered, platform
/// independently, by splash_routing_test.dart.
void main() {
  setUpAll(() async {
    // Without real fonts every glyph is an opaque square and every icon an
    // empty box, which hides the layout the goldens exist to show.
    Future<void> load(String family, List<String> paths) async {
      final loader = FontLoader(family);
      var found = false;
      for (final path in paths) {
        final file = File(path);
        if (file.existsSync()) {
          loader.addFont(Future.value(file.readAsBytesSync().buffer.asByteData()));
          found = true;
        }
      }
      if (found) await loader.load();
    }

    await load('Roboto', [
      '/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf',
      '/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf',
    ]);
    await load('MaterialIcons', [
      '${Platform.environment['FLUTTER_ROOT'] ?? ''}'
          '/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf',
    ]);
  });

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

  /// A router with stub destinations, so the screens' real `context.go` calls
  /// resolve instead of throwing and leaving a timer pending.
  Widget wrap(Widget child, {required bool dark}) {
    final router = GoRouter(
      initialLocation: '/',
      routes: [
        GoRoute(path: '/', builder: (_, __) => child),
        GoRoute(path: '/login', builder: (_, __) => const Text('LOGIN')),
        GoRoute(path: '/no-internet', builder: (_, __) => const Text('OFFLINE')),
      ],
    );

    return ProviderScope(
      // The splash asks whether a session exists; without this it would
      // reach for FirebaseAuth.instance, which does not exist in a test.
      overrides: [isSignedInProvider.overrideWithValue(false)],
      child: ScreenUtilInit(
        designSize: const Size(390, 844),
        minTextAdapt: true,
        builder: (context, _) => MaterialApp.router(
          debugShowCheckedModeBanner: false,
          theme: dark ? AppTheme.darkTheme(context) : AppTheme.lightTheme(context),
          routerConfig: router,
        ),
      ),
    );
  }

  void useDeviceViewport(WidgetTester tester) {
    // setSurfaceSize leaves ScreenUtil reading the default 800x600 surface,
    // which inflates every .sp value; driving the view directly does not.
    tester.view.physicalSize = const Size(390 * 3, 844 * 3);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);
  }

  for (final dark in [true, false]) {
    final mode = dark ? 'dark' : 'light';

    testWidgets('splash renders ($mode)', (tester) async {
      useDeviceViewport(tester);
      mockConnectivity(online: true);

      await tester.pumpWidget(wrap(const SplashScreen(), dark: dark));

      // Image.asset decodes asynchronously; without this the logo is missing
      // from the captured frame.
      await tester.runAsync(() async {
        await precacheImage(
          const AssetImage('assets/images/logo.png'),
          tester.element(find.byType(SplashScreen)),
        );
      });

      // Capture mid-animation, before the screen routes away.
      await tester.pump(const Duration(milliseconds: 1500));
      await expectLater(
        find.byType(SplashScreen),
        matchesGoldenFile('goldens/splash_$mode.png'),
      );

      // Let the pending navigation timer run out so the test ends clean.
      await tester.pumpAndSettle(const Duration(seconds: 3));
    }, skip: !Platform.isLinux);

  }
}
