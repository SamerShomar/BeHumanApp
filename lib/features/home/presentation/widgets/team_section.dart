import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:be_human_app/core/languages/app_localizations.dart';
import 'package:be_human_app/core/theme/app_colors.dart';
import 'package:be_human_app/core/widgets/glass.dart';
import 'package:be_human_app/core/widgets/state_views.dart';
import 'package:be_human_app/features/admin/presentation/providers/admin_providers.dart';
import 'package:be_human_app/features/auth/domain/entities/app_user.dart';
import 'package:be_human_app/features/auth/presentation/widgets/user_avatar.dart';

/// Everyone on the foundation, at the foot of the home screen.
///
/// Ordered by responsibility rather than alphabetically: the board first, then
/// the managers, then everybody else, and names alphabetical inside each
/// group. Whoever opens this is usually looking for "who decides on this" or
/// "who do I ask", and a flat A–Z list answers neither.
class TeamSection extends ConsumerWidget {
  const TeamSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final users = ref.watch(usersProvider);
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
          child: Text(
            AppLocalizations.of(context, 'team_and_board'),
            style: theme.textTheme.titleLarge,
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        users.when(
          loading: () => const LoadingStateView(),
          error: (error, _) => ErrorStateView(error: error),
          data: (all) {
            // Deactivated accounts are not on the team any more; listing them
            // beside people who are would misrepresent who is here.
            final members = [...all.where((u) => u.isActive)]..sort(_byStanding);

            if (members.isEmpty) {
              return EmptyStateView(
                icon: Icons.groups_outlined,
                message: AppLocalizations.of(context, 'team_and_board_empty'),
              );
            }

            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
              child: GlassCard(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md,
                  vertical: AppSpacing.sm,
                ),
                child: Column(
                  children: [
                    for (var i = 0; i < members.length; i++) ...[
                      if (i > 0)
                        Divider(
                          height: 1,
                          color: theme.colorScheme.onSurface.withOpacity(0.07),
                        ),
                      _MemberRow(user: members[i]),
                    ],
                  ],
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  static int _byStanding(AppUser a, AppUser b) {
    int rank(UserRole role) => switch (role) {
          UserRole.admin => 0,
          UserRole.manager => 1,
          UserRole.member => 2,
        };
    final byRole = rank(a.role).compareTo(rank(b.role));
    return byRole != 0 ? byRole : a.name.compareTo(b.name);
  }
}

class _MemberRow extends StatelessWidget {
  const _MemberRow({required this.user});

  final AppUser user;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accent = switch (user.role) {
      UserRole.admin => AppColors.brand,
      UserRole.manager => AppColors.success,
      UserRole.member => theme.colorScheme.onSurface.withOpacity(0.55),
    };

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      child: Row(
        children: [
          UserAvatar(
            photoPath: user.photoPath,
            name: user.name,
            radius: 22,
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  user.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleSmall,
                ),
                const SizedBox(height: 2),
                // Role and team together: "manager" alone does not say which
                // half of the foundation somebody manages.
                Text(
                  '${user.role.label(context)} · ${user.team.label(context)}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(color: accent),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
