import 'package:awtad_retail/awtad_retail.dart';
import 'package:flutter/material.dart';

import '../../core/database/retail_session.dart';

class ReportsScreen extends StatelessWidget {
  const ReportsScreen({super.key, required this.session});

  final RetailSession session;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_Report>(
      future: _load(),
      builder: (context, snapshot) {
        final report = snapshot.data;
        final totals = report?.salesTotals ?? _emptyTotals();
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const Text(
              'ملخصات المبيعات والأرباح وحركة المخزون',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            _card(
              'عدد المبيعات',
              '${report?.salesCount ?? 0}',
              key: const Key('sales-count'),
            ),
            for (final code in CurrencyCode.values)
              _card(
                'إجمالي المبيعات ${code.value}',
                '${totals[code] ?? 0} ${code.value}',
                key: Key('sales-total-${code.value}'),
              ),
            _card(
              'أصناف المخزون',
              '${report?.stockCount ?? 0}',
              key: const Key('stock-count'),
            ),
            _card(
              'كمية المخزون',
              '${report?.stockQty ?? 0}',
              key: const Key('stock-qty'),
            ),
          ],
        );
      },
    );
  }

  static Map<CurrencyCode, int> _emptyTotals() {
    return <CurrencyCode, int>{
      for (final code in CurrencyCode.values) code: 0,
    };
  }

  Future<_Report> _load() async {
    final merchant = RetailSession.defaultMerchant;
    final sales = await session.sales.getAll(merchant);
    final stock = await session.inventory.getAll(merchant);
    final totals = _emptyTotals();
    for (final sale in sales) {
      totals[sale.currency] =
          (totals[sale.currency] ?? 0) + sale.total.minorUnits;
    }
    var qty = 0;
    for (final item in stock) {
      qty += item.quantity.wholeUnits;
    }
    return _Report(
      salesCount: sales.length,
      salesTotals: totals,
      stockCount: stock.length,
      stockQty: qty,
    );
  }

  Widget _card(String label, String value, {required Key key}) {
    return Card(
      child: ListTile(
        title: Text(label),
        trailing: Text(value, key: key),
      ),
    );
  }
}

class _Report {
  const _Report({
    required this.salesCount,
    required this.salesTotals,
    required this.stockCount,
    required this.stockQty,
  });

  final int salesCount;
  final Map<CurrencyCode, int> salesTotals;
  final int stockCount;
  final int stockQty;
}
