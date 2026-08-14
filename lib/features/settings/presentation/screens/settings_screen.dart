import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:be_human_app/core/languages/app_localizations.dart';
import 'package:be_human_app/features/auth/domain/entities/app_user.dart';
import 'package:be_human_app/features/auth/presentation/providers/auth_provider.dart';
import 'package:be_human_app/core/providers/theme_provider.dart';
import 'package:be_human_app/core/services/push_service.dart';
import 'package:be_human_app/features/auth/presentation/widgets/avatar_picker.dart';
import 'package:be_human_app/features/notifications/presentation/widgets/notification_bell.dart';
import 'package:firebase_auth/firebase_auth.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserStreamProvider).value;
    final isDark = ref.watch(themeProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(AppLocalizations.of(context, 'settings_title')),
        actions: const [NotificationBell()],
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(16.w),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Card(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24.r)),
              child: Padding(
                padding: EdgeInsets.all(16.w),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    if (user != null) ...[
                      AvatarPicker(user: user, radius: 36.r),
                      SizedBox(width: 16.w),
                    ],
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(user?.name ?? AppLocalizations.of(context, 'user_default'), style: theme.textTheme.titleLarge),
                          SizedBox(height: 6.h),
                          Text(user?.email ?? '', style: theme.textTheme.bodyMedium),
                          SizedBox(height: 6.h),
                          Text('${AppLocalizations.of(context, 'team_label')}: ${user == null ? '' : user.team.label(context)}', style: theme.textTheme.bodyMedium),
                          SizedBox(height: 6.h),
                          Text('${AppLocalizations.of(context, 'role_label')}: ${user == null ? '' : user.role.label(context)}', style: theme.textTheme.bodyMedium),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            SizedBox(height: 12.h),
            ElevatedButton(
              onPressed: () => _showChangePasswordDialog(context, ref),
              child: Text(AppLocalizations.of(context, 'change_password')),
            ),
            SizedBox(height: 8.h),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(AppLocalizations.of(context, 'theme_mode'), style: theme.textTheme.bodyLarge),
                Switch(
                  value: isDark,
                  onChanged: (v) => ref.read(themeProvider.notifier).setTheme(v),
                ),
              ],
            ),
            SizedBox(height: 8.h),
            Row(
              children: [
                Expanded(child: Text(AppLocalizations.of(context, 'language'), style: theme.textTheme.bodyLarge)),
                DropdownButton<Locale>(
                  value: ref.watch(localeProvider),
                  items: [
                    DropdownMenuItem(value: const Locale('en'), child: Text(AppLocalizations.of(context, 'english'))),
                    DropdownMenuItem(value: const Locale('ar'), child: Text(AppLocalizations.of(context, 'arabic'))),
                    DropdownMenuItem(value: const Locale('nl'), child: Text(AppLocalizations.of(context, 'dutch'))),
                  ],
                  onChanged: (locale) {
                    if (locale == null) return;
                    ref.read(localeProvider.notifier).setLocale(locale);

                    // Recorded on the profile too, so a push notification
                    // composed on the server arrives in this language.
                    if (user != null) {
                      ref
                          .read(profileServiceProvider)
                          .updateLocale(user.uid, locale.languageCode);
                    }
                  },
                ),
              ],
            ),
            SizedBox(height: 8.h),
            ElevatedButton(
              onPressed: () async {
                final messenger = ScaffoldMessenger.of(context);
                final router = GoRouter.of(context);
                try {
                  // Before signing out, while the rules still allow writing
                  // to this profile: otherwise the phone keeps receiving the
                  // previous user's notifications.
                  if (user != null) {
                    try {
                      await ref.read(pushServiceProvider).unregister(user.uid);
                    } catch (_) {
                      // Never block signing out over this.
                    }
                  }
                  await ref.read(authServiceProvider).signOut();
                  // The router listens to the auth stream, but navigating
                  // explicitly avoids leaving a stale route on screen.
                  router.go('/login');
                } catch (e) {
                  messenger.showSnackBar(
                    SnackBar(
                      content: Text(AppLocalizations.of(
                        context, 'logout_error', {'error': e.toString()},
                      )),
                    ),
                  );
                }
              },
              child: Text(AppLocalizations.of(context, 'logout')),
            ),
          ],
        ),
      ),
    );
  }

  void _showChangePasswordDialog(BuildContext context, WidgetRef ref) {
    showDialog<void>(
      context: context,
      builder: (ctx) => _ChangePasswordDialog(ref: ref),
    );
  }
}

class _ChangePasswordDialog extends StatefulWidget {
  const _ChangePasswordDialog({required this.ref});

  final WidgetRef ref;

  @override
  State<_ChangePasswordDialog> createState() => _ChangePasswordDialogState();
}

class _ChangePasswordDialogState extends State<_ChangePasswordDialog> {
  final _oldCtrl = TextEditingController();
  final _newCtrl = TextEditingController();
  bool _isSaving = false;

  @override
  void dispose() {
    _oldCtrl.dispose();
    _newCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    final updatedMessage = AppLocalizations.of(context, 'password_updated');
    final invalidMessage = AppLocalizations.of(context, 'password_invalid');

    setState(() => _isSaving = true);
    try {
      await widget.ref.read(authServiceProvider).changePassword(
            currentPassword: _oldCtrl.text,
            newPassword: _newCtrl.text,
          );
      messenger.showSnackBar(SnackBar(content: Text(updatedMessage)));
      navigator.pop();
    } on FirebaseAuthException catch (e) {
      // A wrong current password surfaces as a failed re-authentication.
      final message = switch (e.code) {
        'wrong-password' || 'invalid-credential' => invalidMessage,
        'weak-password' => AppLocalizations.of(context, 'weak_password'),
        _ => e.message ?? invalidMessage,
      };
      if (mounted) {
        setState(() => _isSaving = false);
      }
      messenger.showSnackBar(SnackBar(content: Text(message)));
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(AppLocalizations.of(context, 'change_password')),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _oldCtrl,
            decoration: InputDecoration(labelText: AppLocalizations.of(context, 'old_password')),
            obscureText: true,
          ),
          TextField(
            controller: _newCtrl,
            decoration: InputDecoration(labelText: AppLocalizations.of(context, 'new_password')),
            obscureText: true,
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: _isSaving ? null : () => Navigator.of(context).pop(),
          child: Text(AppLocalizations.of(context, 'cancel')),
        ),
        ElevatedButton(
          onPressed: _isSaving ? null : _submit,
          child: _isSaving
              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
              : Text(AppLocalizations.of(context, 'save')),
        ),
      ],
    );
  }
}
