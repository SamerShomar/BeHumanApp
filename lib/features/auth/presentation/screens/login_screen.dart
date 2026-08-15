import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:be_human_app/core/utils/connectivity.dart';

import 'package:be_human_app/core/languages/app_localizations.dart';
import 'package:be_human_app/core/theme/app_colors.dart';
import 'package:be_human_app/core/widgets/glass.dart';
import 'package:be_human_app/features/auth/presentation/providers/auth_provider.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  bool isLoading = false;
  String? errorMessage;


  Future<void> _handleLogin() async {
    final messenger = ScaffoldMessenger.of(context);
    final router = GoRouter.of(context);

    final email = _emailController.text.trim().toLowerCase();
    final password = _passwordController.text.trim();

    if (email.isEmpty || password.isEmpty) {
      messenger.showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context, 'email_password_required'))),
      );
      return;
    }

    setState(() {
      isLoading = true;
      errorMessage = null;
    });

    try {
      // Check internet connection first
      final hasInternet = await hasNetworkConnection();
      if (!hasInternet) {
        if (!mounted) return;
        setState(() {
          isLoading = false;
          errorMessage = AppLocalizations.of(context, 'no_internet_title');
        });
        return;
      }

      final auth = ref.read(authServiceProvider);
      await auth.signIn(email, password);
      // The user will be automatically loaded through the stream provider
      router.go('/home');
    } on FirebaseAuthException catch (e) {
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }

      // Firebase returns `invalid-credential` instead of `wrong-password` when
      // email-enumeration protection is enabled, so both map to one message.
      final message = switch (e.code) {
        'user-not-found' => AppLocalizations.of(context, 'email_not_registered'),
        'wrong-password' || 'invalid-credential' =>
          AppLocalizations.of(context, 'credentials_invalid'),
        'too-many-requests' => AppLocalizations.of(context, 'too_many_requests'),
        _ => AppLocalizations.of(context, 'login_error', {'error': e.message ?? ''}),
      };
      messenger.showSnackBar(SnackBar(content: Text(message)));
    } catch (e) {
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
      messenger.showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context, 'login_failed_retry'))),
      );
    }
  }

  Future<void> _handleForgotPassword() async {
    final messenger = ScaffoldMessenger.of(context);
    final email = _emailController.text.trim().toLowerCase();

    if (email.isEmpty) {
      messenger.showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context, 'reset_needs_email'))),
      );
      return;
    }

    final sentMessage = AppLocalizations.of(context, 'reset_sent');

    try {
      await ref.read(authServiceProvider).sendPasswordReset(email);
      // Firebase reports success even for unknown addresses, so the wording
      // must not confirm whether the account exists.
      messenger.showSnackBar(SnackBar(content: Text(sentMessage)));
    } on FirebaseAuthException catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text(e.message ?? AppLocalizations.of(context, 'reset_failed'))),
      );
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: AppBackground(
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(AppSpacing.xl),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 460),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // The mark sits above the panel rather than inside it, so
                    // the foundation is the first thing on the screen.
                    Container(
                      padding: const EdgeInsets.all(AppSpacing.lg),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white.withOpacity(0.75),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.brand.withOpacity(0.28),
                            blurRadius: 40,
                            offset: const Offset(0, 12),
                          ),
                        ],
                      ),
                      child: Image.asset(
                        'assets/images/logo.png',
                        width: 96,
                        height: 96,
                        fit: BoxFit.contain,
                        errorBuilder: (_, __, ___) => const SizedBox(width: 96, height: 96),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    Text(
                      AppLocalizations.of(context, 'app_title'),
                      textAlign: TextAlign.center,
                      style: theme.textTheme.headlineMedium,
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      AppLocalizations.of(context, 'login_subtitle'),
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyMedium,
                    ),
                    const SizedBox(height: AppSpacing.xl),
                    GlassCard(
                      // One frosted panel on the screen, and nothing repeating
                      // behind it — this is where the effect is worth its cost.
                      blurred: true,
                      padding: const EdgeInsets.all(AppSpacing.xl),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _GlassTextField(
                            controller: _emailController,
                            hintText: AppLocalizations.of(context, 'email_hint'),
                            icon: Icons.alternate_email,
                            keyboardType: TextInputType.emailAddress,
                          ),
                          const SizedBox(height: AppSpacing.md),
                          _GlassTextField(
                            controller: _passwordController,
                            hintText: AppLocalizations.of(context, 'password_hint'),
                            icon: Icons.lock_outline,
                            obscureText: true,
                          ),
                          if (errorMessage != null)
                            Padding(
                              padding: const EdgeInsets.only(top: AppSpacing.md),
                              child: Row(
                                children: [
                                  const Icon(Icons.error_outline,
                                      size: 16, color: AppColors.danger),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: Text(
                                      errorMessage!,
                                      style: theme.textTheme.bodySmall
                                          ?.copyWith(color: AppColors.danger),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          const SizedBox(height: AppSpacing.xl),
                          ElevatedButton(
                            onPressed: isLoading ? null : _handleLogin,
                            child: isLoading
                                ? const SizedBox(
                                    width: 22,
                                    height: 22,
                                    child: CircularProgressIndicator(
                                      color: Colors.white,
                                      strokeWidth: 2.4,
                                    ),
                                  )
                                : Text(AppLocalizations.of(context, 'login_button')),
                          ),
                          const SizedBox(height: AppSpacing.xs),
                          TextButton(
                            onPressed: isLoading ? null : _handleForgotPassword,
                            child: Text(AppLocalizations.of(context, 'forgot_password')),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _GlassTextField extends StatelessWidget {
  const _GlassTextField({
    required this.controller,
    required this.hintText,
    required this.icon,
    this.obscureText = false,
    this.keyboardType,
  });

  final TextEditingController controller;
  final String hintText;
  final IconData icon;
  final bool obscureText;
  final TextInputType? keyboardType;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      obscureText: obscureText,
      keyboardType: keyboardType,
      // Shape, fill and focus ring all come from inputDecorationTheme now, so
      // this field looks the same as every other one in the app.
      decoration: InputDecoration(
        hintText: hintText,
        prefixIcon: Icon(icon, size: 20),
      ),
    );
  }
}
