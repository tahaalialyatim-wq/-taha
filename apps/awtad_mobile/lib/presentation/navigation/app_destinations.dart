import 'package:flutter/material.dart';

enum AppDestination {
  home('home', 'الرئيسية', Icons.home_outlined),
  sales('sales', 'المبيعات', Icons.point_of_sale_outlined),
  inventory('inventory', 'المخزون', Icons.inventory_2_outlined),
  customers('customers', 'العملاء', Icons.groups_outlined),
  debts('debts', 'الديون', Icons.account_balance_wallet_outlined),
  reports('reports', 'التقارير', Icons.bar_chart_outlined);

  const AppDestination(this.id, this.labelAr, this.icon);

  final String id;
  final String labelAr;
  final IconData icon;

  static const List<AppDestination> primary = <AppDestination>[
    home,
    sales,
    inventory,
    customers,
    debts,
    reports,
  ];
}
