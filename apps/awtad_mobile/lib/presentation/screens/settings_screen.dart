import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({
    super.key,
    required this.seed,
    required this.dark,
    required this.onDarkChanged,
    required this.onSeedChanged,
  });

  final Color seed;
  final bool dark;
  final ValueChanged<bool> onDarkChanged;
  final ValueChanged<Color> onSeedChanged;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('المظهر')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Row(
            children: [
              Expanded(
                child: _modeCard(
                  icon: Icons.wb_sunny_outlined,
                  label: 'فاتح',
                  selected: !dark,
                  onTap: () => onDarkChanged(false),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _modeCard(
                  icon: Icons.nightlight_round,
                  label: 'داكن',
                  selected: dark,
                  onTap: () => onDarkChanged(true),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          const Text('اللون الأساسي'),
          const SizedBox(height: 8),
          Wrap(
            spacing: 12,
            children: [
              for (final color in AppTheme.seeds)
                GestureDetector(
                  onTap: () => onSeedChanged(color),
                  child: CircleAvatar(
                    backgroundColor: color,
                    child: seed == color
                        ? const Icon(Icons.check, color: Colors.white)
                        : null,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 20),
          SwitchListTile(
            title: const Text('اتجاه النص من اليمين إلى اليسار (RTL)'),
            value: true,
            onChanged: null,
          ),
          const ListTile(
            title: Text('اللغة'),
            trailing: Text('العربية'),
          ),
        ],
      ),
    );
  }

  Widget _modeCard({
    required IconData icon,
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Card(
        color: selected ? AppTheme.mintSurface : null,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              Icon(icon, size: 32),
              const SizedBox(height: 8),
              Text(label),
            ],
          ),
        ),
      ),
    );
  }
}
