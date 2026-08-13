import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:be_human_app/features/admin/presentation/providers/admin_providers.dart';

import 'package:be_human_app/core/languages/app_localizations.dart';

class ArchiveScreen extends ConsumerWidget {
  const ArchiveScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final proposals = ref.watch(proposalsProvider);
    final transactions = ref.watch(transactionsProvider);

    final items = <Map<String, String>>[];

    for (var p in proposals.value ?? []) {
      if (p['fileName'] != null) {
        items.add(
            {'fileName': p['fileName'], 'type': 'PDF', 'source': 'مقترحات'});
      }
    }

    for (var t in transactions.value ?? []) {
      if (t['fileName'] != null) {
        items.add(
            {'fileName': t['fileName'], 'type': 'فاتورة', 'source': 'مالية'});
      }
    }

    return Scaffold(
      appBar: AppBar(title: Text(AppLocalizations.of(context, 'archive'))),
      body: ListView.builder(
        padding: const EdgeInsets.all(12),
        itemCount: items.length,
        itemBuilder: (context, i) {
          final it = items[i];
          return Card(
            child: ListTile(
              title: Text(it['fileName'] ?? ''),
              subtitle: Text('${it['type']} • ${it['source']}'),
            ),
          );
        },
      ),
    );
  }
}
