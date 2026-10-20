import 'dart:io';

import 'package:awtad_mobile/core/database/database_service.dart';
import 'package:awtad_mobile/core/database/retail_session.dart';
import 'package:awtad_mobile/presentation/screens/inventory_screen.dart';
import 'package:awtad_retail/awtad_retail.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late Directory dir;
  late DatabaseService database;
  late RetailSession session;
  final merchant = RetailSession.defaultMerchant;

  setUp(() async {
    dir = Directory.systemTemp.createTempSync('awtad-inv-');
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
          child: Scaffold(body: InventoryScreen(session: session)),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> addProduct(
    WidgetTester tester, {
    required String productId,
    String? selling,
    String? purchase,
  }) async {
    await tester.enterText(find.byKey(const Key('product-field')), productId);
    if (selling != null) {
      await tester.enterText(
        find.byKey(const Key('selling-price-field')),
        selling,
      );
    }
    if (purchase != null) {
      await tester.enterText(
        find.byKey(const Key('purchase-price-field')),
        purchase,
      );
    }
    await tester.tap(find.byKey(const Key('save-button')));
    await tester.pumpAndSettle();
  }

  ChoiceChip chip(WidgetTester tester, String prefix, CurrencyCode code) {
    return tester.widget<ChoiceChip>(
      find.byKey(Key('$prefix-currency-${code.value}')),
    );
  }

  testWidgets('saved default currency prefills a new item', (tester) async {
    await session.settings.saveDefaultCurrency(
      merchant,
      CurrencyCode.yemeniRial,
    );
    await pumpScreen(tester);

    expect(chip(tester, 'selling', CurrencyCode.yemeniRial).selected, isTrue);
    expect(chip(tester, 'purchase', CurrencyCode.yemeniRial).selected, isTrue);

    await addProduct(tester, productId: 'p1', selling: '1500');

    final item = await session.inventoryService.findByProduct(
      merchant,
      ProductId('p1'),
    );
    expect(item, isNotNull);
    expect(item!.sellingPrice!.currency, CurrencyCode.yemeniRial);
    expect(item.sellingPrice!.minorUnits, 1500);
  });

  testWidgets('explicit currency selection is persisted per price field',
      (tester) async {
    await pumpScreen(tester);

    await tester.tap(find.byKey(const Key('selling-currency-SAR')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('purchase-currency-USD')));
    await tester.pumpAndSettle();

    await addProduct(
      tester,
      productId: 'p2',
      selling: '200',
      purchase: '90',
    );

    final item = await session.inventoryService.findByProduct(
      merchant,
      ProductId('p2'),
    );
    expect(item!.sellingPrice!.currency, CurrencyCode.saudiRiyal);
    expect(item.sellingPrice!.minorUnits, 200);
    expect(item.purchasePrice!.currency, CurrencyCode.usDollar);
    expect(item.purchasePrice!.minorUnits, 90);
  });

  testWidgets('missing default requires explicit selection before saving',
      (tester) async {
    await pumpScreen(tester);
    expect(await session.settings.readDefaultCurrency(merchant), isNull);

    await addProduct(tester, productId: 'p3', selling: '50');

    expect(find.text('اختر عملة سعر البيع قبل الحفظ.'), findsOneWidget);
    expect(
      await session.inventoryService.findByProduct(merchant, ProductId('p3')),
      isNull,
    );
  });

  testWidgets('editing quantity preserves stored currencies', (tester) async {
    await session.inventoryService.addProduct(
      merchant,
      ProductId('p4'),
      quantity: Quantity.whole(5),
      sellingPrice: const Money(
        currency: CurrencyCode.yemeniRial,
        minorUnits: 1000,
      ),
      purchasePrice: const Money(
        currency: CurrencyCode.saudiRiyal,
        minorUnits: 700,
      ),
    );
    await session.settings.saveDefaultCurrency(
      merchant,
      CurrencyCode.usDollar,
    );
    await pumpScreen(tester);

    await tester.tap(find.byKey(const Key('edit-p4')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('qty-field')), '9');
    await tester.tap(find.byKey(const Key('save-button')));
    await tester.pumpAndSettle();

    final item = await session.inventoryService.findByProduct(
      merchant,
      ProductId('p4'),
    );
    expect(item!.quantity, Quantity.whole(9));
    expect(item.sellingPrice!.currency, CurrencyCode.yemeniRial);
    expect(item.sellingPrice!.minorUnits, 1000);
    expect(item.purchasePrice!.currency, CurrencyCode.saudiRiyal);
    expect(item.purchasePrice!.minorUnits, 700);
  });

  testWidgets('currency labels match the selection and drop "هللات"',
      (tester) async {
    await session.settings.saveDefaultCurrency(
      merchant,
      CurrencyCode.usDollar,
    );
    await pumpScreen(tester);

    expect(find.text('سعر البيع (وحدات صغرى USD)'), findsOneWidget);
    expect(find.text('سعر الشراء (وحدات صغرى USD)'), findsOneWidget);
    expect(find.textContaining('هللات'), findsNothing);
  });

  testWidgets('negative prices are rejected before saving', (tester) async {
    await pumpScreen(tester);

    await addProduct(tester, productId: 'negative-selling', selling: '-5');
    expect(find.text('لا يُسمح بسعر بيع سالب.'), findsOneWidget);
    expect(
      await session.inventoryService.findByProduct(
        merchant,
        ProductId('negative-selling'),
      ),
      isNull,
    );

    await tester.enterText(
      find.byKey(const Key('selling-price-field')),
      '',
    );
    await addProduct(tester, productId: 'negative-purchase', purchase: '-1');
    expect(find.text('لا يُسمح بسعر شراء سالب.'), findsOneWidget);
    expect(
      await session.inventoryService.findByProduct(
        merchant,
        ProductId('negative-purchase'),
      ),
      isNull,
    );
  });

  testWidgets('existing inventory behavior adds and lists an item',
      (tester) async {
    await session.settings.saveDefaultCurrency(
      merchant,
      CurrencyCode.saudiRiyal,
    );
    await pumpScreen(tester);

    await addProduct(tester, productId: 'p6', selling: '300');

    expect(find.text('تمت إضافة المنتج.'), findsOneWidget);
    expect(find.textContaining('بيع 300 SAR'), findsOneWidget);
    expect((await session.inventoryService.getAll(merchant)), hasLength(1));
  });
}
