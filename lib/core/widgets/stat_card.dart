import 'package:flutter/material.dart';

import 'package:be_human_app/core/theme/app_colors.dart';
import 'package:be_human_app/core/utils/formatters.dart';
import 'package:be_human_app/core/widgets/glass.dart';

/// One headline figure — balance, income, expenses.
///
/// The home and finance screens used to draw these differently, so the same
/// three numbers looked like different data depending on where you saw them.
/// This is now the only way they are drawn.
///
/// Two details matter and were both wrong before:
///
///  * the amount is inside a [FittedBox], so a long figure shrinks instead of
///    wrapping — the finance screen was splitting `15349.50$` across two lines,
///    mid-number;
///  * the card has a fixed height, so a label that wraps to two lines does not
///    make one card taller than the two beside it.
class StatCard extends StatelessWidget {
  const StatCard({
    required this.label,
    required this.amount,
    this.secondary,
    required this.color,
    required this.icon,
    super.key,
  });

  final String label;

  /// Already formatted. The card used to format it, which meant the caller
  /// could not show a figure the formatter did not know how to produce — a
  /// second currency, for instance.
  final Object? amount;

  /// A second, quieter line under the headline figure. Used for the same
  /// total expressed in the other currency.
  final String? secondary;

  final Color color;
  final IconData icon;

  static const double height = 104;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SizedBox(
      height: height,
      child: GlassCard(
        tint: color,
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.md,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Icon(icon, size: 16, color: color),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    label,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.labelSmall?.copyWith(color: color),
                  ),
                ),
              ],
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: double.infinity,
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: AlignmentDirectional.centerStart,
                    child: Text(
                      amount is String ? amount as String : Formatters.amount(amount),
                      maxLines: 1,
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: color,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
                if (secondary != null)
                  SizedBox(
                    width: double.infinity,
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: AlignmentDirectional.centerStart,
                      child: Text(
                        secondary!,
                        maxLines: 1,
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: color.withOpacity(0.85),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// The three figures side by side, spaced consistently.
class StatCardRow extends StatelessWidget {
  const StatCardRow({required this.cards, super.key});

  final List<StatCard> cards;

  @override
  Widget build(BuildContext context) {
    // No `stretch` here: the row sits in a Column, where stretching the cross
    // axis asks for infinite height. Each card carries its own fixed height,
    // which is what keeps the three aligned.
    return Row(
      children: [
        for (var i = 0; i < cards.length; i++) ...[
          if (i > 0) const SizedBox(width: AppSpacing.md),
          Expanded(child: cards[i]),
        ],
      ],
    );
  }
}
