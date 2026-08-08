import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:be_human_app/core/languages/app_localizations.dart';
import 'package:be_human_app/features/auth/presentation/providers/auth_provider.dart';
import 'package:be_human_app/core/utils/app_mock_data.dart';
import 'package:be_human_app/core/providers/theme_provider.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserStreamProvider).value;
    final isDark = ref.watch(themeProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(AppLocalizations.of(context, 'settings_title'))),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(16.w),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Card(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24.r)),
              child: Padding(
                padding: EdgeInsets.all(16.w),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(user?.name ?? AppLocalizations.of(context, 'user_default'), style: theme.textTheme.titleLarge),
                    SizedBox(height: 6.h),
                    Text(user?.email ?? '', style: theme.textTheme.bodyMedium),
                    SizedBox(height: 6.h),
                    Text('${AppLocalizations.of(context, 'team_label')}: ${user?.team.name ?? ''}', style: theme.textTheme.bodyMedium),
                    SizedBox(height: 6.h),
                    Text('${AppLocalizations.of(context, 'role_label')}: ${user?.role.name ?? ''}', style: theme.textTheme.bodyMedium),
                  ],
                ),
              ),
            ),
            SizedBox(height: 12.h),
            ElevatedButton(
              onPressed: () => _showChangePasswordDialog(context),
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
                    if (locale != null) {
                      ref.read(localeProvider.notifier).setLocale(locale);
                    }
                  },
                ),
              ],
            ),
            SizedBox(height: 8.h),
            ElevatedButton(
              onPressed: () async {
                try {
                  final auth = ref.read(authServiceProvider);
                  await auth.signOut();
                  // The stream provider will automatically update to null
                  context.go('/login');
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('خطأ في تسجيل الخروج: ${e.toString()}')),
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

  void _showChangePasswordDialog(BuildContext context) {
    final oldCtrl = TextEditingController();
    final newCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('تغيير كلمة المرور'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: oldCtrl, decoration: InputDecoration(labelText: AppLocalizations.of(context, 'old_password')), obscureText: true),
            TextField(controller: newCtrl, decoration: InputDecoration(labelText: AppLocalizations.of(context, 'new_password')), obscureText: true),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: Text(AppLocalizations.of(context, 'cancel'))),
          ElevatedButton(
            onPressed: () {
              final email = ProviderScope.containerOf(context).read(currentUserStreamProvider).value?.email;
              if (email == null) {
                Navigator.of(ctx).pop();
                return;
              }

              final old = oldCtrl.text;
              final nw = newCtrl.text;
              final stored = AppMockData.mockPasswords[email];
              if (stored != null && stored == old) {
                AppMockData.mockPasswords[email] = nw;
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(AppLocalizations.of(context, 'password_updated'))));
                Navigator.of(ctx).pop();
              } else {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(AppLocalizations.of(context, 'password_invalid'))));
              }
            },
            child: const Text('حفظ'),
          ),
        ],
      ),
    );
  }
}
