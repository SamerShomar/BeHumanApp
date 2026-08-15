import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'package:be_human_app/core/languages/app_localizations.dart';
import 'package:be_human_app/core/theme/app_colors.dart';
import 'package:be_human_app/core/utils/formatters.dart';
import 'package:be_human_app/core/widgets/app_fab.dart';
import 'package:be_human_app/core/widgets/glass.dart';
import 'package:be_human_app/core/widgets/stat_card.dart';
import 'package:be_human_app/core/widgets/state_views.dart';
import 'package:be_human_app/features/finance/data/statement_exporter.dart';
import 'package:be_human_app/features/finance/presentation/screens/pdf_preview_screen.dart';
import 'package:be_human_app/features/finance/domain/money.dart';
import 'package:be_human_app/features/finance/domain/statement_range.dart';
import 'package:be_human_app/features/finance/presentation/widgets/statement_document.dart';
import 'package:be_human_app/core/services/file_storage_service.dart';
import 'package:be_human_app/features/admin/presentation/providers/admin_providers.dart';
import 'package:be_human_app/features/auth/presentation/providers/auth_provider.dart';
import 'package:be_human_app/features/auth/domain/entities/app_user.dart';
import 'package:be_human_app/features/notifications/presentation/providers/notification_providers.dart';
import 'package:be_human_app/features/notifications/presentation/widgets/notification_bell.dart';
import 'package:be_human_app/core/domain/attachment.dart';
import 'package:be_human_app/core/widgets/attachment_viewer.dart';

class FinanceScreen extends ConsumerStatefulWidget {
  const FinanceScreen({super.key});

  @override
  ConsumerState<FinanceScreen> createState() => _FinanceScreenState();
}

class _FinanceScreenState extends ConsumerState<FinanceScreen> {
  StatementRange? _range;
  bool _isExporting = false;

