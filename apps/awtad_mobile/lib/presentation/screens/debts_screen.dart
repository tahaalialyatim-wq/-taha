import 'package:awtad_retail/awtad_retail.dart';
import 'package:flutter/material.dart';

import '../../core/database/retail_session.dart';

class DebtsScreen extends StatefulWidget {
  const DebtsScreen({super.key, required this.session});

  final RetailSession session;

  @override
  State<DebtsScreen> createState() => _DebtsScreenState();
}

class _DebtsScreenState extends State<DebtsScreen> {
  List<_DebtRow> _rows = const <_DebtRow>[];

  @override
  void initState() {
    super.initState();
    _reload();
  }

  Future<void> _reload() async {
    final merchant = RetailSession.defaultMerchant;
    final customers = await widget.session.customers.getAll(merchant);
    final rows = <_DebtRow>[];
    for (final customer in customers) {
      final balance = await widget.session.ledger.getBalance(
        merchant,
        customer.id,
        CurrencyCode.saudiRiyal,
      );
      final entries = await widget.session.ledger.getEntries(
        merchant,
        customer.id,
      );
      rows.add(
        _DebtRow(
          name: customer.name,
          balance: balance.balanceMinorUnits,
          entries: entries.length,
        ),
      );
    }
    setState(() => _rows = rows);
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text(
          'سجلات الديون',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        if (_rows.isEmpty) const Text('لا توجد حسابات بعد.'),
        for (final row in _rows)
          Card(
            child: ListTile(
              title: Text(row.name),
              subtitle: Text('قيود: ${row.entries}'),
              trailing: Text('${row.balance} هللة'),
            ),
          ),
      ],
    );
  }
}

class _DebtRow {
  const _DebtRow({
    required this.name,
    required this.balance,
    required this.entries,
  });

  final String name;
  final int balance;
  final int entries;
}
