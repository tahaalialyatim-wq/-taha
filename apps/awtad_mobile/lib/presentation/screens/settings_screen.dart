import 'package:awtad_retail/awtad_retail.dart';
import 'package:flutter/material.dart';

import '../../core/database/retail_session.dart';
import '../../core/theme/app_theme.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({
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
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  CurrencyCode? _selected;
  bool _loading = true;
  bool _saving = false;
  String? _message;

  MerchantId get _merchant => RetailSession.defaultMerchant;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final saved = await widget.session.settings.readDefaultCurrency(
        _merchant,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _selected = saved;
        _loading = false;
        _message = null;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _selected = null;
        _loading = false;
        _message = 'تعذر قراءة العملة الافتراضية.';
      });
    }
  }

  Future<void> _select(CurrencyCode code) async {
    if (_saving || _selected == code) {
      return;
    }
    setState(() => _saving = true);
    try {
      await widget.session.settings.saveDefaultCurrency(_merchant, code);
      if (!mounted) {
        return;
      }
      setState(() {
        _selected = code;
        _saving = false;
        _message = null;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _saving = false;
        _message = 'تعذر حفظ العملة الافتراضية.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('الإعدادات')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            'العملة الافتراضية',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: [
              for (final code in CurrencyCode.values)
                ChoiceChip(
                  key: Key('default-currency-${code.value}'),
                  label: Text(code.value),
                  selected: _selected == code,
                  onSelected: (_loading || _saving)
                      ? null
                      : (_) => _select(code),
                ),
            ],
          ),
          if (_message != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                _message!,
                key: const Key('default-currency-message'),
              ),
            ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: _modeCard(
                  icon: Icons.wb_sunny_outlined,
                  label: 'فاتح',
                  selected: !widget.dark,
                  onTap: () => widget.onDarkChanged(false),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _modeCard(
                  icon: Icons.nightlight_round,
                  label: 'داكن',
                  selected: widget.dark,
                  onTap: () => widget.onDarkChanged(true),
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
                  onTap: () => widget.onSeedChanged(color),
                  child: CircleAvatar(
                    backgroundColor: color,
                    child: widget.seed == color
                        ? const Icon(Icons.check, color: Colors.white)
                        : null,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 20),
          const SwitchListTile(
            title: Text('اتجاه النص من اليمين إلى اليسار (RTL)'),
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
