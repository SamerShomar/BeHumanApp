import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import 'package:be_human_app/core/theme/app_theme.dart';
import 'package:be_human_app/core/languages/app_localizations.dart';
import 'package:be_human_app/features/admin/presentation/providers/admin_providers.dart';
import 'package:be_human_app/features/auth/presentation/providers/auth_provider.dart';
import 'package:be_human_app/features/notifications/presentation/widgets/notification_bell.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserStreamProvider);
    final finances = ref.watch(financesProvider);
    final proposals = ref.watch(proposalsProvider);

    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: isDarkMode ? const Color(0xFF0A1628) : const Color(0xFFF0F4F8),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.only(bottom: 24.h),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(height: 20.h),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 20.w),
                // The home screen has no app bar, so the bell sits beside the
                // greeting instead — it must be reachable from every screen.
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            AppLocalizations.of(context, 'overview'),
                            style: TextStyle(
                              color: colorScheme.onSurface,
                              fontSize: 14,
                              fontWeight: FontWeight.w400,
                            ),
                          ),
                          SizedBox(height: 4.h),
                          Text(
                            user.when(
                              data: (u) => u?.name ?? '',
                              loading: () => '...',
                              error: (_, __) => '',
                            ),
                            style: TextStyle(
                              color: colorScheme.primary,
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const NotificationBell(),
                  ],
                ),
              ),
              SizedBox(height: 30.h),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 20.w),
                child: Row(
                  children: [
                    Expanded(
                      child: _StatCard(
                        label: AppLocalizations.of(context, 'balance_current'),
                        amount: finances['balance'],
                        color: Colors.blue,
                      ),
                    ),
                    SizedBox(width: 12.w),
                    Expanded(
                      child: _StatCard(
                        label: AppLocalizations.of(context, 'incoming'),
                        amount: finances['totalIncome'],
                        color: Colors.green,
                      ),
                    ),
                    SizedBox(width: 12.w),
                    Expanded(
                      child: _StatCard(
                        label: AppLocalizations.of(context, 'outgoing'),
                        amount: finances['totalExpense'],
                        color: Colors.red,
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: 30.h),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 20.w),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      AppLocalizations.of(context, 'recent_proposals'),
                      style: TextStyle(
                        color: colorScheme.onSurface,
                        fontSize: 18.sp,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    TextButton(
                      onPressed: () => context.go('/proposals'),
                      child: Text(AppLocalizations.of(context, 'proposals')),
                    ),
                  ],
                ),
              ),
              SizedBox(height: 8.h),
              proposals.when(
                loading: () => Padding(
                  padding: EdgeInsets.symmetric(vertical: 32.h),
                  child: const Center(child: CircularProgressIndicator()),
                ),
                error: (error, _) => _Message(
                  text: '${AppLocalizations.of(context, 'error_generic')}: $error',
                ),
                data: (items) {
                  if (items.isEmpty) {
                    return _Message(text: AppLocalizations.of(context, 'no_proposals'));
                  }
                  // Firestore already orders by date descending.
                  return Column(
                    children: [
                      for (final proposal in items.take(3))
                        Padding(
                          padding: EdgeInsets.only(bottom: 12.h),
                          child: _ProposalCard(proposal: proposal, isDarkMode: isDarkMode),
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

/// Formats an amount for display, tolerating a missing or non-numeric value
/// rather than showing a fabricated figure.
String formatAmount(Object? value) {
  final number = value is num ? value : num.tryParse('${value ?? ''}');
  if (number == null) return '—';
  return '${NumberFormat('#,##0.##', 'en').format(number)}\$';
}

class _StatCard extends StatelessWidget {
  const _StatCard({required this.label, required this.amount, required this.color});

  final String label;
  final Object? amount;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(12.r),
      decoration: AppTheme.statCardDark(color),
      child: Column(
        children: [
          Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(color: color, fontSize: 13.sp, fontWeight: FontWeight.bold),
          ),
          SizedBox(height: 8.h),
          FittedBox(
            child: Text(
              formatAmount(amount),
              style: TextStyle(color: color, fontSize: 18.sp, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }
}

class _ProposalCard extends StatelessWidget {
  const _ProposalCard({required this.proposal, required this.isDarkMode});

  final Map<String, dynamic> proposal;
  final bool isDarkMode;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 20.w),
      child: Container(
        padding: EdgeInsets.all(16.r),
        decoration: isDarkMode ? AppTheme.glassCardDark() : AppTheme.glassCardLight(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 40.w,
                  height: 40.h,
                  decoration: BoxDecoration(
                    color: Colors.blue.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(8.r),
                  ),
                  child: const Icon(Icons.description, color: Colors.blue, size: 24),
                ),
                SizedBox(width: 12.w),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        proposal['title'] as String? ??
                            proposal['fileName'] as String? ??
                            AppLocalizations.of(context, 'proposal_placeholder'),
                        style: TextStyle(
                          color: colorScheme.onSurface,
                          fontSize: 16.sp,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        _formatDate(proposal['date']),
                        style: TextStyle(
                          color: colorScheme.onSurface.withOpacity(0.6),
                          fontSize: 12.sp,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            SizedBox(height: 12.h),
            Row(
              children: [
                Text(
                  '${AppLocalizations.of(context, 'status')}: ',
                  style: TextStyle(
                    color: colorScheme.onSurface.withOpacity(0.8),
                    fontSize: 14.sp,
                  ),
                ),
                Text(
                  proposal['status'] as String? ?? '',
                  style: TextStyle(
                    color: colorScheme.primary,
                    fontSize: 14.sp,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                Text(
                  formatAmount(proposal['amount']),
                  style: TextStyle(
                    color: colorScheme.primary,
                    fontSize: 14.sp,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// Proposals store an ISO-8601 string; fall back to the raw value so a
  /// legacy or malformed entry still renders.
  static String _formatDate(Object? value) {
    if (value is! String) return '';
    final parsed = DateTime.tryParse(value);
    if (parsed == null) return value;
    return DateFormat('yyyy-MM-dd').format(parsed);
  }
}

class _Message extends StatelessWidget {
  const _Message({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 32.h),
      child: Center(
        child: Text(
          text,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
          ),
        ),
      ),
    );
  }
}
