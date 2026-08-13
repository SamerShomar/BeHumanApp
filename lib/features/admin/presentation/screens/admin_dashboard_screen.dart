import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:be_human_app/core/languages/app_localizations.dart';
import 'package:be_human_app/features/auth/presentation/providers/auth_provider.dart';
import 'package:be_human_app/features/admin/presentation/providers/admin_providers.dart';
import 'package:be_human_app/features/about/data/website_scraper.dart';
import 'package:be_human_app/features/auth/domain/entities/app_user.dart';
import 'package:be_human_app/features/admin/presentation/providers/about_provider.dart';

class AdminDashboardScreen extends ConsumerWidget {
  const AdminDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserStreamProvider).value;

    if (user == null || !user.isAdmin) {
      return Scaffold(
        body: Center(
          child: Text('ليس لديك صلاحية', style: Theme.of(context).textTheme.titleLarge),
        ),
      );
    }

    final proposals = ref.watch(proposalsProvider);
    final finances = ref.watch(financesProvider);
    final about = ref.watch(aboutProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(AppLocalizations.of(context, 'admin_dashboard')),
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0),
            child: ElevatedButton(
              onPressed: () async {
                final scraper = ref.read(websiteScraperProvider);
                final snack = ScaffoldMessenger.of(context);
                try {
                  final data = await scraper.fetch();
                  ref.read(aboutProvider.notifier).setAll(data);
                  snack.showSnackBar(const SnackBar(content: Text('تم تحديث المحتوى من الموقع')));
                } catch (e) {
                  snack.showSnackBar(const SnackBar(content: Text('فشل سحب المحتوى، تم استخدام نصوص بديلة')));
                }
              },
              child: const Text('سحب محتوى الموقع'),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // About preview
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(AppLocalizations.of(context, 'about_org'), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    Text('Mission: ${about['mission'] ?? ''}'),
                    const SizedBox(height: 6),
                    Text('Vision: ${about['vision'] ?? ''}'),
                    const SizedBox(height: 6),
                    Text('Description: ${about['description'] ?? ''}'),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),

            // Proposals
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(AppLocalizations.of(context, 'proposals'), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                ElevatedButton(
                  onPressed: () => _showAddProposalDialog(context, ref),
                  child: const Text('إضافة مقترح جديد'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ...proposals.value?.map((p) => ListTile(
                  title: Text(p['title'] ?? ''),
                  subtitle: Text('${p['status'] ?? ''} • ${p['date'] ?? ''}'),
                  trailing: Text('${p['amount'] ?? ''}'),
                )) ?? [],

            const SizedBox(height: 16),

            // Finances
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(AppLocalizations.of(context, 'financial'), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                ElevatedButton(
                  onPressed: () => _showAddTransactionDialog(context, ref),
                  child: const Text('إضافة حركة وارد/صادر'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('الإيرادات: ${finances['totalIncome'] ?? 0}'),
                    Text('المصروفات: ${finances['totalExpense'] ?? 0}'),
                    Text('الرصيد: ${finances['balance'] ?? 0}'),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Users
            Text(
              AppLocalizations.of(context, 'members'),
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            ref.watch(usersProvider).when(
                  loading: () => const Center(child: CircularProgressIndicator()),
                  error: (error, _) => Text('${AppLocalizations.of(context, 'error_generic')}: $error'),
                  data: (users) => Column(
                    children: [
                      for (final member in users)
                        _MemberTile(member: member, currentUserUid: user.uid),
                    ],
                  ),
                ),
          ],
        ),
      ),
    );
  }

  void _showAddProposalDialog(BuildContext context, WidgetRef ref) {
    final titleCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    final amountCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('إضافة مقترح جديد'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: titleCtrl, decoration: const InputDecoration(labelText: 'العنوان')),
            TextField(controller: descCtrl, decoration: const InputDecoration(labelText: 'الوصف')),
            TextField(controller: amountCtrl, decoration: const InputDecoration(labelText: 'المبلغ'), keyboardType: TextInputType.number),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('إلغاء')),
          ElevatedButton(
            onPressed: () async {
              final id = 'p${DateTime.now().millisecondsSinceEpoch}';
              final amount = double.tryParse(amountCtrl.text) ?? 0.0;
              final proposal = {
                'id': id,
                'title': titleCtrl.text,
                'status': 'معلق',
                'date': DateTime.now().toIso8601String(),
                'amount': amount,
                'description': descCtrl.text,
              };

              try {
                final adminService = ref.read(firestoreAdminServiceProvider);
                await adminService.addProposal(proposal);
                Navigator.of(ctx).pop();
                ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(content: Text('تم إضافة المقترح بنجاح')));
              } catch (e) {
                ScaffoldMessenger.of(ctx).showSnackBar(
                  SnackBar(content: Text('فشل إضافة المقترح: ${e.toString()}')),
                );
              }
            },
            child: const Text('حفظ'),
          ),
        ],
      ),
    );
  }

  void _showAddTransactionDialog(BuildContext context, WidgetRef ref) {
    final amountCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    var type = 'income';

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('إضافة حركة مالية'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DropdownButtonFormField<String>(
              initialValue: type,
              items: const [
                DropdownMenuItem(value: 'income', child: Text('وارد')),
                DropdownMenuItem(value: 'expense', child: Text('صادر')),
              ],
              onChanged: (v) => type = v ?? 'income',
              decoration: const InputDecoration(labelText: 'النوع'),
            ),
            TextField(controller: amountCtrl, decoration: const InputDecoration(labelText: 'المبلغ'), keyboardType: TextInputType.number),
            TextField(controller: descCtrl, decoration: const InputDecoration(labelText: 'الوصف')),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('إلغاء')),
          ElevatedButton(
            onPressed: () async {
              final amount = double.tryParse(amountCtrl.text) ?? 0.0;
              final id = 't${DateTime.now().millisecondsSinceEpoch}';
              final transaction = {
                'id': id,
                'type': type,
                'amount': amount,
                'description': descCtrl.text,
                'date': DateTime.now().toIso8601String(),
              };

              try {
                final adminService = ref.read(firestoreAdminServiceProvider);
                await adminService.addTransaction(transaction);
                Navigator.of(ctx).pop();
                ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(content: Text('تم إضافة الحركة المالية بنجاح')));
              } catch (e) {
                ScaffoldMessenger.of(ctx).showSnackBar(
                  SnackBar(content: Text('فشل إضافة الحركة المالية: ${e.toString()}')),
                );
              }
            },
            child: const Text('حفظ'),
          ),
        ],
      ),
    );
  }
}

