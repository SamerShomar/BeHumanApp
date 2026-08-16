import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:be_human_app/core/languages/app_localizations.dart';
import 'package:be_human_app/core/theme/app_colors.dart';
import 'package:be_human_app/core/utils/connectivity.dart';

/// A small marker in the corner saying the device is offline.
///
/// This replaces a full "no internet" screen. That screen was wrong about what
/// losing signal means here: with Firestore's offline cache the app keeps
/// working — records are read from the cache, and edits queue and send
/// themselves when the network returns. Blocking the whole app for a condition
/// it handles was stopping people from doing work they could perfectly well do
/// on a connection that drops constantly.
///
/// So it states a fact and stays out of the way. It cannot be dismissed,
/// because it disappears exactly when it stops being true.
class OfflineIndicator extends ConsumerWidget {
  const OfflineIndicator({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // `valueOrNull ?? true`: while the first reading is still in flight, say
    // nothing rather than accuse the connection.
    final isOnline = ref.watch(isOnlineProvider).valueOrNull ?? true;

    return Stack(
      children: [
        child,
        // Directional, so it sits in the corner the reader's language calls
        // the end — left in Arabic, right in English.
        PositionedDirectional(
          top: MediaQuery.paddingOf(context).top + 6,
          end: AppSpacing.md,
          child: IgnorePointer(
            child: AnimatedSlide(
              offset: isOnline ? const Offset(0, -2) : Offset.zero,
              duration: const Duration(milliseconds: 260),
              curve: Curves.easeOutCubic,
              child: AnimatedOpacity(
                opacity: isOnline ? 0 : 1,
                duration: const Duration(milliseconds: 200),
                child: const _OfflinePill(),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _OfflinePill extends StatelessWidget {
  const _OfflinePill();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;

    return Material(
      color: Colors.transparent,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: dark ? const Color(0xFF2A1A1E) : const Color(0xFFFDECEE),
          borderRadius: BorderRadius.circular(AppRadius.pill),
          border: Border.all(color: AppColors.danger.withOpacity(0.35)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(dark ? 0.35 : 0.08),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: const BoxDecoration(
                color: AppColors.danger,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 7),
            Text(
              AppLocalizations.of(context, 'offline_short'),
              style: theme.textTheme.labelSmall?.copyWith(
                color: AppColors.danger,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
