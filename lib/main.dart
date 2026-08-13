import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:be_human_app/core/config/app_config.dart';
import 'package:be_human_app/core/security/inactivity_guard.dart';
import 'package:be_human_app/core/security/security_settings.dart';
import 'package:be_human_app/core/router/app_router.dart';
import 'package:be_human_app/core/theme/app_theme.dart';
import 'package:be_human_app/core/languages/app_localizations.dart';
import 'package:be_human_app/core/providers/theme_provider.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Android reads its configuration from android/app/google-services.json and
  // iOS from ios/Runner/GoogleService-Info.plist.
  await Firebase.initializeApp();

  // Must run before Firestore is touched: it decides whether documents are
  // allowed to persist unencrypted on the device.
  await SecuritySettings.apply();

  // Supabase holds proposal PDFs, which cannot fit in a Firestore document.
  // A build without these keys still runs; only uploading is unavailable.
  if (AppConfig.isStorageConfigured) {
    await Supabase.initialize(
      url: AppConfig.supabaseUrl,
      anonKey: AppConfig.supabaseAnonKey,
    );
  }

  runApp(
    const ProviderScope(
      child: BeHumanApp(),
    ),
  );
}

class BeHumanApp extends ConsumerWidget {
  const BeHumanApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = ref.watch(themeProvider);
    final locale = ref.watch(localeProvider);
    final router = ref.watch(routerProvider);

    return ScreenUtilInit(
      designSize: const Size(390, 844),
      minTextAdapt: true,
      splitScreenMode: true,
      builder: (context, child) {
        return MaterialApp.router(
          title: AppLocalizations.of(context, 'app_title'),
          debugShowCheckedModeBanner: false,
          theme: AppTheme.lightTheme(context),
          darkTheme: AppTheme.darkTheme(context),
          themeMode: isDark ? ThemeMode.dark : ThemeMode.light,
          locale: locale,
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          routerConfig: router,
          builder: (context, child) => InactivityGuard(child: child ?? const SizedBox.shrink()),
          localeResolutionCallback: (locale, supportedLocales) {
            if (locale == null) return supportedLocales.first;
            for (final supportedLocale in supportedLocales) {
              if (supportedLocale.languageCode == locale.languageCode) {
                return supportedLocale;
              }
            }
            return supportedLocales.first;
          },
        );
      },
    );
  }
}