/// A member row with an inline role selector.
///
/// Firestore rules also enforce that only an admin may change a role, so this
/// UI is a convenience rather than the security boundary.
class _MemberTile extends ConsumerWidget {
  const _MemberTile({required this.member, required this.currentUserUid});

  final AppUser member;
  final String currentUserUid;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Guard against an admin removing their own admin rights and locking
    // everyone out of the dashboard.
    final isSelf = member.uid == currentUserUid;

    return Card(
      child: ListTile(
        title: Text(member.name),
        subtitle: Text('${member.email} • ${member.team.name}'),
        trailing: DropdownButton<UserRole>(
          value: member.role,
          onChanged: isSelf
              ? null
              : (role) async {
                  if (role == null) return;
                  final messenger = ScaffoldMessenger.of(context);
                  final updated = AppLocalizations.of(context, 'role_updated');
                  try {
                    await ref
                        .read(firestoreAdminServiceProvider)
                        .updateUserRole(member.uid, role);
                    messenger.showSnackBar(SnackBar(content: Text(updated)));
                  } catch (e) {
                    messenger.showSnackBar(
                      SnackBar(content: Text('${AppLocalizations.of(context, 'error_generic')}: $e')),
                    );
                  }
                },
          items: [
            for (final role in UserRole.values)
              DropdownMenuItem(value: role, child: Text(role.name)),
          ],
        ),
      ),
    );
  }
}
