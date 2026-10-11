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
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const Text(
              'ملخصات المبيعات والأرباح وحركة المخزون',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            _card('عدد المبيعات', '${report?.salesCount ?? 0}'),
            _card('إجمالي المبيعات (هللة)', '${report?.salesTotal ?? 0}'),
            _card('أصناف المخزون', '${report?.stockCount ?? 0}'),
            _card('كمية المخزون', '${report?.stockQty ?? 0}'),
          ],
        );
      },
    );
  }

  Future<_Report> _load() async {
    final merchant = RetailSession.defaultMerchant;
    final sales = await session.sales.getAll(merchant);
    final stock = await session.inventory.getAll(merchant);
    var total = 0;
    var qty = 0;
    for (final sale in sales) {
      total += sale.total.minorUnits;
    }
    for (final item in stock) {
      qty += item.quantity.wholeUnits;
    }
    return _Report(
      salesCount: sales.length,
      salesTotal: total,
      stockCount: stock.length,
      stockQty: qty,
    );
  }

  Widget _card(String label, String value) {
    return Card(
      child: ListTile(
        title: Text(label),
        trailing: Text(value),
      ),
    );
  }
}

class _Report {
  const _Report({
    required this.salesCount,
    required this.salesTotal,
    required this.stockCount,
    required this.stockQty,
  });

  final int salesCount;
  final int salesTotal;
  final int stockCount;
  final int stockQty;
}