  @override
  Widget build(BuildContext context) {
    final transactions = ref.watch(transactionsProvider);

    // Totals follow the filter, so an exported statement and the figures on
    // screen can never disagree.
    final visible = _range == null
        ? (transactions.valueOrNull ?? const <Map<String, dynamic>>[])
        : _range!.filter(transactions.valueOrNull ?? const []);
    final totals = MoneyTotals.of(visible);

    // Gaza members see the ledger but cannot change it; the rules enforce the
    // same thing server-side, so this only decides what is worth showing.
    final hasWriteAccess =
        ref.watch(currentUserStreamProvider).valueOrNull?.hasFinancialAccess ?? false;

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: GlassAppBar(
        title: AppLocalizations.of(context, 'financial'),
        actions: [
          IconButton(
            icon: const Icon(Icons.date_range),
            tooltip: AppLocalizations.of(context, 'pick_range'),
            onPressed: _pickRange,
          ),
          if (_range != null)
            IconButton(
              icon: const Icon(Icons.filter_alt_off),
              tooltip: AppLocalizations.of(context, 'clear_filter'),
              onPressed: () => setState(() => _range = null),
            ),
          IconButton(
            icon: _isExporting
                ? const SizedBox(
                    width: 18, height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.picture_as_pdf),
            tooltip: AppLocalizations.of(context, 'export_statement'),
            onPressed: _isExporting ? null : () => _export(visible),
          ),
          const NotificationBell(),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg, AppSpacing.md, AppSpacing.lg, 0,
            ),
            child: StatCardRow(
              cards: [
                StatCard(
                  label: AppLocalizations.of(context, 'balance'),
                  amount: Money.format(totals.balanceEur, StatementCurrency.eur),
                  color: AppColors.brand,
                  icon: Icons.account_balance_wallet_outlined,
                ),
                StatCard(
                  label: AppLocalizations.of(context, 'incoming'),
                  amount: Money.format(totals.incomeEur, StatementCurrency.eur),
                  color: AppColors.success,
                  icon: Icons.south_west,
                ),
                StatCard(
                  label: AppLocalizations.of(context, 'outgoing'),
                  amount: Money.format(totals.expenseEur, StatementCurrency.eur),
                  color: AppColors.danger,
                  icon: Icons.north_east,
                ),
              ],
            ),
          ),
          if (_range != null || !hasWriteAccess)
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg, AppSpacing.md, AppSpacing.lg, 0,
              ),
              child: Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.sm,
                children: [
                  if (_range != null)
                    _InfoPill(
                      icon: Icons.date_range,
                      label: '${Formatters.date(_range!.from)}  →  '
                          '${Formatters.date(_range!.to)}',
                      onClear: () => setState(() => _range = null),
                    ),
                  if (!hasWriteAccess)
                    _InfoPill(
                      icon: Icons.visibility_outlined,
                      label: AppLocalizations.of(context, 'read_only_notice'),
                    ),
                ],
              ),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg, AppSpacing.lg, AppSpacing.lg, AppSpacing.sm,
            ),
            child: Text(
              AppLocalizations.of(context, 'transactions'),
              style: Theme.of(context).textTheme.titleLarge,
            ),
          ),
          Expanded(
            child: transactions.when(
              loading: () => const LoadingStateView(),
              error: (e, s) => ErrorStateView(error: e),
              data: (_) {
                if (visible.isEmpty) {
                  return EmptyStateView(
                    icon: Icons.receipt_long_outlined,
                    message: AppLocalizations.of(context, 'no_transactions'),
                  );
                }
                return ListView.builder(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.lg, 0, AppSpacing.lg, 120,
                  ),
                  itemCount: visible.length,
                  itemBuilder: (context, i) => Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.md),
                    child: _TransactionTile(transaction: visible[i]),
                  ),
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: hasWriteAccess
          ? AppFab(
              icon: Icons.add,
              label: AppLocalizations.of(context, 'add_movement'),
              onPressed: () => AddTransactionDialog.show(context),
            )
          : null,
    );
  }

  Future<void> _pickRange() async {
    final now = DateTime.now();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(now.year - 5),
      lastDate: DateTime(now.year + 1),
      initialDateRange: _range == null
          ? null
          : DateTimeRange(start: _range!.from, end: _range!.to),
    );
    if (picked == null) return;
    setState(() => _range = StatementRange(from: picked.start, to: picked.end));
  }

  Future<void> _export(List<Map<String, dynamic>> visible) async {
    final messenger = ScaffoldMessenger.of(context);
    final readyMessage = AppLocalizations.of(context, 'statement_ready');
    final user = ref.read(currentUserStreamProvider).valueOrNull;

    // Exporting without a chosen period means "everything on record", so the
    // header still needs a range to print.
    final range = _range ??
        StatementRange(
          from: _earliestDate(visible) ?? DateTime.now(),
          to: DateTime.now(),
        );

    // The statement renders detached from the app, so nothing is inherited —
    // the container has to be handed over explicitly or every lookup inside
    // it fails and the error box is what ends up in the PDF.
    final container = ProviderScope.containerOf(context);
    final direction = Directionality.of(context);
    final navigator = Navigator.of(context);
    final fileName = 'be-human-statement-'
        '${DateFormat('yyyyMMdd').format(range.from)}-'
        '${DateFormat('yyyyMMdd').format(range.to)}.pdf';

    setState(() => _isExporting = true);
    try {
      // Decoded before rendering, never resolved during it: the rasteriser
      // paints in one pass, and an image still loading paints as nothing.
      final images = await StatementImages.load();

      const exporter = StatementExporter();
      final png = await exporter.renderToImage(
        UncontrolledProviderScope(
          container: container,
          child: Directionality(
            textDirection: direction,
            child: _StatementHost(
              range: range,
              transactions: visible,
              issuedBy: user?.name ?? '',
              images: images,
            ),
          ),
        ),
        size: const Size(StatementDocument.pageWidth, StatementDocument.pageHeight),
      );
      final pdf = exporter.buildPdf(png);

      if (!mounted) return;
      setState(() => _isExporting = false);

      // Shown before sharing, not instead of it. The statement used to go
      // straight to the share sheet, so nobody saw what they were sending —
      // which is how a page of error text went out looking like a statement.
      await navigator.push(MaterialPageRoute<void>(
        builder: (_) => PdfPreviewScreen(bytes: pdf, fileName: fileName),
      ));
      messenger.showSnackBar(SnackBar(content: Text(readyMessage)));
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('$e')));
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }

  static DateTime? _earliestDate(List<Map<String, dynamic>> transactions) {
    DateTime? earliest;
    for (final t in transactions) {
      final date = StatementRange.parseDate(t['date']);
      if (date != null && (earliest == null || date.isBefore(earliest))) {
        earliest = date;
      }
    }
    return earliest;
  }

}

