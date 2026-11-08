import 'dart:io';

import 'package:awtad_mobile/core/database/database_service.dart';
import 'package:awtad_mobile/core/database/retail_session.dart';
import 'package:awtad_mobile/presentation/screens/sales_screen.dart';
import 'package:awtad_retail/awtad_retail.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late Directory dir;
  late DatabaseService database;
  late RetailSession session;
  final merchant = RetailSession.defaultMerchant;

  setUp(() async {
    dir = Directory.systemTemp.createTempSync('awtad-sales-');
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

  Future<void> seedItem(
    String productId, {
    required CurrencyCode? currency,
    int minorUnits = 100,
    int quantity = 5,
  }) async {
    await session.inventoryService.addProduct(
      merchant,
      ProductId(productId),
      quantity: Quantity.whole(quantity),
      sellingPrice: currency == null
          ? null
          : Money(currency: currency, minorUnits: minorUnits),
    );
  }

  Future<void> pumpScreen(WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Directionality(
          textDirection: TextDirection.rtl,
          child: Scaffold(body: SalesScreen(session: session)),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> addToCart(WidgetTester tester, String productId) async {
    final tile = find.ancestor(
      of: find.text(productId),
      matching: find.byType(ListTile),
    );
    final icon = find.descendant(
      of: tile,
      matching: find.byIcon(Icons.add_shopping_cart),
    );
    await tester.tap(icon);
    await tester.pumpAndSettle();
  }

  Future<void> tapCash(WidgetTester tester) async {
    await tester.tap(find.textContaining('نقدي'));
    await tester.pumpAndSettle();
  }

  Future<void> tapCredit(WidgetTester tester) async {
    await tester.tap(find.widgetWithText(OutlinedButton, 'آجل'));
    await tester.pumpAndSettle();
  }

  int rawSaleLineCount() {
    return session.database.database
        .select('SELECT COUNT(*) AS c FROM sale_lines;')
        .first['c'] as int;
  }

  testWidgets('a YER-priced cart sells in YER without a SAR mismatch',
      (tester) async {
    await seedItem('p1', currency: CurrencyCode.yemeniRial, minorUnits: 250);
    await pumpScreen(tester);

    await addToCart(tester, 'p1');
    await tapCash(tester);

    expect(find.text('تم حفظ البيع.'), findsOneWidget);
    final sales = await session.sales.getAll(merchant);
    expect(sales, hasLength(1));
    expect(sales.single.currency, CurrencyCode.yemeniRial);
    expect(
      sales.single.lines.single.unitSellingPrice.currency,
      CurrencyCode.yemeniRial,
    );
  });

  testWidgets('a unanimous SAR cart retains SAR', (tester) async {
    await seedItem('p1', currency: CurrencyCode.saudiRiyal);
    await seedItem('p2', currency: CurrencyCode.saudiRiyal);
    await pumpScreen(tester);

    await addToCart(tester, 'p1');
    await addToCart(tester, 'p2');
    await tapCash(tester);

    final sale = (await session.sales.getAll(merchant)).single;
    expect(sale.currency, CurrencyCode.saudiRiyal);
  });

  testWidgets('a unanimous USD cart retains USD', (tester) async {
    await seedItem('p1', currency: CurrencyCode.usDollar);
    await pumpScreen(tester);

    await addToCart(tester, 'p1');
    await tapCash(tester);

    final sale = (await session.sales.getAll(merchant)).single;
    expect(sale.currency, CurrencyCode.usDollar);
  });

  testWidgets('a mixed YER+SAR cart is rejected before any write',
      (tester) async {
    await seedItem('p1', currency: CurrencyCode.yemeniRial);
    await seedItem('p2', currency: CurrencyCode.saudiRiyal);
    await pumpScreen(tester);

    await addToCart(tester, 'p1');
    await addToCart(tester, 'p2');
    await tapCash(tester);

    expect(
      find.text('لا يمكن خلط عملات مختلفة في فاتورة واحدة.'),
      findsOneWidget,
    );
    expect(await session.sales.getAll(merchant), isEmpty);
    expect(rawSaleLineCount(), 0);
  });

  testWidgets('an explicit selection mismatching the cart is rejected',
      (tester) async {
    await seedItem('p1', currency: CurrencyCode.yemeniRial);
    await pumpScreen(tester);

    await tester.tap(find.byKey(const Key('sale-currency-SAR')));
    await tester.pumpAndSettle();
    await addToCart(tester, 'p1');
    await tapCash(tester);

    expect(
      find.text('عملة الفاتورة يجب أن تطابق عملة أسعار المنتجات (YER).'),
      findsOneWidget,
    );
    expect(await session.sales.getAll(merchant), isEmpty);
    expect(rawSaleLineCount(), 0);
  });

  testWidgets('an undeterminable currency blocks submission without writes',
      (tester) async {
    await seedItem('p1', currency: null, quantity: 3);
    await pumpScreen(tester);

    await addToCart(tester, 'p1');
    await tapCash(tester);

    expect(find.text('اختر عملة الفاتورة قبل الحفظ.'), findsOneWidget);
    expect(await session.sales.getAll(merchant), isEmpty);
    expect(rawSaleLineCount(), 0);
  });

  testWidgets('the saved default never overrides a priced cart currency',
      (tester) async {
    await seedItem('p1', currency: CurrencyCode.yemeniRial);
    await session.settings.saveDefaultCurrency(
      merchant,
      CurrencyCode.saudiRiyal,
    );
    await pumpScreen(tester);

    await addToCart(tester, 'p1');
    await tapCash(tester);

    final sale = (await session.sales.getAll(merchant)).single;
    expect(sale.currency, CurrencyCode.yemeniRial);
  });

  testWidgets('the credit path persists the intrinsic currency',
      (tester) async {
    await seedItem('p1', currency: CurrencyCode.yemeniRial, minorUnits: 400);
    final customerId = CustomerId('c1');
    await session.customers.add(
      Customer(id: customerId, merchantId: merchant, name: 'عميل آجل'),
    );
    await pumpScreen(tester);

    await tester.tap(find.byType(DropdownButton<CustomerId>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('عميل آجل').last);
    await tester.pumpAndSettle();

    await addToCart(tester, 'p1');
    await tapCredit(tester);

    expect(find.text('تم حفظ البيع.'), findsOneWidget);
    final sale = (await session.sales.getAll(merchant)).single;
    expect(sale.currency, CurrencyCode.yemeniRial);
    expect(sale.customerId, customerId);
    final balance = await session.ledger.getBalance(
      merchant,
      customerId,
      CurrencyCode.yemeniRial,
    );
    expect(balance.balanceMinorUnits, 400);
  });

  testWidgets('list shows currency labels and a successful sale clears cart',
      (tester) async {
    await seedItem('p1', currency: CurrencyCode.saudiRiyal, minorUnits: 300);
    await pumpScreen(tester);

    expect(find.textContaining('300 SAR'), findsOneWidget);

    await addToCart(tester, 'p1');
    expect(find.textContaining('نقدي (1)'), findsOneWidget);
    await tapCash(tester);

    expect(find.text('تم حفظ البيع.'), findsOneWidget);
    expect(find.textContaining('نقدي (0)'), findsOneWidget);
    expect(find.textContaining('الإجمالي'), findsOneWidget);
  });
}
