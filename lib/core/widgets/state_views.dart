import 'package:flutter/material.dart';

import 'package:be_human_app/core/languages/app_localizations.dart';
import 'package:be_human_app/core/theme/app_colors.dart';

/// What a list shows when it has nothing to show.
///
/// Several screens rendered an empty white area for *all three* of loading,
/// failed and empty, so a user could not tell a slow connection from a broken
/// app from a genuinely empty folder. These make the three distinguishable.
class EmptyStateView extends StatelessWidget {
  const EmptyStateView({
    required this.icon,
    required this.message,
    this.actionLabel,
    this.onAction,
    super.key,
  });

  final IconData icon;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurface.withOpacity(0.45);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 84,
              height: 84,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.brand.withOpacity(0.10),
                border: Border.all(color: AppColors.brand.withOpacity(0.22)),
              ),
              child: Icon(icon, size: 36, color: AppColors.brand.withOpacity(0.8)),
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(
              message,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyLarge?.copyWith(color: muted),
            ),
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: AppSpacing.lg),
              SizedBox(
                width: 200,
                child: ElevatedButton(onPressed: onAction, child: Text(actionLabel!)),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// A failure the user can act on, rather than a raw exception in the middle of
/// the screen.
class ErrorStateView extends StatelessWidget {
  const ErrorStateView({required this.error, this.onRetry, super.key});

  final Object error;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 84,
              height: 84,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.danger.withOpacity(0.10),
                border: Border.all(color: AppColors.danger.withOpacity(0.25)),
              ),
              child: const Icon(Icons.error_outline, size: 36, color: AppColors.danger),
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(
              AppLocalizations.of(context, 'error_generic'),
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              '$error',
              textAlign: TextAlign.center,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall,
            ),
            if (onRetry != null) ...[
              const SizedBox(height: AppSpacing.lg),
              SizedBox(
                width: 200,
                child: OutlinedButton(
                  onPressed: onRetry,
                  child: Text(AppLocalizations.of(context, 'retry')),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// The one spinner, so waiting looks the same everywhere.
class LoadingStateView extends StatelessWidget {
  const LoadingStateView({super.key});

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(AppSpacing.xxl),
        child: SizedBox(
          width: 32,
          height: 32,
          child: CircularProgressIndicator(strokeWidth: 3),
        ),
      ),
    );
  }
}
