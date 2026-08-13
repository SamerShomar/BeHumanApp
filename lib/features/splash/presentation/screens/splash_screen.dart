import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen> {
  bool _isChecking = true;

  Future<bool> _checkInternet() async {
    // checkConnectivity() returns a list; the device is offline only when
    // every reported result is `none`.
    final results = await Connectivity().checkConnectivity();
    return results.any((r) => r != ConnectivityResult.none);
  }

  @override
  void initState() {
    super.initState();
    _navigateAfterChecks();
  }

  Future<void> _navigateAfterChecks() async {
    setState(() {
      _isChecking = true;
    });

    try {
      // Check internet connection
      final hasInternet = await _checkInternet();

      // Wait 2 seconds for splash animation
      await Future.delayed(const Duration(seconds: 2));

      if (mounted) {
        setState(() {
          _isChecking = false;
        });

        if (hasInternet) {
          // Navigate to login screen
          context.go('/login');
        } else {
          // Navigate to no-internet screen
          context.go('/no-internet');
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isChecking = false;
        });
        // On any error, try to go to login
        context.go('/login');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor:
          isDarkMode ? const Color(0xFF0A1628) : const Color(0xFFF0F4F8),
      body: SafeArea(
        child: Center(
          child: _isChecking
              ? const CircularProgressIndicator()
              : Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Image.asset(
                      'assets/images/logo.PNG',
                      width: 120,
                      height: 120,
                      fit: BoxFit.contain,
                    ),
                    const SizedBox(height: 20),
                    Text(
                      'Be Human',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: colorScheme.primary,
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}
