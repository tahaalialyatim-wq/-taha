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
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const Text(
              'موجز اليوم',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                _metric('الربح التقريبي', data?.profitLabel ?? '—'),
                const SizedBox(width: 8),
                _metric('عدد الفواتير', '${data?.invoiceCount ?? 0}'),
                const SizedBox(width: 8),
                _metric('المبيعات', data?.salesLabel ?? '—'),
              ],
            ),
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
    var total = 0;
    var profit = 0;
    for (final sale in sales) {
      total += sale.total.minorUnits;
      for (final line in sale.lines) {
        profit += line.lineTotal.minorUnits;
      }
    }
    return _HomeSnapshot(
      invoiceCount: sales.length,
      salesLabel: _format(total),
      profitLabel: _format(profit),
    );
  }

  String _format(int minor) => '${(minor / 100).toStringAsFixed(0)} ر.س';

  Widget _metric(String label, String value) {
    return Expanded(
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            children: [
              Text(label, style: const TextStyle(fontSize: 12)),
              const SizedBox(height: 6),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
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
    required this.salesLabel,
    required this.profitLabel,
  });

  final int invoiceCount;
  final String salesLabel;
  final String profitLabel;
}
