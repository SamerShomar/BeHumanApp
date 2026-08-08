import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:be_human_app/core/languages/app_localizations.dart';
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
            Text(AppLocalizations.of(context, 'transactions'), style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Expanded(
              child: transactions.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, s) => Center(child: Text('Error: ${e.toString()}')),
                data: (transactions) => ListView.builder(
                  itemCount: transactions.length,
                  itemBuilder: (context, i) {
                    final t = transactions[i];
                    final isIncome = t['type'] == 'income';
                    return ListTile(
                      leading: CircleAvatar(backgroundColor: isIncome ? Colors.green : Colors.red, child: Icon(isIncome ? Icons.arrow_downward : Icons.arrow_upward, color: Colors.white)),
                      title: Text(t['description'] ?? t['fileName'] ?? ''),
                      subtitle: Text('${t['amount'] ?? 0} — ${t['date'] ?? ''}'),
                      trailing: Text(isIncome ? '+${t['amount']}' : '-${t['amount']}'),
                    );
                  },
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
    final amountCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    var type = 'income';

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('إضافة حركة مالية'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DropdownButtonFormField<String>(
              initialValue: type,
              items: [
                DropdownMenuItem(value: 'income', child: Text(AppLocalizations.of(context, 'income_label'))),
                DropdownMenuItem(value: 'expense', child: Text(AppLocalizations.of(context, 'expense_label'))),
              ],
              onChanged: (v) => type = v ?? 'income',
              decoration: const InputDecoration(labelText: 'النوع'),
            ),
            TextField(controller: amountCtrl, decoration: const InputDecoration(labelText: 'المبلغ'), keyboardType: TextInputType.number),
            TextField(controller: descCtrl, decoration: const InputDecoration(labelText: 'الوصف')),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('إلغاء')),
          ElevatedButton(
            onPressed: () async {
              final amount = double.tryParse(amountCtrl.text) ?? 0.0;
              final id = 't${DateTime.now().millisecondsSinceEpoch}';
              final tx = {
                'id': id,
                'type': type,
                'amount': amount,
                'description': descCtrl.text,
                'date': DateTime.now().toIso8601String(),
              };

              try {
                final adminService = ref.read(firestoreAdminServiceProvider);
                await adminService.addTransaction(tx);
                Navigator.of(ctx).pop();
                ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(content: Text('تم إضافة الحركة المالية بنجاح')));
              } catch (e) {
                ScaffoldMessenger.of(ctx).showSnackBar(
                  SnackBar(content: Text('فشل إضافة الحركة المالية: ${e.toString()}')),
                );
              }
            },
            child: Text(AppLocalizations.of(context, 'save')),
          ),
        ],
      ),
    );
  }
}
