import 'dart:io';

import 'package:awtad_mobile/core/database/database_service.dart';
import 'package:awtad_mobile/core/database/retail_session.dart';
import 'package:awtad_mobile/presentation/screens/reports_screen.dart';
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
    dir = Directory.systemTemp.createTempSync('awtad-reports-');
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

  Future<void> pumpReports(WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Directionality(
          textDirection: TextDirection.rtl,
          child: Scaffold(body: ReportsScreen(session: session)),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  String textFor(WidgetTester tester, String key) {
    return tester.widget<Text>(find.byKey(Key(key))).data!;
  }

  testWidgets('empty sales show zero totals per currency', (tester) async {
    await pumpReports(tester);

    expect(textFor(tester, 'sales-count'), '0');
    expect(textFor(tester, 'sales-total-YER'), '0 YER');
    expect(textFor(tester, 'sales-total-SAR'), '0 SAR');
    expect(textFor(tester, 'sales-total-USD'), '0 USD');
    expect(find.textContaining('هللة'), findsNothing);
    expect(find.textContaining('هللات'), findsNothing);
  });

  testWidgets('single-currency sales stay in that currency', (tester) async {
    await addItem(
      'yer-item',
      currency: CurrencyCode.yemeniRial,
      sellingMinorUnits: 100,
    );
    await sell(
      'yer-item',
      currency: CurrencyCode.yemeniRial,
      quantity: 2,
    );
    await pumpReports(tester);

    expect(textFor(tester, 'sales-count'), '1');
    expect(textFor(tester, 'sales-total-YER'), '200 YER');
    expect(textFor(tester, 'sales-total-SAR'), '0 SAR');
    expect(textFor(tester, 'sales-total-USD'), '0 USD');
    expect(find.text('200 SAR'), findsNothing);
    expect(find.textContaining('هللة'), findsNothing);
    expect(find.textContaining('هللات'), findsNothing);
  });

  testWidgets('multiple currencies are not summed together', (tester) async {
    await addItem(
      'yer-item',
      currency: CurrencyCode.yemeniRial,
      sellingMinorUnits: 100,
    );
    await addItem(
      'sar-item',
      currency: CurrencyCode.saudiRiyal,
      sellingMinorUnits: 250,
    );
    await sell(
      'yer-item',
      currency: CurrencyCode.yemeniRial,
      quantity: 2,
    );
    await sell('sar-item', currency: CurrencyCode.saudiRiyal);
    await pumpReports(tester);

    expect(textFor(tester, 'sales-count'), '2');
    expect(textFor(tester, 'sales-total-YER'), '200 YER');
    expect(textFor(tester, 'sales-total-SAR'), '250 SAR');
    expect(textFor(tester, 'sales-total-USD'), '0 USD');
    expect(find.text('450'), findsNothing);
    expect(find.text('450 YER'), findsNothing);
    expect(find.text('450 SAR'), findsNothing);
    expect(find.textContaining('هللة'), findsNothing);
    expect(find.textContaining('هللات'), findsNothing);
  });
}
