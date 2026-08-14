import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:be_human_app/core/languages/app_localizations.dart';
import 'package:be_human_app/core/services/file_storage_service.dart';
import 'package:be_human_app/features/admin/presentation/providers/admin_providers.dart';
import 'package:be_human_app/features/auth/presentation/providers/auth_provider.dart';
import 'package:be_human_app/features/auth/domain/entities/app_user.dart';

class FinanceScreen extends ConsumerWidget {
  const FinanceScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final finances = ref.watch(financesProvider);
    final transactions = ref.watch(transactionsProvider);

    return Scaffold(
      appBar: AppBar(title: Text(AppLocalizations.of(context, 'financial'))),
      body: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(child: _balanceCard('الرصيد', finances['balance'] ?? 0, Colors.blue)),
                const SizedBox(width: 8),
                Expanded(child: _balanceCard('الوارد', finances['totalIncome'] ?? 0, Colors.green)),
                const SizedBox(width: 8),
                Expanded(child: _balanceCard('الصادر', finances['totalExpense'] ?? 0, Colors.red)),
              ],
            ),
            const SizedBox(height: 12),
            if (!(ref.watch(currentUserStreamProvider).valueOrNull?.hasFinancialAccess ?? true))
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  AppLocalizations.of(context, 'read_only_notice'),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
            Text(AppLocalizations.of(context, 'transactions'), style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Expanded(
              child: transactions.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, s) => Center(child: Text('Error: ${e.toString()}')),
                data: (transactions) => ListView.builder(
                  itemCount: transactions.length,
                  itemBuilder: (context, i) => _TransactionTile(transaction: transactions[i]),
                ),
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: ref.watch(currentUserStreamProvider).when(
        loading: () => null,
        error: (e, s) => null,
        data: (user) => (user != null && user.hasFinancialAccess)
            ? FloatingActionButton(
                onPressed: () => _showAddTransactionDialog(context, ref),
                child: const Icon(Icons.add),
              )
            : null,
      ),
    );
  }

  Widget _balanceCard(String label, double value, Color color) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text('${value.toStringAsFixed(2)}\$', style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 18)),
          ],
        ),
      ),
    );
  }

  void _showAddTransactionDialog(BuildContext context, WidgetRef ref) {
    showDialog<void>(
      context: context,
      builder: (_) => const _AddTransactionDialog(),
    );
  }
}

/// Adds a financial movement, optionally with a scanned invoice.
///
/// The invoice goes to Supabase like proposal PDFs do; the document keeps only
/// its object path, which is what makes it show up in the archive.
class _AddTransactionDialog extends ConsumerStatefulWidget {
  const _AddTransactionDialog();

  @override
  ConsumerState<_AddTransactionDialog> createState() => _AddTransactionDialogState();
}

class _AddTransactionDialogState extends ConsumerState<_AddTransactionDialog> {
  final _amountCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  String _type = 'income';
  PlatformFile? _invoice;
  bool _isSaving = false;

  @override
  void dispose() {
    _amountCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickInvoice() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
      withData: true,
    );
    if (result == null || result.files.isEmpty) return;
    setState(() => _invoice = result.files.first);
  }

  Future<void> _save() async {
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);

    final amount = double.tryParse(_amountCtrl.text);
    if (amount == null || amount <= 0) {
      messenger.showSnackBar(const SnackBar(content: Text('أدخل مبلغاً صحيحاً')));
      return;
    }

    setState(() => _isSaving = true);
    final id = 't${DateTime.now().millisecondsSinceEpoch}';

    try {
      String? invoicePath;
      if (_invoice != null) {
        final bytes = _invoice!.bytes ??
            (_invoice!.path != null ? await File(_invoice!.path!).readAsBytes() : null);
        if (bytes != null) {
          invoicePath = await ref
              .read(fileStorageServiceProvider)
              .uploadInvoicePdf(transactionId: id, bytes: bytes);
        }
      }

      await ref.read(firestoreAdminServiceProvider).addTransaction({
        'id': id,
        'type': _type,
        'amount': amount,
        'description': _descCtrl.text,
        'date': DateTime.now().toIso8601String(),
        if (invoicePath != null) 'filePath': invoicePath,
        if (_invoice != null) 'fileName': _invoice!.name,
      });

      navigator.pop();
      messenger.showSnackBar(
        const SnackBar(content: Text('تم إضافة الحركة المالية بنجاح')),
      );
    } on FileStorageException catch (e) {
      if (mounted) setState(() => _isSaving = false);
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
    } catch (e) {
      if (mounted) setState(() => _isSaving = false);
      messenger.showSnackBar(
        SnackBar(content: Text('فشل إضافة الحركة المالية: ${e.toString()}')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(AppLocalizations.of(context, 'add_financial')),
      content: Column(
        mainAxisSize: MainAxisSize.min,
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
          TextField(
            controller: _amountCtrl,
            decoration: InputDecoration(labelText: AppLocalizations.of(context, 'amount_label')),
            keyboardType: TextInputType.number,
          ),
          TextField(
            controller: _descCtrl,
            decoration: InputDecoration(labelText: AppLocalizations.of(context, 'description_label')),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Text(
                  _invoice?.name ?? AppLocalizations.of(context, 'no_file'),
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
              TextButton.icon(
                onPressed: _isSaving ? null : _pickInvoice,
                icon: const Icon(Icons.attach_file, size: 18),
                label: Text(AppLocalizations.of(context, 'archive_invoice')),
              ),
            ],
          ),
        ],
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

/// One financial movement. Only an admin may remove it — the rules enforce the
/// same thing server-side, so hiding the action is a convenience, not the
/// boundary.
class _TransactionTile extends ConsumerWidget {
  const _TransactionTile({required this.transaction});

  final Map<String, dynamic> transaction;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isIncome = transaction['type'] == 'income';
    final isAdmin = ref.watch(currentUserStreamProvider).valueOrNull?.isAdmin ?? false;
    final scheme = Theme.of(context).colorScheme;

    return ListTile(
      leading: CircleAvatar(
        backgroundColor: isIncome ? Colors.green : Colors.red,
        child: Icon(
          isIncome ? Icons.arrow_downward : Icons.arrow_upward,
          color: Colors.white,
        ),
      ),
      title: Text(transaction['description'] as String? ??
          transaction['fileName'] as String? ??
          ''),
      subtitle: Text('${transaction['amount'] ?? 0} — ${transaction['date'] ?? ''}'),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(isIncome ? '+${transaction['amount']}' : '-${transaction['amount']}'),
          if (isAdmin)
            IconButton(
              icon: Icon(Icons.delete_outline, color: scheme.error),
              tooltip: AppLocalizations.of(context, 'delete'),
              onPressed: () => _confirmAndDelete(context, ref),
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
          // The ledger entry is gone; a leftover invoice file is acceptable.
        }
      }

      messenger.showSnackBar(SnackBar(content: Text(deletedMessage)));
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('$e')));
    }
  }
}
