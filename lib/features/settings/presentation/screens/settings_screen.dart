import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:be_human_app/core/languages/app_localizations.dart';
import 'package:be_human_app/core/theme/app_colors.dart';
import 'package:be_human_app/core/widgets/glass.dart';
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
      backgroundColor: Colors.transparent,
      appBar: GlassAppBar(
        title: AppLocalizations.of(context, 'settings_title'),
        actions: const [NotificationBell()],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg, AppSpacing.md, AppSpacing.lg, 120,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            GlassCard(
              blurred: true,
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Row(
                children: [
                  if (user != null) ...[
                    AvatarPicker(user: user, radius: 34),
                    const SizedBox(width: AppSpacing.lg),
                  ],
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          user?.name ?? AppLocalizations.of(context, 'user_default'),
                          style: theme.textTheme.titleLarge,
                        ),
                        const SizedBox(height: 2),
                        Text(user?.email ?? '', style: theme.textTheme.bodySmall),
                        const SizedBox(height: AppSpacing.sm),
                        Wrap(
                          spacing: AppSpacing.sm,
                          runSpacing: AppSpacing.xs,
                          children: [
                            if (user != null) _Tag(label: user.team.label(context)),
                            if (user != null)
                              _Tag(label: user.role.label(context), accent: true),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.lg),

            // Preferences grouped into one panel instead of loose rows
            // floating on the background.
            _SectionLabel(text: AppLocalizations.of(context, 'preferences')),
            GlassCard(
              blurred: true,
              padding: EdgeInsets.zero,
              child: Column(
                children: [
                  _SettingRow(
                    icon: Icons.dark_mode_outlined,
                    label: AppLocalizations.of(context, 'theme_mode'),
                    trailing: Switch(
                      value: isDark,
                      onChanged: (v) => ref.read(themeProvider.notifier).setTheme(v),
                    ),
                  ),
                  const Divider(height: 1, indent: 56),
                  _SettingRow(
                    icon: Icons.translate,
                    label: AppLocalizations.of(context, 'language'),
                    trailing: DropdownButtonHideUnderline(
                      child: DropdownButton<Locale>(
                        value: ref.watch(localeProvider),
                        borderRadius: BorderRadius.circular(AppRadius.button),
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
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.lg),

            _SectionLabel(text: AppLocalizations.of(context, 'account')),
            ElevatedButton.icon(
              onPressed: () => _showChangePasswordDialog(context, ref),
              icon: const Icon(Icons.lock_outline, size: 20),
              label: Text(AppLocalizations.of(context, 'change_password')),
            ),
            const SizedBox(height: AppSpacing.md),
            // Signing out ends the session; it used to be styled identically
            // to "change password", which made the two indistinguishable.
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: theme.colorScheme.error,
                side: BorderSide(color: theme.colorScheme.error.withOpacity(0.5)),
              ),
              icon: const Icon(Icons.logout, size: 20),
              label: Text(AppLocalizations.of(context, 'logout')),
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

/// A small heading above a group of settings.
class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(
        left: AppSpacing.xs,
        right: AppSpacing.xs,
        bottom: AppSpacing.sm,
      ),
      child: Text(text, style: Theme.of(context).textTheme.labelSmall),
    );
  }
}

/// One row inside a settings panel: icon, label, control.
class _SettingRow extends StatelessWidget {
  const _SettingRow({
    required this.icon,
    required this.label,
    required this.trailing,
  });

  final IconData icon;
  final String label;
  final Widget trailing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.sm,
      ),
      child: Row(
        children: [
          Icon(icon, size: 20, color: theme.colorScheme.onSurface.withOpacity(0.6)),
          const SizedBox(width: AppSpacing.md),
          Expanded(child: Text(label, style: theme.textTheme.bodyLarge)),
          trailing,
        ],
      ),
    );
  }
}

/// The team and role badges on the profile card.
class _Tag extends StatelessWidget {
  const _Tag({required this.label, this.accent = false});

  final String label;
  final bool accent;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = accent
        ? AppColors.brand
        : theme.colorScheme.onSurface.withOpacity(0.55);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(AppRadius.pill),
        border: Border.all(color: color.withOpacity(0.35)),
      ),
      child: Text(
        label,
        style: theme.textTheme.labelSmall?.copyWith(color: color),
      ),
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
