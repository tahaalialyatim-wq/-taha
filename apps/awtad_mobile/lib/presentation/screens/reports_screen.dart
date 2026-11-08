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
        final totals = report?.totals ?? _emptyTotals();
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
              _currencyCard(code, totals[code] ?? _CurrencyTotals.empty()),
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

  static Map<CurrencyCode, _CurrencyTotals> _emptyTotals() {
    return <CurrencyCode, _CurrencyTotals>{
      for (final code in CurrencyCode.values) code: _CurrencyTotals.empty(),
    };
  }

  Future<_Report> _load() async {
    final merchant = RetailSession.defaultMerchant;
    final sales = await session.sales.getAll(merchant);
    final stock = await session.inventory.getAll(merchant);
    final totals = _emptyTotals();
    for (final sale in sales) {
      for (final line in sale.lines) {
        final currency = line.unitSellingPrice.currency;
        final bucket = totals[currency] ??= _CurrencyTotals.empty();
        bucket.revenueMinorUnits += line.lineTotal.minorUnits;
        final cost = line.lineCost;
        final profit = line.grossProfit;
        if (cost == null || profit == null) {
          bucket.hasUnknownCost = true;
        } else {
          bucket.hasKnownCost = true;
          bucket.costMinorUnits += cost.minorUnits;
          bucket.grossProfitMinorUnits += profit.minorUnits;
        }
      }
    }
    var qty = 0;
    for (final item in stock) {
      qty += item.quantity.wholeUnits;
    }
    return _Report(
      salesCount: sales.length,
      totals: totals,
      stockCount: stock.length,
      stockQty: qty,
    );
  }

  Widget _currencyCard(CurrencyCode code, _CurrencyTotals totals) {
    final unknown = totals.hasUnknownCost;
    return Card(
      key: Key('currency-card-${code.value}'),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'إجمالي المبيعات ${code.value}',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            _row(
              'المبيعات',
              '${totals.revenueMinorUnits} ${code.value}',
              key: Key('sales-total-${code.value}'),
            ),
            _row(
              'تكلفة المبيعات',
              _amountLabel(code, totals.costMinorUnits, unknown, totals.hasKnownCost),
              key: Key('cost-total-${code.value}'),
            ),
            _row(
              'الربح الإجمالي',
              _amountLabel(
                code,
                totals.grossProfitMinorUnits,
                unknown,
                totals.hasKnownCost,
              ),
              key: Key('profit-${code.value}'),
            ),
            if (unknown)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  'تغطية التكلفة غير مكتملة: بعض الفواتير بلا تكلفة معروفة.',
                  key: Key('coverage-${code.value}'),
                  style: const TextStyle(fontSize: 12),
                ),
              ),
          ],
        ),
      ),
    );
  }

  String _amountLabel(
    CurrencyCode code,
    int minorUnits,
    bool unknown,
    bool hasKnownCost,
  ) {
    if (unknown && !hasKnownCost) {
      return '—';
    }
    if (unknown) {
      return '$minorUnits ${code.value} (جزئي)';
    }
    return '$minorUnits ${code.value}';
  }

  Widget _row(String label, String value, {required Key key}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: Text(label, style: const TextStyle(fontSize: 13))),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              value,
              key: key,
              textAlign: TextAlign.end,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
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
    required this.totals,
    required this.stockCount,
    required this.stockQty,
  });

  final int salesCount;
  final Map<CurrencyCode, _CurrencyTotals> totals;
  final int stockCount;
  final int stockQty;
}

class _CurrencyTotals {
  _CurrencyTotals({
    required this.revenueMinorUnits,
    required this.costMinorUnits,
    required this.grossProfitMinorUnits,
    required this.hasKnownCost,
    required this.hasUnknownCost,
  });

  factory _CurrencyTotals.empty() => _CurrencyTotals(
        revenueMinorUnits: 0,
        costMinorUnits: 0,
        grossProfitMinorUnits: 0,
        hasKnownCost: false,
        hasUnknownCost: false,
      );

  int revenueMinorUnits;
  int costMinorUnits;
  int grossProfitMinorUnits;
  bool hasKnownCost;
  bool hasUnknownCost;
}
