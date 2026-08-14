import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:be_human_app/core/languages/app_localizations.dart';
import 'package:be_human_app/core/theme/app_colors.dart';
import 'package:be_human_app/core/utils/formatters.dart';
import 'package:be_human_app/core/widgets/glass.dart';
import 'package:be_human_app/core/widgets/state_views.dart';
import 'package:be_human_app/core/widgets/stat_card.dart';
import 'package:be_human_app/core/widgets/status_chip.dart';
import 'package:be_human_app/features/admin/presentation/providers/admin_providers.dart';
import 'package:be_human_app/features/auth/presentation/providers/auth_provider.dart';
import 'package:be_human_app/features/auth/presentation/widgets/user_avatar.dart';
import 'package:be_human_app/features/notifications/presentation/widgets/notification_bell.dart';
import 'package:be_human_app/features/projects/presentation/providers/project_providers.dart';
import 'package:be_human_app/features/projects/presentation/widgets/project_card.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserStreamProvider);
    final finances = ref.watch(financesProvider);
    final proposals = ref.watch(proposalsProvider);
    final projects = ref.watch(projectsProvider);
    final siteContent = ref.watch(siteContentProvider).valueOrNull ?? const {};
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        bottom: false,
        child: SingleChildScrollView(
          // Room for the floating navigation bar the shell extends behind.
          padding: const EdgeInsets.only(bottom: 110),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: AppSpacing.lg),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
                child: Row(
                  children: [
                    if (user.valueOrNull != null)
                      UserAvatar(
                        photoPath: user.valueOrNull!.photoPath,
                        name: user.valueOrNull!.name,
                        radius: 22,
                      ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            AppLocalizations.of(context, 'overview'),
                            style: theme.textTheme.bodySmall,
                          ),
                          Text(
                            user.when(
                              data: (u) => u?.name ?? '',
                              loading: () => '…',
                              error: (_, __) => '',
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.headlineSmall,
                          ),
                        ],
                      ),
                    ),
                    const NotificationBell(),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.xl),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
                child: StatCardRow(
                  cards: [
                    StatCard(
                      label: AppLocalizations.of(context, 'balance_current'),
                      amount: finances['balance'],
                      color: AppColors.brand,
                      icon: Icons.account_balance_wallet_outlined,
                    ),
                    StatCard(
                      label: AppLocalizations.of(context, 'incoming'),
                      amount: finances['totalIncome'],
                      color: AppColors.success,
                      icon: Icons.south_west,
                    ),
                    StatCard(
                      label: AppLocalizations.of(context, 'outgoing'),
                      amount: finances['totalExpense'],
                      color: AppColors.danger,
                      icon: Icons.north_east,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.xl),

              // What the organisation says about itself, straight from the
              // website. Hidden entirely when nobody has imported it yet,
              // rather than leaving an empty card on the screen.
              if ((siteContent['mission'] ?? '').isNotEmpty)
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.xl, 0, AppSpacing.xl, AppSpacing.xl,
                  ),
                  child: GlassCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.public, size: 16, color: AppColors.brand),
                            const SizedBox(width: 6),
                            Text(
                              AppLocalizations.of(context, 'about_org'),
                              style: theme.textTheme.labelSmall
                                  ?.copyWith(color: AppColors.brand),
                            ),
                          ],
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        Text(
                          siteContent['mission']!,
                          maxLines: 4,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodyMedium,
                        ),
                      ],
                    ),
                  ),
                ),

              Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
                child: Text(
                  AppLocalizations.of(context, 'latest_projects'),
                  style: theme.textTheme.titleLarge,
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              projects.when(
                loading: () => const LoadingStateView(),
                error: (error, _) => ErrorStateView(error: error),
                data: (items) {
                  if (items.isEmpty) {
                    return EmptyStateView(
                      icon: Icons.volunteer_activism_outlined,
                      message: AppLocalizations.of(context, 'no_projects'),
                    );
                  }
                  return Column(
                    children: [
                      for (final project in items.take(3))
                        Padding(
                          padding: const EdgeInsets.fromLTRB(
                            AppSpacing.xl, 0, AppSpacing.xl, AppSpacing.md,
                          ),
                          child: ProjectCard(
                            title: project.title,
                            description: project.description,
                            beneficiaries: project.beneficiaries,
                            location: project.location,
                          ),
                        ),
                    ],
                  );
                },
              ),

              const SizedBox(height: AppSpacing.lg),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        AppLocalizations.of(context, 'recent_proposals'),
                        style: theme.textTheme.titleLarge,
                      ),
                    ),
                    TextButton(
                      onPressed: () => context.go('/proposals'),
                      child: Text(AppLocalizations.of(context, 'view_all')),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              proposals.when(
                loading: () => const LoadingStateView(),
                error: (error, _) => ErrorStateView(error: error),
                data: (items) {
                  if (items.isEmpty) {
                    return EmptyStateView(
                      icon: Icons.description_outlined,
                      message: AppLocalizations.of(context, 'no_proposals'),
                    );
                  }
                  return Column(
                    children: [
                      for (final proposal in items.take(3))
                        Padding(
                          padding: const EdgeInsets.fromLTRB(
                            AppSpacing.xl, 0, AppSpacing.xl, AppSpacing.md,
                          ),
                          child: _ProposalPreview(proposal: proposal),
                        ),
                    ],
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProposalPreview extends StatelessWidget {
  const _ProposalPreview({required this.proposal});

  final Map<String, dynamic> proposal;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final status = proposal['status'];

    return GlassCard(
      onTap: () => context.go('/proposals'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: StatusChip.colorFor(status).withOpacity(0.14),
                  borderRadius: BorderRadius.circular(AppRadius.small),
                ),
                child: Icon(
                  Icons.description_outlined,
                  color: StatusChip.colorFor(status),
                  size: 20,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      proposal['title'] as String? ??
                          proposal['fileName'] as String? ??
                          AppLocalizations.of(context, 'proposal_placeholder'),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleMedium,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      Formatters.date(proposal['date']),
                      style: theme.textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              // Localised and colour-coded. This was printing the stored key —
              // "pending" — in English no matter the app's language.
              StatusChip(status: status, compact: true),
              const Spacer(),
              Text(
                Formatters.amount(proposal['amount']),
                style: theme.textTheme.titleMedium?.copyWith(color: AppColors.brand),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
