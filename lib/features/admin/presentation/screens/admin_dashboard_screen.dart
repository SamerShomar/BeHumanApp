import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:be_human_app/core/languages/app_localizations.dart';
import 'package:be_human_app/core/theme/app_colors.dart';
import 'package:be_human_app/core/utils/formatters.dart';
import 'package:be_human_app/core/widgets/glass.dart';
import 'package:be_human_app/core/widgets/stat_card.dart';
import 'package:be_human_app/core/widgets/state_views.dart';
import 'package:be_human_app/features/proposals/domain/proposal_status.dart';
import 'package:be_human_app/core/widgets/status_chip.dart';
import 'package:be_human_app/features/auth/presentation/providers/auth_provider.dart';
import 'package:be_human_app/features/admin/presentation/providers/admin_providers.dart';
import 'package:be_human_app/features/about/data/website_scraper.dart';
import 'package:be_human_app/features/auth/domain/entities/app_user.dart';
import 'package:be_human_app/features/admin/presentation/providers/about_provider.dart';
import 'package:be_human_app/features/projects/domain/project.dart';
import 'package:be_human_app/features/projects/presentation/providers/project_providers.dart';
import 'package:be_human_app/features/notifications/presentation/providers/notification_providers.dart';
import 'package:be_human_app/features/notifications/presentation/widgets/notification_bell.dart';

