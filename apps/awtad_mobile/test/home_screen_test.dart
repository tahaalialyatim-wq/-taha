import 'dart:io';

import 'package:awtad_mobile/core/database/database_service.dart';
import 'package:awtad_mobile/core/database/retail_session.dart';
import 'package:awtad_mobile/presentation/navigation/app_destinations.dart';
import 'package:awtad_mobile/presentation/screens/home_screen.dart';
import 'package:awtad_retail/awtad_retail.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late Directory dir;
  late DatabaseService database;
  late RetailSession session;
  final merchant = RetailSession.defaultMerchant;
  var saleSequence = 0;

  setUp(() async {
    saleSequence = 0;
    dir = Directory.systemTemp.createTempSync('awtad-home-');
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

  Future<void> addItem(
    String productId, {
    required CurrencyCode currency,
    required int sellingMinorUnits,
    int? costMinorUnits,
    CurrencyCode? costCurrency,
    int quantity = 5,
  }) async {
    await session.inventoryService.addProduct(
      merchant,
      ProductId(productId),
      quantity: Quantity.whole(quantity),
      sellingPrice: Money(
        currency: currency,
        minorUnits: sellingMinorUnits,
      ),
      purchasePrice: costMinorUnits == null
          ? null
          : Money(
              currency: costCurrency ?? currency,
              minorUnits: costMinorUnits,
            ),
    );
  }

  Future<void> sell(
    String productId, {
    required CurrencyCode currency,
    int quantity = 1,
  }) async {
    await session.cashSales.complete(
      CompleteSaleCommand(
        saleId: SaleId('sale-${saleSequence++}'),
        merchantId: merchant,
        currency: currency,
        lines: <SaleCommandLine>[
          SaleCommandLine(
            productId: ProductId(productId),
            quantity: Quantity.whole(quantity),
          ),
        ],
      ),
    );
  }

  Future<void> pumpHome(WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Directionality(
          textDirection: TextDirection.rtl,
          child: Scaffold(
            body: HomeScreen(
              session: session,
              onOpen: (AppDestination destination) {},
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  String textFor(WidgetTester tester, String key) {
    return tester.widget<Text>(find.byKey(Key(key))).data!;
  }

  testWidgets('shows sales, gross profit and margin per currency',
      (tester) async {
    await addItem(
      'yer-item',
      currency: CurrencyCode.yemeniRial,
      sellingMinorUnits: 100,
      costMinorUnits: 60,
    );
    await addItem(
      'sar-item',
      currency: CurrencyCode.saudiRiyal,
      sellingMinorUnits: 250,
      costMinorUnits: 100,
    );
    await sell(
      'yer-item',
      currency: CurrencyCode.yemeniRial,
      quantity: 2,
    );
    await sell('sar-item', currency: CurrencyCode.saudiRiyal);
    await pumpHome(tester);

    expect(find.byKey(const Key('currency-card-YER')), findsOneWidget);
    expect(find.byKey(const Key('currency-card-SAR')), findsOneWidget);
    expect(find.byKey(const Key('currency-card-USD')), findsOneWidget);

    expect(textFor(tester, 'sales-YER'), '200 YER');
    expect(textFor(tester, 'profit-YER'), '80 YER');
    expect(textFor(tester, 'margin-YER'), '40.0%');

    expect(textFor(tester, 'sales-SAR'), '250 SAR');
    expect(textFor(tester, 'profit-SAR'), '150 SAR');
    expect(textFor(tester, 'margin-SAR'), '60.0%');

    expect(textFor(tester, 'sales-USD'), '0 USD');
    expect(textFor(tester, 'profit-USD'), '0 USD');
    expect(textFor(tester, 'margin-USD'), '—');

    expect(textFor(tester, 'invoice-count'), '2');
    expect(find.textContaining('ر.س'), findsNothing);
    expect(find.text('450 SAR'), findsNothing);
    expect(find.text('450 YER'), findsNothing);
  });

  testWidgets('unknown cost is reported as incomplete coverage',
      (tester) async {
    await addItem(
      'no-cost',
      currency: CurrencyCode.yemeniRial,
      sellingMinorUnits: 100,
    );
    await sell('no-cost', currency: CurrencyCode.yemeniRial);
    await pumpHome(tester);

    expect(textFor(tester, 'sales-YER'), '100 YER');
    expect(textFor(tester, 'profit-YER'), '—');
    expect(textFor(tester, 'margin-YER'), '—');
    expect(find.byKey(const Key('coverage-YER')), findsOneWidget);
    expect(textFor(tester, 'invoice-count'), '1');
  });

  testWidgets('partially known cost marks profit as partial', (tester) async {
    await addItem(
      'known',
      currency: CurrencyCode.yemeniRial,
      sellingMinorUnits: 100,
      costMinorUnits: 40,
    );
    await addItem(
      'unknown',
      currency: CurrencyCode.yemeniRial,
      sellingMinorUnits: 100,
    );
    await sell('known', currency: CurrencyCode.yemeniRial);
    await sell('unknown', currency: CurrencyCode.yemeniRial);
    await pumpHome(tester);

    expect(textFor(tester, 'sales-YER'), '200 YER');
    expect(textFor(tester, 'profit-YER'), '60 YER (جزئي)');
    expect(textFor(tester, 'margin-YER'), '—');
    expect(find.byKey(const Key('coverage-YER')), findsOneWidget);
  });

  testWidgets('a foreign cost currency leaves profit unknown', (tester) async {
    await addItem(
      'foreign-cost',
      currency: CurrencyCode.yemeniRial,
      sellingMinorUnits: 100,
      costMinorUnits: 60,
      costCurrency: CurrencyCode.saudiRiyal,
    );
    await sell('foreign-cost', currency: CurrencyCode.yemeniRial);
    await pumpHome(tester);

    expect(textFor(tester, 'sales-YER'), '100 YER');
    expect(textFor(tester, 'profit-YER'), '—');
    expect(textFor(tester, 'margin-YER'), '—');
    expect(find.byKey(const Key('coverage-YER')), findsOneWidget);
  });

  testWidgets('losses and zero prices render safely', (tester) async {
    await addItem(
      'loss',
      currency: CurrencyCode.usDollar,
      sellingMinorUnits: 100,
      costMinorUnits: 150,
    );
    await addItem(
      'zero-price',
      currency: CurrencyCode.saudiRiyal,
      sellingMinorUnits: 0,
      costMinorUnits: 40,
    );
    await sell('loss', currency: CurrencyCode.usDollar);
    await sell('zero-price', currency: CurrencyCode.saudiRiyal);
    await pumpHome(tester);

    expect(textFor(tester, 'sales-USD'), '100 USD');
    expect(textFor(tester, 'profit-USD'), '-50 USD');
    expect(textFor(tester, 'margin-USD'), '-50.0%');

    expect(textFor(tester, 'sales-SAR'), '0 SAR');
    expect(textFor(tester, 'profit-SAR'), '-40 SAR');
    expect(textFor(tester, 'margin-SAR'), '—');
  });

  testWidgets('historical profit ignores later inventory cost changes',
      (tester) async {
    await addItem(
      'history',
      currency: CurrencyCode.yemeniRial,
      sellingMinorUnits: 100,
      costMinorUnits: 60,
    );
    await sell('history', currency: CurrencyCode.yemeniRial);
    final item = await session.inventoryService.findByProduct(
      merchant,
      ProductId('history'),
    );
    await session.inventory.update(
      item!.copyWith(
        purchasePrice: const Money(
          currency: CurrencyCode.yemeniRial,
          minorUnits: 90,
        ),
      ),
    );
    await pumpHome(tester);

    expect(textFor(tester, 'profit-YER'), '40 YER');
    expect(textFor(tester, 'margin-YER'), '40.0%');
  });

  testWidgets('narrow screen has no overflow', (tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await addItem(
      'yer-item',
      currency: CurrencyCode.yemeniRial,
      sellingMinorUnits: 100,
      costMinorUnits: 60,
    );
    await sell(
      'yer-item',
      currency: CurrencyCode.yemeniRial,
      quantity: 3,
    );
    await pumpHome(tester);

    expect(tester.takeException(), isNull);
    expect(textFor(tester, 'sales-YER'), '300 YER');
  });
}
