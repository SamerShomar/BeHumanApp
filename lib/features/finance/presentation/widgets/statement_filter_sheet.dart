import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:be_human_app/core/languages/app_localizations.dart';
import 'package:be_human_app/core/theme/app_colors.dart';
import 'package:be_human_app/core/utils/formatters.dart';
import 'package:be_human_app/features/finance/domain/statement_filter.dart';

/// What the sheet was closed with.
///
/// Two ways out that both keep the filter, so "print" does not need the caller
/// to guess whether the numbers on screen are the ones being printed.
class StatementFilterResult {
  const StatementFilterResult({required this.filter, required this.print});

  final StatementFilter filter;
  final bool print;
}

/// The filter panel: a period, an amount range, and a print button.
///
/// One sheet rather than a toolbar of icons. Choosing what goes on a statement
/// is a single decision made in one go — dates and amounts together — and the
/// button that prints it belongs next to the choices it prints, not in an app
/// bar three taps away from them.
class StatementFilterSheet extends StatefulWidget {
  const StatementFilterSheet({required this.initial, super.key});

  final StatementFilter initial;

  static Future<StatementFilterResult?> show(
    BuildContext context,
    StatementFilter initial,
  ) {
    return showModalBottomSheet<StatementFilterResult>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => StatementFilterSheet(initial: initial),
    );
  }

  @override
  State<StatementFilterSheet> createState() => _StatementFilterSheetState();
}

class _StatementFilterSheetState extends State<StatementFilterSheet> {
  late DateTime? _from = widget.initial.from;
  late DateTime? _to = widget.initial.to;
  late final TextEditingController _min = TextEditingController(
    text: widget.initial.minAmount == null ? '' : _plain(widget.initial.minAmount!),
  );
  late final TextEditingController _max = TextEditingController(
    text: widget.initial.maxAmount == null ? '' : _plain(widget.initial.maxAmount!),
  );

  static String _plain(double value) =>
      value == value.roundToDouble() ? value.toStringAsFixed(0) : '$value';

  @override
  void dispose() {
    _min.dispose();
    _max.dispose();
    super.dispose();
  }

  StatementFilter get _filter => StatementFilter(
        from: _from,
        to: _to,
        minAmount: double.tryParse(_min.text.trim()),
        maxAmount: double.tryParse(_max.text.trim()),
      );

  Future<void> _pickDate({required bool isStart}) async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: (isStart ? _from : _to) ?? now,
      firstDate: DateTime(now.year - 10),
      lastDate: DateTime(now.year + 1),
    );
    if (picked == null) return;

    setState(() {
      if (isStart) {
        _from = picked;
        // Keeping an end date that now precedes the start would filter
        // everything out and read as "there are no movements".
        if (_to != null && _to!.isBefore(picked)) _to = picked;
      } else {
        _to = picked;
        if (_from != null && _from!.isAfter(picked)) _from = picked;
      }
    });
  }

  void _clear() {
    setState(() {
      _from = null;
      _to = null;
      _min.clear();
      _max.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;

    return Padding(
      // Lifts the sheet clear of the keyboard when an amount field has focus.
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: Container(
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: const BorderRadius.vertical(
            top: Radius.circular(AppRadius.card),
          ),
          border: Border.all(color: AppColors.glassStroke(dark)),
        ),
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.xl, AppSpacing.md, AppSpacing.xl, AppSpacing.xl,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.onSurface.withOpacity(0.18),
                    borderRadius: BorderRadius.circular(AppRadius.pill),
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      AppLocalizations.of(context, 'filter_statement'),
                      style: theme.textTheme.titleLarge,
                    ),
                  ),
                  if (!_filter.isEmpty)
                    TextButton(
                      onPressed: _clear,
                      child: Text(AppLocalizations.of(context, 'clear_filter')),
                    ),
                ],
              ),
              const SizedBox(height: AppSpacing.lg),

              _SectionLabel(
                icon: Icons.date_range,
                text: AppLocalizations.of(context, 'period'),
              ),
              const SizedBox(height: AppSpacing.sm),
              Row(
                children: [
                  Expanded(
                    child: _DateField(
                      label: AppLocalizations.of(context, 'from_date'),
                      value: _from,
                      onTap: () => _pickDate(isStart: true),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: _DateField(
                      label: AppLocalizations.of(context, 'to_date'),
                      value: _to,
                      onTap: () => _pickDate(isStart: false),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: AppSpacing.xl),
              _SectionLabel(
                icon: Icons.euro,
                text: AppLocalizations.of(context, 'amount_range'),
              ),
              const SizedBox(height: AppSpacing.sm),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _min,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                      ],
                      onChanged: (_) => setState(() {}),
                      decoration: InputDecoration(
                        labelText: AppLocalizations.of(context, 'amount_from'),
                        prefixText: '€ ',
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: TextField(
                      controller: _max,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                      ],
                      onChanged: (_) => setState(() {}),
                      decoration: InputDecoration(
                        labelText: AppLocalizations.of(context, 'amount_to'),
                        prefixText: '€ ',
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: AppSpacing.xl),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.picture_as_pdf_outlined),
                  label: Text(AppLocalizations.of(context, 'print_payment_statement')),
                  onPressed: () => Navigator.of(context).pop(
                    StatementFilterResult(filter: _filter, print: true),
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              SizedBox(
                width: double.infinity,
                child: TextButton(
                  onPressed: () => Navigator.of(context).pop(
                    StatementFilterResult(filter: _filter, print: false),
                  ),
                  child: Text(AppLocalizations.of(context, 'apply_filter')),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 16, color: AppColors.brand),
        const SizedBox(width: 6),
        Text(
          text,
          style: Theme.of(context)
              .textTheme
              .labelLarge
              ?.copyWith(color: AppColors.brand),
        ),
      ],
    );
  }
}

/// A date, shown the way a text field is, so the two rows of the sheet read as
/// one form rather than as buttons above inputs.
class _DateField extends StatelessWidget {
  const _DateField({required this.label, required this.value, required this.onTap});

  final String label;
  final DateTime? value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.button),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          suffixIcon: const Icon(Icons.calendar_today_outlined, size: 16),
        ),
        child: Text(
          value == null
              ? AppLocalizations.of(context, 'any_date')
              : Formatters.date(value!.toIso8601String()),
          style: value == null
              ? theme.textTheme.bodyMedium
                  ?.copyWith(color: theme.hintColor)
              : theme.textTheme.bodyMedium,
        ),
      ),
    );
  }
}