/// Adds a financial movement, optionally with a scanned invoice.
///
/// The invoice goes to Supabase like proposal PDFs do; the document keeps only
/// its object path, which is what makes it show up in the archive.
/// Records a financial movement.
///
/// Public because the admin dashboard offers the same action, and it used to
/// do it through a second, thinner dialog of its own — one that asked for
/// neither an exchange rate nor a transfer notice, and so could write rows the
/// rest of the app now treats as incomplete. One way in, one set of rules.
class AddTransactionDialog extends ConsumerStatefulWidget {
  const AddTransactionDialog({super.key});

  static Future<void> show(BuildContext context) => showDialog<void>(
        context: context,
        builder: (_) => const AddTransactionDialog(),
      );

  @override
  ConsumerState<AddTransactionDialog> createState() => _AddTransactionDialogState();
}

class _AddTransactionDialogState extends ConsumerState<AddTransactionDialog> {
  final _amountCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _rateCtrl = TextEditingController();
  String _type = 'income';

  /// Set from the signed-in member's team on the first build, then left alone
  /// so a deliberate change is not undone by a rebuild.
  StatementCurrency? _currency;
  PlatformFile? _receipt;
  bool _isSaving = false;

  @override
  void dispose() {
    _amountCtrl.dispose();
    _descCtrl.dispose();
    _rateCtrl.dispose();
    super.dispose();
  }

