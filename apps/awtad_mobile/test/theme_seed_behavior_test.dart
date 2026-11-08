import 'package:awtad_mobile/core/database/retail_session.dart';
import 'package:awtad_mobile/core/theme/app_theme.dart';
import 'package:awtad_mobile/presentation/screens/settings_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'phase1_fakes.dart';

void main() {
  test('supported seeds stay five and brand is 0xFF0B5C4D', () {
    expect(AppTheme.brand, const Color(0xFF0B5C4D));
    expect(AppTheme.seeds, hasLength(5));
    expect(AppTheme.seeds.first, AppTheme.brand);
    expect(AppTheme.light(AppTheme.brand).useMaterial3, isTrue);
    expect(AppTheme.dark(AppTheme.brand).useMaterial3, isTrue);
    expect(AppTheme.light(AppTheme.brand).colorScheme.primary, AppTheme.brand);
  });

  testWidgets('seed chip applies supported color and keeps language disabled',
      (tester) async {
    final session = sessionWithoutSqlite();
    await tester.pumpWidget(_ThemeHost(session: session));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('theme-seed-0')), findsOneWidget);
    expect(find.byKey(const Key('theme-seed-4')), findsOneWidget);
    expect(find.text('العربية'), findsOneWidget);
    expect(
      tester.widget<SwitchListTile>(find.byType(SwitchListTile)).onChanged,
      isNull,
    );

    var ctx = tester.element(find.byType(SettingsScreen));
    expect(Theme.of(ctx).colorScheme.primary, AppTheme.brand);
    expect(Theme.of(ctx).useMaterial3, isTrue);

    await tester.tap(find.byKey(const Key('theme-seed-1')));
    await tester.pumpAndSettle();

    ctx = tester.element(find.byType(SettingsScreen));
    expect(Theme.of(ctx).colorScheme.primary, AppTheme.seeds[1]);
    expect(Theme.of(ctx).appBarTheme.backgroundColor, AppTheme.seeds[1]);
    expect(find.text('العربية'), findsOneWidget);
  });
}

class _ThemeHost extends StatefulWidget {
  const _ThemeHost({required this.session});

  final RetailSession session;

  @override
  State<_ThemeHost> createState() => _ThemeHostState();
}

class _ThemeHostState extends State<_ThemeHost> {
  Color _seed = AppTheme.brand;
  bool _dark = false;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      theme: AppTheme.light(_seed),
      darkTheme: AppTheme.dark(_seed),
      themeMode: _dark ? ThemeMode.dark : ThemeMode.light,
      home: SettingsScreen(
        session: widget.session,
        seed: _seed,
        dark: _dark,
        onDarkChanged: (value) => setState(() => _dark = value),
        onSeedChanged: (value) => setState(() => _seed = value),
      ),
    );
  }
}
