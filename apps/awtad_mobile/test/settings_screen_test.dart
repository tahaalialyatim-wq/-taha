import 'dart:io';

import 'package:awtad_mobile/core/database/database_service.dart';
import 'package:awtad_mobile/core/database/retail_session.dart';
import 'package:awtad_mobile/core/theme/app_theme.dart';
import 'package:awtad_mobile/presentation/screens/settings_screen.dart';
import 'package:awtad_retail/awtad_retail.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late Directory dir;
  late DatabaseService database;
  late RetailSession session;
  final merchant = RetailSession.defaultMerchant;

  setUp(() async {
    dir = Directory.systemTemp.createTempSync('awtad-settings-');
    database = DatabaseService(databasePath: DatabaseService.pathIn(dir.path));
    await database.initialize();
    session = RetailSession(database);
  });

  tearDown(() {
    session.close();
    if (dir.existsSync()) {
      dir.deleteSync(recursive: true);
    }
  });

  Future<void> pumpScreen(WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Directionality(
          textDirection: TextDirection.rtl,
          child: SettingsScreen(
            session: session,
            seed: AppTheme.seeds.first,
            dark: false,
            onDarkChanged: (_) {},
            onSeedChanged: (_) {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  ChoiceChip chip(WidgetTester tester, CurrencyCode code) {
    return tester.widget<ChoiceChip>(
      find.byKey(Key('default-currency-${code.value}')),
    );
  }

  testWidgets('null default leaves no currency selected', (tester) async {
    await pumpScreen(tester);

    expect(chip(tester, CurrencyCode.yemeniRial).selected, isFalse);
    expect(chip(tester, CurrencyCode.saudiRiyal).selected, isFalse);
    expect(chip(tester, CurrencyCode.usDollar).selected, isFalse);
    expect(await session.settings.readDefaultCurrency(merchant), isNull);
  });

  testWidgets('saved default currency is loaded', (tester) async {
    await session.settings.saveDefaultCurrency(
      merchant,
      CurrencyCode.saudiRiyal,
    );
    await pumpScreen(tester);

    expect(chip(tester, CurrencyCode.saudiRiyal).selected, isTrue);
    expect(chip(tester, CurrencyCode.yemeniRial).selected, isFalse);
    expect(chip(tester, CurrencyCode.usDollar).selected, isFalse);
  });

  testWidgets('selecting a currency persists it for the session merchant',
      (tester) async {
    await pumpScreen(tester);

    await tester.tap(find.byKey(const Key('default-currency-USD')));
    await tester.pumpAndSettle();

    expect(chip(tester, CurrencyCode.usDollar).selected, isTrue);
    expect(
      await session.settings.readDefaultCurrency(merchant),
      CurrencyCode.usDollar,
    );
  });

  testWidgets('saved currency survives reopen', (tester) async {
    await pumpScreen(tester);
    await tester.tap(find.byKey(const Key('default-currency-YER')));
    await tester.pumpAndSettle();
    session.close();

    database = DatabaseService(databasePath: DatabaseService.pathIn(dir.path));
    await database.initialize();
    session = RetailSession(database);

    await pumpScreen(tester);

    expect(chip(tester, CurrencyCode.yemeniRial).selected, isTrue);
    expect(
      await session.settings.readDefaultCurrency(merchant),
      CurrencyCode.yemeniRial,
    );
  });

  testWidgets('read failure shows a message and does not select a currency',
      (tester) async {
    session.close();
    await pumpScreen(tester);

    expect(find.byKey(const Key('default-currency-message')), findsOneWidget);
    expect(find.text('تعذر قراءة العملة الافتراضية.'), findsOneWidget);
    expect(chip(tester, CurrencyCode.yemeniRial).selected, isFalse);
    expect(chip(tester, CurrencyCode.saudiRiyal).selected, isFalse);
    expect(chip(tester, CurrencyCode.usDollar).selected, isFalse);
  });

  testWidgets('save failure keeps the previous selection', (tester) async {
    await session.settings.saveDefaultCurrency(
      merchant,
      CurrencyCode.yemeniRial,
    );
    await pumpScreen(tester);
    expect(chip(tester, CurrencyCode.yemeniRial).selected, isTrue);

    session.close();
    await tester.tap(find.byKey(const Key('default-currency-SAR')));
    await tester.pumpAndSettle();

    expect(find.text('تعذر حفظ العملة الافتراضية.'), findsOneWidget);
    expect(chip(tester, CurrencyCode.yemeniRial).selected, isTrue);
    expect(chip(tester, CurrencyCode.saudiRiyal).selected, isFalse);
  });

  testWidgets('invalid stored currency is not overwritten on load',
      (tester) async {
    database.database.execute(
      'INSERT INTO store_settings (merchant_id, default_currency) '
      "VALUES (?, 'XXX');",
      [merchant.value],
    );

    await pumpScreen(tester);

    expect(find.text('تعذر قراءة العملة الافتراضية.'), findsOneWidget);
    expect(chip(tester, CurrencyCode.yemeniRial).selected, isFalse);
    expect(chip(tester, CurrencyCode.saudiRiyal).selected, isFalse);
    expect(chip(tester, CurrencyCode.usDollar).selected, isFalse);

    final rows = database.database.select(
      'SELECT default_currency FROM store_settings WHERE merchant_id = ?;',
      [merchant.value],
    );
    expect(rows.single['default_currency'], 'XXX');
  });
}
