import 'package:awtad_retail/awtad_retail.dart';
import 'package:flutter/material.dart';

import '../../core/database/retail_session.dart';
import 'customer_detail_screen.dart';

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
      final balances = <CustomerAccountBalance>[];
      for (final currency in CurrencyCode.values) {
        balances.add(
          await widget.session.ledger.getBalance(
            merchant,
            customer.id,
            currency,
          ),
        );
      }
      final entries = await widget.session.ledger.getEntries(
        merchant,
        customer.id,
      );
      rows.add(
        _DebtRow(
          customer: customer,
          balances: balances,
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
              title: Text(row.customer.name),
              subtitle: Text('قيود: ${row.entries}\n${row.balanceLabel}'),
              isThreeLine: true,
              trailing: const Icon(Icons.chevron_left),
              onTap: () async {
                await Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => CustomerDetailScreen(
                      session: widget.session,
                      customer: row.customer,
                    ),
                  ),
                );
                await _reload();
              },
            ),
          ),
      ],
    );
  }
}

class _DebtRow {
  const _DebtRow({
    required this.customer,
    required this.balances,
    required this.entries,
  });

  final Customer customer;
  final List<CustomerAccountBalance> balances;
  final int entries;

  String get balanceLabel {
    final parts = <String>[];
    for (final balance in balances) {
      if (balance.balanceMinorUnits == 0) {
        continue;
      }
      if (balance.balanceMinorUnits > 0) {
        parts
            .add('عليه ${balance.balanceMinorUnits} ${balance.currency.value}');
      } else {
        parts.add('له ${-balance.balanceMinorUnits} ${balance.currency.value}');
      }
    }
    if (parts.isEmpty) {
      return 'تسوية';
    }
    return parts.join(' · ');
  }
}