class AdminDashboardScreen extends ConsumerWidget {
  const AdminDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserStreamProvider).value;

    if (user == null || !user.isAdmin) {
      return Scaffold(
        backgroundColor: Colors.transparent,
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
      backgroundColor: Colors.transparent,
      appBar: GlassAppBar(
        title: AppLocalizations.of(context, 'admin_dashboard'),
        actions: [
          // An ElevatedButton sat here before; with a real button theme it is
          // 52px tall and does not belong in a toolbar.
          IconButton(
            tooltip: AppLocalizations.of(context, 'import_from_website'),
            icon: const Icon(Icons.cloud_download_outlined),
            onPressed: () => _importFromWebsite(context, ref),
          ),
          const NotificationBell(),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg, AppSpacing.md, AppSpacing.lg, 120,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            StatCardRow(
              cards: [
                StatCard(
                  label: AppLocalizations.of(context, 'balance'),
                  amount: finances['balance'],
                  color: AppColors.brand,
                  icon: Icons.account_balance_wallet_outlined,
                ),
                StatCard(
                  label: AppLocalizations.of(context, 'revenues'),
                  amount: finances['totalIncome'],
                  color: AppColors.success,
                  icon: Icons.south_west,
                ),
                StatCard(
                  label: AppLocalizations.of(context, 'expenses'),
                  amount: finances['totalExpense'],
                  color: AppColors.danger,
                  icon: Icons.north_east,
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.xl),

            _SectionHeader(
              title: AppLocalizations.of(context, 'proposals'),
              actionLabel: AppLocalizations.of(context, 'add_proposal_new'),
              onAction: () => _showAddProposalDialog(context, ref, user),
            ),
            for (final p in proposals.value ?? const <Map<String, dynamic>>[])
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                child: GlassCard(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              p['title'] as String? ?? '',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.titleSmall,
                            ),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                StatusChip(status: p['status'], compact: true),
                                const SizedBox(width: AppSpacing.sm),
                                Flexible(
                                  child: Text(
                                    Formatters.date(p['date']),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: Theme.of(context).textTheme.bodySmall,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Text(
                        Formatters.amount(p['amount']),
                        style: Theme.of(context)
                            .textTheme
                            .titleSmall
                            ?.copyWith(color: AppColors.brand),
                      ),
                    ],
                  ),
                ),
              ),

            const SizedBox(height: AppSpacing.lg),
            _SectionHeader(
              title: AppLocalizations.of(context, 'financial'),
              actionLabel: AppLocalizations.of(context, 'add_movement'),
              onAction: () => _showAddTransactionDialog(context, ref, user),
            ),
            GlassCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(AppLocalizations.of(context, 'about_org'),
                      style: Theme.of(context).textTheme.titleSmall),
                  const SizedBox(height: AppSpacing.sm),
                  Text(about['mission'] ?? '',
                      style: Theme.of(context).textTheme.bodySmall),
                ],
              ),
            ),

            // Projects — what the home screen shows to everyone.
            const SizedBox(height: AppSpacing.lg),
            _SectionHeader(
              title: AppLocalizations.of(context, 'projects'),
              actionLabel: AppLocalizations.of(context, 'add_project'),
              onAction: () => _showProjectDialog(context, ref),
            ),
            ref.watch(projectsProvider).when(
                  loading: () => const LoadingStateView(),
                  error: (error, _) => ErrorStateView(error: error),
                  data: (projects) {
                    if (projects.isEmpty) {
                      return EmptyStateView(
                        icon: Icons.volunteer_activism_outlined,
                        message: AppLocalizations.of(context, 'no_projects'),
                        actionLabel: AppLocalizations.of(context, 'add_project'),
                        onAction: () => _showProjectDialog(context, ref),
                      );
                    }
                    return Column(
                      children: [
                        for (final project in projects)
                          Padding(
                            padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                            child: _ProjectRow(project: project),
                          ),
                      ],
                    );
                  },
                ),

            const SizedBox(height: AppSpacing.lg),
            _SectionHeader(title: AppLocalizations.of(context, 'members')),
            ref.watch(usersProvider).when(
                  loading: () => const LoadingStateView(),
                  error: (error, _) => ErrorStateView(error: error),
                  data: (users) => Column(
                    children: [
                      for (final member in users)
                        Padding(
                          padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                          child: _MemberTile(
                            member: member,
                            currentUserUid: user.uid,
                          ),
                        ),
                    ],
                  ),
                ),
          ],
        ),
      ),
    );
  }

  void _showAddProposalDialog(BuildContext context, WidgetRef ref, AppUser actor) {
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
                // The rules require a proposal to carry its author's uid.
                'submittedBy': actor.uid,
                'submittedByName': actor.name,
              };

              try {
                final adminService = ref.read(firestoreAdminServiceProvider);
                await adminService.addProposal(proposal);
                await ref.read(notificationServiceProvider).proposalSubmitted(
                      actor: actor,
                      proposalId: id,
                      title: titleCtrl.text,
                    );
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

  void _showAddTransactionDialog(BuildContext context, WidgetRef ref, AppUser actor) {
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
                await ref.read(notificationServiceProvider).transactionAdded(
                      actor: actor,
                      transactionId: id,
                      type: type,
                      amount: amount,
                    );
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

    return GlassCard(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(member.name, style: Theme.of(context).textTheme.titleSmall),
                Text(
                  '${member.email}  •  ${member.team.label(context)}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
          DropdownButtonHideUnderline(
            child: DropdownButton<UserRole>(
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
        ],
      ),
    );
  }
}

/// Pulls the website's own words and project list, and stores both in
/// Firestore so every user sees them — including offline, and including users
/// who were not the one to press this.
Future<void> _importFromWebsite(BuildContext context, WidgetRef ref) async {
  final messenger = ScaffoldMessenger.of(context);
  final scraper = ref.read(websiteScraperProvider);
  final service = ref.read(projectServiceProvider);

  final contentUpdated = AppLocalizations.of(context, 'content_updated');
  final contentFailed = AppLocalizations.of(context, 'content_update_failed');
  final importFailed = AppLocalizations.of(context, 'projects_import_failed');
  String imported(int count) => AppLocalizations.of(
        context, 'projects_imported', {'count': '$count'},
      );

  try {
    final about = await scraper.fetch();
    await service.saveSiteContent(about);
    ref.read(aboutProvider.notifier).setAll(about);
    messenger.showSnackBar(SnackBar(content: Text(contentUpdated)));
  } catch (_) {
    messenger.showSnackBar(SnackBar(content: Text(contentFailed)));
    return;
  }

  // Reported separately: the description can import cleanly while the project
  // list comes back empty, and the admin needs to know which happened.
  try {
    final projects = await scraper.fetchProjects();
    if (projects.isEmpty) {
      messenger.showSnackBar(SnackBar(content: Text(importFailed)));
      return;
    }
    final count = await service.replaceImported(projects);
    messenger.showSnackBar(SnackBar(content: Text(imported(count))));
  } catch (_) {
    messenger.showSnackBar(SnackBar(content: Text(importFailed)));
  }
}

void _showProjectDialog(BuildContext context, WidgetRef ref, {Project? existing}) {
  showDialog<void>(
    context: context,
    builder: (_) => _ProjectDialog(existing: existing),
  );
}

/// One project in the admin list, with edit and delete.
class _ProjectRow extends ConsumerWidget {
  const _ProjectRow({required this.project});

  final Project project;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);

    return GlassCard(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  project.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleSmall,
                ),
                Text(
                  [
                    if (project.beneficiaries != null)
                      AppLocalizations.of(context, 'beneficiaries_count',
                          {'count': '${project.beneficiaries}'}),
                    if (project.location != null) project.location!,
                  ].join('  •  '),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall,
                ),
              ],
            ),
          ),
          IconButton(
            visualDensity: VisualDensity.compact,
            tooltip: AppLocalizations.of(context, 'edit_project'),
            icon: const Icon(Icons.edit_outlined, size: 20),
            onPressed: () => _showProjectDialog(context, ref, existing: project),
          ),
          IconButton(
            visualDensity: VisualDensity.compact,
            tooltip: AppLocalizations.of(context, 'delete'),
            icon: Icon(Icons.delete_outline, size: 20, color: theme.colorScheme.error),
            onPressed: () => _confirmDelete(context, ref),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref) async {
    final messenger = ScaffoldMessenger.of(context);
    final deleted = AppLocalizations.of(context, 'project_deleted');
    final scheme = Theme.of(context).colorScheme;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (confirm) => AlertDialog(
        content: Text(AppLocalizations.of(context, 'delete_project_confirm')),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(confirm).pop(false),
            child: Text(AppLocalizations.of(context, 'cancel')),
          ),
          TextButton(
            onPressed: () => Navigator.of(confirm).pop(true),
            child: Text(
              AppLocalizations.of(context, 'delete'),
              style: TextStyle(color: scheme.error),
            ),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      await ref.read(projectServiceProvider).delete(project.id);
      messenger.showSnackBar(SnackBar(content: Text(deleted)));
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('$e')));
    }
  }
}

