import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';

import 'package:be_human_app/core/languages/app_localizations.dart';
import 'package:be_human_app/core/utils/connectivity.dart';

/// Shown when the device has no network.
///
/// As well as the manual retry, this watches the connectivity stream and moves
/// on by itself the moment the connection returns, so a user who reconnects
/// does not have to notice and press anything.
class NoInternetScreen extends ConsumerStatefulWidget {
  const NoInternetScreen({super.key});

  @override
  ConsumerState<NoInternetScreen> createState() => _NoInternetScreenState();
}

class _NoInternetScreenState extends ConsumerState<NoInternetScreen> {
  bool _isChecking = false;
  StreamSubscription<List<ConnectivityResult>>? _subscription;

  @override
  void initState() {
    super.initState();
    _subscription = Connectivity().onConnectivityChanged.listen((results) {
      if (results.any((r) => r != ConnectivityResult.none)) {
        _goOnline();
      }
    });
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  void _goOnline() {
    if (!mounted) return;
    context.go('/login');
  }

  Future<void> _retry() async {
    setState(() => _isChecking = true);

    // A visible pause, otherwise a failed retry looks like the button did
    // nothing at all.
    final results = await Future.wait([
      hasNetworkConnection(),
      Future<void>.delayed(const Duration(milliseconds: 600)),
    ]);

    if (!mounted) return;
    setState(() => _isChecking = false);

    if (results.first as bool) {
      _goOnline();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context, 'still_offline')),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: isDark
                ? const [Color(0xFF0A1628), Color(0xFF102A47)]
                : const [Color(0xFFF0F4F8), Color(0xFFD9E6F5)],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: EdgeInsets.symmetric(horizontal: 32.w),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 140.w,
                    height: 140.w,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: scheme.error.withOpacity(isDark ? 0.12 : 0.08),
                      border: Border.all(
                        color: scheme.error.withOpacity(0.25),
                        width: 1.5,
                      ),
                    ),
                    child: Icon(
                      Icons.wifi_off_rounded,
                      size: 64.w,
                      color: scheme.error,
                    ),
                  ),
                  SizedBox(height: 32.h),
                  Text(
                    AppLocalizations.of(context, 'no_internet_title'),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 22.sp,
                      fontWeight: FontWeight.bold,
                      color: scheme.onSurface,
                    ),
                  ),
                  SizedBox(height: 12.h),
                  Text(
                    AppLocalizations.of(context, 'no_internet_body'),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14.sp,
                      height: 1.6,
                      color: scheme.onSurface.withOpacity(0.6),
                    ),
                  ),
                  SizedBox(height: 40.h),
                  SizedBox(
                    width: double.infinity,
                    height: 52.h,
                    child: ElevatedButton.icon(
                      onPressed: _isChecking ? null : _retry,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: scheme.primary,
                        foregroundColor: scheme.onPrimary,
                        disabledBackgroundColor: scheme.primary.withOpacity(0.5),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16.r),
                        ),
                      ),
                      icon: _isChecking
                          ? SizedBox(
                              width: 18.w,
                              height: 18.w,
                              child: const CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation(Colors.white),
                              ),
                            )
                          : const Icon(Icons.refresh_rounded),
                      label: Text(
                        AppLocalizations.of(context, 'retry'),
                        style: TextStyle(
                          fontSize: 16.sp,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  SizedBox(height: 16.h),
                  Text(
                    AppLocalizations.of(context, 'auto_reconnect_hint'),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 12.sp,
                      color: scheme.onSurface.withOpacity(0.4),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
