import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:be_human_app/core/languages/app_localizations.dart';
import 'package:be_human_app/core/theme/app_colors.dart';
import 'package:be_human_app/core/widgets/glass.dart';

/// One project on the home screen: what it was, a line or two about it, how
/// many people it reached and where.
class ProjectCard extends StatelessWidget {
  const ProjectCard({
    required this.title,
    required this.description,
    this.beneficiaries,
    this.location,
    this.onTap,
    super.key,
  });

  final String title;
  final String description;
  final int? beneficiaries;
  final String? location;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return GlassCard(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: AppColors.brand.withOpacity(0.14),
                  borderRadius: BorderRadius.circular(AppRadius.small),
                ),
                child: const Icon(
                  Icons.volunteer_activism_outlined,
                  color: AppColors.brand,
                  size: 22,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Text(
                  title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleMedium,
                ),
              ),
            ],
          ),
          if (description.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(
              description,
              // Clamped rather than scrollable: this is a summary, and the
              // full text belongs on the project itself.
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodyMedium,
            ),
          ],
          if (beneficiaries != null || location != null) ...[
            const SizedBox(height: AppSpacing.md),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: [
                if (beneficiaries != null)
                  _Fact(
                    icon: Icons.groups_outlined,
                    color: AppColors.success,
                    label: AppLocalizations.of(
                      context,
                      'beneficiaries_count',
                      {'count': NumberFormat('#,##0', 'en').format(beneficiaries)},
                    ),
                  ),
                if (location != null)
                  _Fact(
                    icon: Icons.place_outlined,
                    color: AppColors.brandDeep,
                    label: location!,
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

/// A single labelled fact about a project.
class _Fact extends StatelessWidget {
  const _Fact({required this.icon, required this.color, required this.label});

  final IconData icon;
  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(AppRadius.pill),
        border: Border.all(color: color.withOpacity(0.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 6),
          // Flexible so a long place name shortens instead of overflowing —
          // "غزة — مخيم الشاطئ" is a good deal wider than "Gaza".
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.labelSmall?.copyWith(color: color),
            ),
          ),
        ],
      ),
    );
  }
}
