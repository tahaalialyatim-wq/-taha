import 'package:flutter/material.dart';

import '../../core/database/retail_session.dart';
import '../../core/theme/app_theme.dart';
import '../screens/customers_screen.dart';
import '../screens/debts_screen.dart';
import '../screens/home_screen.dart';
import '../screens/inventory_screen.dart';
import '../screens/reports_screen.dart';
import '../screens/sales_screen.dart';
import '../screens/settings_screen.dart';
import 'app_destinations.dart';

class AppShell extends StatefulWidget {
  const AppShell({
    super.key,
    required this.session,
    required this.seed,
    required this.dark,
    required this.onDarkChanged,
    required this.onSeedChanged,
  });

  final RetailSession session;
  final Color seed;
  final bool dark;
  final ValueChanged<bool> onDarkChanged;
  final ValueChanged<Color> onSeedChanged;

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  AppDestination _current = AppDestination.home;
  bool _drawerOpen = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('الأوتاد للمبيعات'),
        leading: IconButton(
          icon: const Icon(Icons.menu),
          onPressed: () => setState(() => _drawerOpen = !_drawerOpen),
        ),
      ),
      body: Row(
        children: [
          if (_drawerOpen)
            Material(
              elevation: 4,
              child: SizedBox(
                width: 240,
                child: _SideMenu(
                  current: _current,
                  onSelect: (destination) {
                    setState(() {
                      _current = destination;
                      _drawerOpen = false;
                    });
                  },
                  onSettings: () {
                    setState(() => _drawerOpen = false);
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => SettingsScreen(
                          session: widget.session,
                          seed: widget.seed,
                          dark: widget.dark,
                          onDarkChanged: widget.onDarkChanged,
                          onSeedChanged: widget.onSeedChanged,
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          Expanded(child: _page()),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: AppDestination.primary.indexOf(_current),
        onDestinationSelected: (index) {
          setState(() => _current = AppDestination.primary[index]);
        },
        destinations: [
          for (final destination in AppDestination.primary)
            NavigationDestination(
              icon: Icon(destination.icon),
              label: destination.labelAr,
            ),
        ],
      ),
    );
  }

  Widget _page() {
    switch (_current) {
      case AppDestination.home:
        return HomeScreen(
          session: widget.session,
          onOpen: (destination) => setState(() => _current = destination),
        );
      case AppDestination.sales:
        return SalesScreen(session: widget.session);
      case AppDestination.inventory:
        return InventoryScreen(session: widget.session);
      case AppDestination.customers:
        return CustomersScreen(session: widget.session);
      case AppDestination.debts:
        return DebtsScreen(session: widget.session);
      case AppDestination.reports:
        return ReportsScreen(session: widget.session);
    }
  }
}

class _SideMenu extends StatelessWidget {
  const _SideMenu({
    required this.current,
    required this.onSelect,
    required this.onSettings,
  });

  final AppDestination current;
  final ValueChanged<AppDestination> onSelect;
  final VoidCallback onSettings;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: double.infinity,
          color: AppTheme.brand,
          padding: const EdgeInsets.fromLTRB(16, 32, 16, 16),
          child: const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'الأوتاد للمبيعات',
                style: TextStyle(color: Colors.white, fontSize: 18),
              ),
              Text('v1.0.0', style: TextStyle(color: Colors.white70)),
            ],
          ),
        ),
        for (final destination in AppDestination.primary)
          ListTile(
            selected: destination == current,
            leading: Icon(destination.icon),
            title: Text(destination.labelAr),
            onTap: () => onSelect(destination),
          ),
        const Divider(),
        ListTile(
          leading: const Icon(Icons.settings_outlined),
          title: const Text('الإعدادات'),
          onTap: onSettings,
        ),
        ListTile(
          leading: const Icon(Icons.info_outline),
          title: const Text('حول التطبيق'),
          onTap: () {
            showDialog<void>(
              context: context,
              builder: (context) => const AlertDialog(
                title: Text('الأوتاد للمبيعات'),
                content: Text(
                  'AWTAD RETAIL\nتطبيق أندرويد لإدارة المبيعات والمخزون والعملاء.',
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}