/// Adds or edits a project by hand — the path that always works, whatever the
/// website's markup happens to be.
class _ProjectDialog extends ConsumerStatefulWidget {
  const _ProjectDialog({this.existing});

  final Project? existing;

  @override
  ConsumerState<_ProjectDialog> createState() => _ProjectDialogState();
}

class _ProjectDialogState extends ConsumerState<_ProjectDialog> {
  late final _titleCtrl = TextEditingController(text: widget.existing?.title);
  late final _descCtrl = TextEditingController(text: widget.existing?.description);
  late final _beneficiariesCtrl = TextEditingController(
    text: widget.existing?.beneficiaries?.toString() ?? '',
  );
  late final _locationCtrl = TextEditingController(text: widget.existing?.location);
  bool _isSaving = false;

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descCtrl.dispose();
    _beneficiariesCtrl.dispose();
    _locationCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    final savedMessage = AppLocalizations.of(context, 'project_saved');

    final title = _titleCtrl.text.trim();
    if (title.isEmpty) return;

    setState(() => _isSaving = true);
    try {
      await ref.read(projectServiceProvider).save(Project(
            id: widget.existing?.id ?? 'j${DateTime.now().millisecondsSinceEpoch}',
            title: title,
            description: _descCtrl.text.trim(),
            // Editing keeps the original date so the order does not jump.
            date: widget.existing?.date ?? DateTime.now(),
            beneficiaries: int.tryParse(
              _beneficiariesCtrl.text.replaceAll(RegExp(r'[^0-9]'), ''),
            ),
            location: _locationCtrl.text.trim().isEmpty
                ? null
                : _locationCtrl.text.trim(),
            sourceUrl: widget.existing?.sourceUrl,
          ));
      navigator.pop();
      messenger.showSnackBar(SnackBar(content: Text(savedMessage)));
    } catch (e) {
      if (mounted) setState(() => _isSaving = false);
      messenger.showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(AppLocalizations.of(
        context, widget.existing == null ? 'add_project' : 'edit_project',
      )),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _titleCtrl,
              decoration: InputDecoration(
                labelText: AppLocalizations.of(context, 'title_label'),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            TextField(
              controller: _descCtrl,
              maxLines: 3,
              decoration: InputDecoration(
                labelText: AppLocalizations.of(context, 'description_label'),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            TextField(
              controller: _beneficiariesCtrl,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: AppLocalizations.of(context, 'beneficiaries_label'),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            TextField(
              controller: _locationCtrl,
              decoration: InputDecoration(
                labelText: AppLocalizations.of(context, 'location_label'),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isSaving ? null : () => Navigator.of(context).pop(),
          child: Text(AppLocalizations.of(context, 'cancel')),
        ),
        ElevatedButton(
          onPressed: _isSaving ? null : _save,
          child: _isSaving
              ? const SizedBox(
                  width: 16, height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(AppLocalizations.of(context, 'save')),
        ),
      ],
    );
  }
}

/// A section title with an optional action beside it.
class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, this.actionLabel, this.onAction});

  final String title;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Row(
        children: [
          Expanded(
            child: Text(title, style: Theme.of(context).textTheme.titleLarge),
          ),
          if (actionLabel != null && onAction != null)
            TextButton.icon(
              onPressed: onAction,
              icon: const Icon(Icons.add, size: 18),
              label: Text(actionLabel!),
            ),
        ],
      ),
    );
  }
}
