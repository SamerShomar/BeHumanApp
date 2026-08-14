import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:be_human_app/core/languages/app_localizations.dart';
import 'package:be_human_app/features/proposals/domain/proposal_status.dart';
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
          child: Text(
            AppLocalizations.of(context, 'no_permission'),
            style: Theme.of(context).textTheme.titleLarge,
          ),
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
                final contentUpdated = AppLocalizations.of(context, 'content_updated');
                final contentUpdateFailed = AppLocalizations.of(context, 'content_update_failed');
                try {
                  final data = await scraper.fetch();
                  ref.read(aboutProvider.notifier).setAll(data);
                  snack.showSnackBar(SnackBar(content: Text(contentUpdated)));
                } catch (e) {
                  snack.showSnackBar(SnackBar(content: Text(contentUpdateFailed)));
                }
              },
              child: Text(AppLocalizations.of(context, 'pull_website_action')),
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
                  child: Text(AppLocalizations.of(context, 'add_proposal_new')),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ...proposals.value?.map((p) => ListTile(
                  title: Text(p['title'] ?? ''),
                  subtitle: Text('${ProposalStatus.label(context, p['status'])} • ${p['date'] ?? ''}'),
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
                  child: Text(AppLocalizations.of(context, 'add_movement')),
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
                    Text('${AppLocalizations.of(context, 'revenues')}: ${finances['totalIncome'] ?? 0}'),
                    Text('${AppLocalizations.of(context, 'expenses')}: ${finances['totalExpense'] ?? 0}'),
                    Text('${AppLocalizations.of(context, 'balance')}: ${finances['balance'] ?? 0}'),
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
        title: Text(AppLocalizations.of(context, 'add_proposal_new')),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: titleCtrl, decoration: InputDecoration(labelText: AppLocalizations.of(context, 'title_label'))),
            TextField(controller: descCtrl, decoration: InputDecoration(labelText: AppLocalizations.of(context, 'description_label'))),
            TextField(controller: amountCtrl, decoration: InputDecoration(labelText: AppLocalizations.of(context, 'amount_label')), keyboardType: TextInputType.number),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: Text(AppLocalizations.of(context, 'cancel'))),
          ElevatedButton(
            onPressed: () async {
              final id = 'p${DateTime.now().millisecondsSinceEpoch}';
              final amount = double.tryParse(amountCtrl.text) ?? 0.0;
              final proposal = {
                'id': id,
                'title': titleCtrl.text,
                'status': ProposalStatus.pending,
                'date': DateTime.now().toIso8601String(),
                'amount': amount,
                'description': descCtrl.text,
              };

              try {
                final adminService = ref.read(firestoreAdminServiceProvider);
                await adminService.addProposal(proposal);
                Navigator.of(ctx).pop();
                ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content: Text(AppLocalizations.of(context, 'proposal_added'))));
              } catch (e) {
                ScaffoldMessenger.of(ctx).showSnackBar(
                  SnackBar(content: Text(AppLocalizations.of(
                    context, 'proposal_add_failed', {'error': e.toString()},
                  ))),
                );
              }
            },
            child: Text(AppLocalizations.of(context, 'save')),
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
        title: Text(AppLocalizations.of(context, 'add_financial')),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DropdownButtonFormField<String>(
              initialValue: type,
              items: [
                DropdownMenuItem(value: 'income', child: Text(AppLocalizations.of(context, 'income_label'))),
                DropdownMenuItem(value: 'expense', child: Text(AppLocalizations.of(context, 'expense_label'))),
              ],
              onChanged: (v) => type = v ?? 'income',
              decoration: InputDecoration(labelText: AppLocalizations.of(context, 'type_label')),
            ),
            TextField(controller: amountCtrl, decoration: InputDecoration(labelText: AppLocalizations.of(context, 'amount_label')), keyboardType: TextInputType.number),
            TextField(controller: descCtrl, decoration: InputDecoration(labelText: AppLocalizations.of(context, 'description_label'))),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: Text(AppLocalizations.of(context, 'cancel'))),
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
                ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content: Text(AppLocalizations.of(context, 'transaction_added'))));
              } catch (e) {
                ScaffoldMessenger.of(ctx).showSnackBar(
                  SnackBar(content: Text(AppLocalizations.of(
                    context, 'transaction_add_failed', {'error': e.toString()},
                  ))),
                );
              }
            },
            child: Text(AppLocalizations.of(context, 'save')),
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
        subtitle: Text('${member.email} • ${member.team.label(context)}'),
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
              DropdownMenuItem(value: role, child: Text(role.label(context))),
          ],
        ),
      ),
    );
  }
}
