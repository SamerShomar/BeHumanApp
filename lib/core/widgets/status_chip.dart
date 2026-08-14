import 'package:flutter/material.dart';

import 'package:be_human_app/core/theme/app_colors.dart';
import 'package:be_human_app/features/proposals/domain/proposal_status.dart';

/// A proposal's status, as a coloured pill.
///
/// The three states used to render in the same blue, so the most important
/// fact on the screen could only be read word by word. Colour makes a list
/// scannable; the label is still there, because colour alone excludes anyone
/// who cannot distinguish these hues.
class StatusChip extends StatelessWidget {
  const StatusChip({required this.status, this.compact = false, super.key});

  final Object? status;
  final bool compact;

  static Color colorFor(Object? status) => switch (ProposalStatus.normalize(status)) {
        ProposalStatus.accepted => AppColors.success,
        ProposalStatus.rejected => AppColors.danger,
        _ => AppColors.warning,
      };

  static IconData iconFor(Object? status) => switch (ProposalStatus.normalize(status)) {
        ProposalStatus.accepted => Icons.check_circle_outline,
        ProposalStatus.rejected => Icons.cancel_outlined,
        _ => Icons.schedule,
      };

  @override
  Widget build(BuildContext context) {
    final color = colorFor(status);
    final theme = Theme.of(context);

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 8 : 10,
        vertical: compact ? 3 : 5,
      ),
      decoration: BoxDecoration(
        color: color.withOpacity(theme.brightness == Brightness.dark ? 0.18 : 0.14),
        borderRadius: BorderRadius.circular(AppRadius.pill),
        border: Border.all(color: color.withOpacity(0.45)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(iconFor(status), size: compact ? 12 : 14, color: color),
          const SizedBox(width: 5),
          Text(
            ProposalStatus.label(context, status),
            style: (compact ? theme.textTheme.labelSmall : theme.textTheme.titleSmall)
                ?.copyWith(color: color),
          ),
        ],
      ),
    );
  }
}
