import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'package:be_human_app/core/router/app_router.dart';
import 'package:be_human_app/core/theme/app_theme.dart';
import 'package:be_human_app/core/languages/app_localizations.dart';
import 'package:be_human_app/core/utils/ensure_users.dart';
import 'package:be_human_app/core/providers/theme_provider.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize Firebase
  await Firebase.initializeApp();
  print('Firebase initialized successfully from google-services.json');
  
  // Create admin account
  try {
    const adminEmail = 'admin@behuman.app';
    const adminPassword = 'Admin@12345678';
    
    final userCredential = await FirebaseAuth.instance.createUserWithEmailAndPassword(
      email: adminEmail,
      password: adminPassword,
    );
    
    if (userCredential.user != null) {
      print('Admin account created successfully: ${userCredential.user!.email}');
      
      // Update user profile
      await userCredential.user!.updateDisplayName('Administrator');
      
      // Send email verification
      await userCredential.user!.sendEmailVerification();
      print('Admin email verification sent');
      
      // Set admin custom claims (optional)
      await userCredential.user!.getIdToken(true);
      print('Admin account setup completed');
    }
  } catch (e) {
    if (e.toString().contains('email-already-in-use')) {
      print('Admin account already exists');
    } else {
      print('Error creating admin account: $e');
    }
  }
  
  // Only ensure users in debug mode and after successful Firebase initialization
  if (kDebugMode) {
    try {
      await ensureUsers();
    } catch (e) {
      print('Error ensuring users: $e');
    }
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
          routerConfig: AppRouter.router,
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