  /// Picks the transfer notice.
  ///
  /// A scan or a photo, both accepted: outside an office a transfer notice is
  /// usually a picture of a screen or a slip, and requiring a PDF meant
  /// requiring somebody to convert one before they could record a payment.
  Future<void> _pickReceipt() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: Attachment.allowedExtensions,
      withData: true,
    );
    if (result == null || result.files.isEmpty) return;

    final file = result.files.first;
    if (!Attachment.isAllowed(file.name)) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context, 'archive_file_types'))),
      );
      return;
    }

    setState(() => _receipt = file);
  }

  /// The currency this entry will be saved with, defaulting to the member's
  /// own team until they pick something else.
  StatementCurrency get _entryCurrency {
    final team = ref.read(currentUserStreamProvider).valueOrNull?.team;
    return _currency ??
        (team == null ? StatementCurrency.ils : StatementCurrency.forTeam(team));
  }

  Future<void> _save() async {
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);

    final amount = double.tryParse(_amountCtrl.text.trim());
    if (amount == null || amount <= 0) {
      messenger.showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context, 'invalid_amount'))),
      );
      return;
    }

    final rate = double.tryParse(_rateCtrl.text.trim());
    if (rate == null || rate <= 0) {
      messenger.showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context, 'invalid_rate'))),
      );
      return;
    }

    // Required, not optional. Every movement of money on this ledger has to be
    // backed by the transfer notice for it, and the whole team can open it.
    if (_receipt == null) {
      messenger.showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context, 'receipt_required'))),
      );
      return;
    }

    setState(() => _isSaving = true);
    final id = 't${DateTime.now().millisecondsSinceEpoch}';

    try {
      final bytes = _receipt!.bytes ??
          (_receipt!.path != null ? await File(_receipt!.path!).readAsBytes() : null);
      if (bytes == null) {
        if (mounted) setState(() => _isSaving = false);
        messenger.showSnackBar(
          SnackBar(content: Text(AppLocalizations.of(context, 'file_not_loaded'))),
        );
        return;
      }

      final receiptPath = await ref
          .read(fileStorageServiceProvider)
          .uploadInvoiceAttachment(
            transactionId: id,
            bytes: bytes,
            fileName: _receipt!.name,
          );

      await ref.read(firestoreAdminServiceProvider).addTransaction({
        'id': id,
        'type': _type,
        'amount': amount,
        'currency': _entryCurrency.code,
        'ilsPerEur': rate,
        'description': _descCtrl.text.trim(),
        'date': DateTime.now().toIso8601String(),
        'filePath': receiptPath,
        'fileName': _receipt!.name,
      });

      final actor = ref.read(currentUserStreamProvider).valueOrNull;
      if (actor != null) {
        await ref.read(notificationServiceProvider).transactionAdded(
              actor: actor,
              transactionId: id,
              type: _type,
              amount: amount,
            );
      }

      navigator.pop();
      messenger.showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context, 'transaction_added'))),
      );
    } on FileStorageException catch (e) {
      if (mounted) setState(() => _isSaving = false);
      messenger.showSnackBar(SnackBar(content: Text(e.localized(context))));
    } catch (e) {
      if (mounted) setState(() => _isSaving = false);

      // Firestore's own wording for a rejected write is "The caller does not
      // have permission to execute the specified operation", which tells
      // whoever is typing an amount nothing at all. It means one specific
      // thing here: the ruleset live on the project is older than the one in
      // firestore.rules, which lets both teams write. Say that instead.
      final isDenied = e is FirebaseException && e.code == 'permission-denied';

      messenger.showSnackBar(
        SnackBar(
          duration: Duration(seconds: isDenied ? 8 : 4),
          content: Text(
            isDenied
                ? AppLocalizations.of(context, 'transaction_add_denied')
                : AppLocalizations.of(
                    context, 'transaction_add_failed', {'error': e.toString()}),
          ),
        ),
      );
    }
  }

  /// What the entered amount comes to in the other currency, shown live so a
  /// mistyped rate is obvious before it is saved rather than after.
  String? _conversionHint(StatementCurrency currency) {
    final amount = double.tryParse(_amountCtrl.text.trim());
    final rate = double.tryParse(_rateCtrl.text.trim());
    if (amount == null || rate == null || rate <= 0) return null;

    final money = Money(amount: amount, currency: currency, ilsPerEur: rate);
    return currency == StatementCurrency.ils
        ? money.formattedEur
        : money.formattedIls;
  }

  @override
  Widget build(BuildContext context) {
    // Gaza records in shekels, the Netherlands in euro. Opening on the wrong
    // one is a mistake waiting to be made every single time.
    final team = ref.watch(currentUserStreamProvider).valueOrNull?.team;
    final currency = _currency ??
        (team == null ? StatementCurrency.ils : StatementCurrency.forTeam(team));
    final hint = _conversionHint(currency);

    return AlertDialog(
      title: Text(AppLocalizations.of(context, 'add_financial')),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            DropdownButtonFormField<String>(
              initialValue: _type,
              items: [
                DropdownMenuItem(value: 'income', child: Text(AppLocalizations.of(context, 'income_label'))),
                DropdownMenuItem(value: 'expense', child: Text(AppLocalizations.of(context, 'expense_label'))),
              ],
              onChanged: (v) => setState(() => _type = v ?? 'income'),
              decoration: InputDecoration(labelText: AppLocalizations.of(context, 'type_label')),
            ),
            const SizedBox(height: AppSpacing.md),
            Row(
              children: [
                Expanded(
                  flex: 3,
                  child: TextField(
                    controller: _amountCtrl,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    onChanged: (_) => setState(() {}),
                    decoration: InputDecoration(
                      labelText: AppLocalizations.of(context, 'amount_label'),
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  flex: 2,
                  child: DropdownButtonFormField<StatementCurrency>(
                    initialValue: currency,
                    items: [
                      for (final currency in StatementCurrency.values)
                        DropdownMenuItem(
                          value: currency,
                          child: Text('${currency.symbol} ${currency.code}'),
                        ),
                    ],
                    onChanged: (v) => setState(() => _currency = v ?? currency),
                    decoration: InputDecoration(
                      labelText: AppLocalizations.of(context, 'currency_label'),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            TextField(
              controller: _rateCtrl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                labelText: AppLocalizations.of(context, 'exchange_rate_label'),
                helperText: AppLocalizations.of(context, 'exchange_rate_help'),
                helperMaxLines: 2,
              ),
            ),
            if (hint != null)
              Padding(
                padding: const EdgeInsets.only(top: AppSpacing.sm),
                child: Row(
                  children: [
                    const Icon(Icons.swap_horiz, size: 16, color: AppColors.brand),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        AppLocalizations.of(context, 'equals_value', {'value': hint}),
                        style: Theme.of(context).textTheme.bodySmall
                            ?.copyWith(color: AppColors.brand),
                      ),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: AppSpacing.md),
            TextField(
              controller: _descCtrl,
              decoration: InputDecoration(
                labelText: AppLocalizations.of(context, 'description_label'),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            _ReceiptField(
              receipt: _receipt,
              enabled: !_isSaving,
              onPick: _pickReceipt,
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
              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
              : Text(AppLocalizations.of(context, 'save')),
        ),
      ],
    );
  }
}

/// The transfer notice picker, which states plainly that it is not optional.
class _ReceiptField extends StatelessWidget {
  const _ReceiptField({
    required this.receipt,
    required this.enabled,
    required this.onPick,
  });

  final PlatformFile? receipt;
  final bool enabled;
  final VoidCallback onPick;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final chosen = receipt != null;
    final color = chosen ? AppColors.success : theme.colorScheme.error;

    return InkWell(
      onTap: enabled ? onPick : null,
      borderRadius: BorderRadius.circular(AppRadius.button),
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppRadius.button),
          border: Border.all(color: color.withOpacity(0.5)),
          color: color.withOpacity(0.07),
        ),
        child: Row(
          children: [
            Icon(
              switch (receipt == null
                  ? null
                  : Attachment.kindOf(receipt!.name)) {
                AttachmentKind.pdf => Icons.picture_as_pdf_outlined,
                AttachmentKind.image => Icons.image_outlined,
                AttachmentKind.other => Icons.check_circle_outline,
                null => Icons.upload_file,
              },
              size: 20,
              color: color,
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    AppLocalizations.of(context, 'transfer_receipt'),
                    style: theme.textTheme.titleSmall?.copyWith(color: color),
                  ),
                  Text(
                    receipt?.name ??
                        AppLocalizations.of(context, 'receipt_required_hint'),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// One financial movement.
///
/// Every row carries the transfer notice that backs it, and anyone on the team
/// can open it — a ledger the team cannot audit is just a list of numbers.
/// Only an admin may remove a row; the rules enforce the same thing
/// server-side, so hiding the action is a convenience, not the boundary.
class _TransactionTile extends ConsumerWidget {
  const _TransactionTile({required this.transaction});

  final Map<String, dynamic> transaction;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isIncome = transaction['type'] == 'income';
    final isAdmin = ref.watch(currentUserStreamProvider).valueOrNull?.isAdmin ?? false;
    final theme = Theme.of(context);
    final color = isIncome ? AppColors.success : AppColors.danger;
    final money = Money.fromTransaction(transaction);
    final receiptPath = transaction['filePath'];

    return GlassCard(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.md,
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.14),
                  borderRadius: BorderRadius.circular(AppRadius.small),
                ),
                child: Icon(
                  isIncome ? Icons.south_west : Icons.north_east,
                  color: color,
                  size: 20,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      transaction['description'] as String? ??
                          transaction['fileName'] as String? ??
                          '',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleSmall,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      Formatters.date(transaction['date']),
                      style: theme.textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  // Both currencies, every row: the shekel figure is what was
                  // spent on the ground, the euro one is what the donors gave.
                  // Euro on screen; the printed statement is the shekel
                  // document. One currency per surface, so nobody has to
                  // work out which of two figures they are looking at.
                  Text(
                    money.signedEur(isIncome: isIncome),
                    style: theme.textTheme.titleSmall?.copyWith(color: color),
                  ),
                ],
              ),
              if (isAdmin)
                IconButton(
                  visualDensity: VisualDensity.compact,
                  icon: Icon(
                    Icons.delete_outline,
                    size: 20,
                    color: theme.colorScheme.onSurface.withOpacity(0.45),
                  ),
                  tooltip: AppLocalizations.of(context, 'delete'),
                  onPressed: () => _confirmAndDelete(context, ref),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          if (receiptPath is String)
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: TextButton.icon(
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  visualDensity: VisualDensity.compact,
                ),
                icon: const Icon(Icons.receipt_long_outlined, size: 16),
                label: Text(AppLocalizations.of(context, 'view_receipt')),
                // Above the shell: a document opened inside it is read with
                // the navigation bar floating across its bottom edge.
                onPressed: () => Navigator.of(context, rootNavigator: true).push(
                  MaterialPageRoute<void>(
                    builder: (_) => AttachmentViewer(
                      storagePath: receiptPath,
                      fileName: transaction['fileName'] as String? ?? '',
                      title: transaction['description'] as String?,
                    ),
                  ),
                ),
              ),
            )
          else
            // Rows written before a notice was required. Flagged rather than
            // left blank, because "no receipt" is itself worth seeing.
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.info_outline,
                        size: 14, color: AppColors.warning),
                    const SizedBox(width: 6),
                    Text(
                      AppLocalizations.of(context, 'no_receipt_on_record'),
                      style: theme.textTheme.labelSmall
                          ?.copyWith(color: AppColors.warning),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _confirmAndDelete(BuildContext context, WidgetRef ref) async {
    final messenger = ScaffoldMessenger.of(context);
    final deletedMessage = AppLocalizations.of(context, 'transaction_deleted');
    final scheme = Theme.of(context).colorScheme;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (confirm) => AlertDialog(
        content: Text(AppLocalizations.of(context, 'delete_transaction_confirm')),
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
      await ref
          .read(firestoreAdminServiceProvider)
          .deleteTransaction(transaction['id'] as String);

      final filePath = transaction['filePath'];
      if (filePath is String) {
        try {
          await ref.read(fileStorageServiceProvider).deleteFile(filePath);
        } on FileStorageException {
          // The ledger entry is gone; a leftover receipt is acceptable.
        }
      }

      messenger.showSnackBar(SnackBar(content: Text(deletedMessage)));
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('$e')));
    }
  }
}

/// Supplies the localisation scope the statement needs while it is rendered
/// off-screen, where there is no MaterialApp above it.
class _StatementHost extends StatelessWidget {
  const _StatementHost({
    required this.range,
    required this.transactions,
    required this.issuedBy,
    required this.images,
  });

  final StatementRange range;
  final List<Map<String, dynamic>> transactions;
  final String issuedBy;
  final StatementImages images;

  @override
  Widget build(BuildContext context) {
    return StatementDocument(
      range: range,
      transactions: transactions,
      issuedBy: issuedBy,
      images: images,
    );
  }
}

/// A small status pill above the ledger: the active date filter, or a note
/// that this user can only read.
class _InfoPill extends StatelessWidget {
  const _InfoPill({required this.icon, required this.label, this.onClear});

  final IconData icon;
  final String label;
  final VoidCallback? onClear;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;

    return Container(
      padding: EdgeInsets.only(
        left: AppSpacing.md,
        right: onClear == null ? AppSpacing.md : AppSpacing.xs,
        top: 6,
        bottom: 6,
      ),
      decoration: BoxDecoration(
        color: AppColors.glassFill(dark),
        borderRadius: BorderRadius.circular(AppRadius.pill),
        border: Border.all(color: AppColors.glassStroke(dark)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: theme.textTheme.bodySmall?.color),
          const SizedBox(width: 6),
          // Flexible, not a bare Text: the read-only notice is a full sentence
          // and is much longer in Dutch than in English.
          Flexible(
            child: Text(
              label,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall,
            ),
          ),
          if (onClear != null)
            IconButton(
              visualDensity: VisualDensity.compact,
              constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
              padding: EdgeInsets.zero,
              iconSize: 16,
              tooltip: AppLocalizations.of(context, 'clear_filter'),
              onPressed: onClear,
              icon: const Icon(Icons.close),
            ),
        ],
      ),
    );
  }
}
