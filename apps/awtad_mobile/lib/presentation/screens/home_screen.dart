import 'package:awtad_retail/awtad_retail.dart';
import 'package:flutter/material.dart';

import '../../core/database/retail_session.dart';
import '../../core/theme/app_theme.dart';
import '../navigation/app_destinations.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({
    super.key,
    required this.session,
    required this.onOpen,
  });

  final RetailSession session;
  final ValueChanged<AppDestination> onOpen;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_HomeSnapshot>(
      future: _load(),
      builder: (context, snapshot) {
        final data = snapshot.data;
        final totals = data?.totals ?? _emptyTotals();
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const Text(
              'ملخص المبيعات',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            const Text('ربح إجمالي — لا يشمل المصروفات'),
            const SizedBox(height: 12),
            _metric(
              'عدد الفواتير',
              '${data?.invoiceCount ?? 0}',
              key: const Key('invoice-count'),
            ),
            const SizedBox(height: 12),
            for (final code in CurrencyCode.values)
              _currencyCard(code, totals[code] ?? _CurrencyTotals.empty()),
            const SizedBox(height: 16),
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 1.35,
              children: [
                _tile('المبيعات', Icons.point_of_sale, AppDestination.sales),
                _tile('المخزون', Icons.inventory_2, AppDestination.inventory),
                _tile('العملاء', Icons.groups, AppDestination.customers),
                _tile(
                  'الديون',
                  Icons.account_balance_wallet,
                  AppDestination.debts,
                ),
                _tile('التقارير', Icons.bar_chart, AppDestination.reports),
                _tile('الرئيسية', Icons.home, AppDestination.home),
              ],
            ),
          ],
        );
      },
    );
  }

  Future<_HomeSnapshot> _load() async {
    final merchant = RetailSession.defaultMerchant;
    final sales = await session.sales.getAll(merchant);
    final totals = _emptyTotals();
    for (final sale in sales) {
      for (final line in sale.lines) {
        final currency = line.unitSellingPrice.currency;
        final bucket = totals[currency] ??= _CurrencyTotals.empty();
        bucket.revenueMinorUnits += line.lineTotal.minorUnits;
        final profit = line.grossProfit;
        if (profit == null) {
          bucket.hasUnknownCost = true;
        } else {
          bucket.hasKnownCost = true;
          bucket.grossProfitMinorUnits += profit.minorUnits;
        }
      }
    }
    return _HomeSnapshot(invoiceCount: sales.length, totals: totals);
  }

  static Map<CurrencyCode, _CurrencyTotals> _emptyTotals() {
    return <CurrencyCode, _CurrencyTotals>{
      for (final code in CurrencyCode.values) code: _CurrencyTotals.empty(),
    };
  }

  Widget _currencyCard(CurrencyCode code, _CurrencyTotals totals) {
    final unknown = totals.hasUnknownCost;
    final String profitLabel;
    if (unknown && !totals.hasKnownCost) {
      profitLabel = '—';
    } else if (unknown) {
      profitLabel = '${totals.grossProfitMinorUnits} ${code.value} (جزئي)';
    } else {
      profitLabel = '${totals.grossProfitMinorUnits} ${code.value}';
    }
    final marginLabel = totals.revenueMinorUnits > 0 && !unknown
        ? GrossProfitMargin.fromMinorUnits(
            revenueMinorUnits: totals.revenueMinorUnits,
            grossProfitMinorUnits: totals.grossProfitMinorUnits,
          ).label
        : '—';

    return Card(
      key: Key('currency-card-${code.value}'),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              code.value,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            _row(
              'المبيعات',
              '${totals.revenueMinorUnits} ${code.value}',
              key: Key('sales-${code.value}'),
            ),
            _row(
              'الربح الإجمالي',
              profitLabel,
              key: Key('profit-${code.value}'),
            ),
            _row(
              'هامش الربح الإجمالي',
              marginLabel,
              key: Key('margin-${code.value}'),
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

  Widget _metric(String label, String value, {required Key key}) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Text(label, style: const TextStyle(fontSize: 12)),
            const SizedBox(height: 6),
            Text(
              value,
              key: key,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _tile(String label, IconData icon, AppDestination destination) {
    return InkWell(
      onTap: () => onOpen(destination),
      child: Card(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircleAvatar(
              backgroundColor: AppTheme.mintSurface,
              child: Icon(icon, color: AppTheme.brand),
            ),
            const SizedBox(height: 8),
            Text(label),
          ],
        ),
      ),
    );
  }
}

class _HomeSnapshot {
  const _HomeSnapshot({
    required this.invoiceCount,
    required this.totals,
  });

  final int invoiceCount;
  final Map<CurrencyCode, _CurrencyTotals> totals;
}

class _CurrencyTotals {
  _CurrencyTotals({
    required this.revenueMinorUnits,
    required this.grossProfitMinorUnits,
    required this.hasKnownCost,
    required this.hasUnknownCost,
  });

  factory _CurrencyTotals.empty() => _CurrencyTotals(
        revenueMinorUnits: 0,
        grossProfitMinorUnits: 0,
        hasKnownCost: false,
        hasUnknownCost: false,
      );

  int revenueMinorUnits;
  int grossProfitMinorUnits;
  bool hasKnownCost;
  bool hasUnknownCost;
}
