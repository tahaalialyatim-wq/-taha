import 'dart:io';

import 'package:awtad_mobile/core/database/database_service.dart';
import 'package:awtad_mobile/core/database/retail_session.dart';
import 'package:awtad_mobile/presentation/screens/customer_detail_screen.dart';
import 'package:awtad_retail/awtad_retail.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late Directory dir;
  late DatabaseService database;
  late RetailSession session;
  final merchant = RetailSession.defaultMerchant;
  final customerId = CustomerId('c1');
  const customerName = 'عميل الدفعات';
  final occurredAt = DateTime.utc(2026, 10, 12);

  setUp(() async {
    dir = Directory.systemTemp.createTempSync('awtad-pay-');
    database = DatabaseService(databasePath: DatabaseService.pathIn(dir.path));
    await database.initialize();
    session = RetailSession(database);
    await session.customers.add(
      Customer(id: customerId, merchantId: merchant, name: customerName),
    );
  });

  tearDown(() {
    session.close();
    if (dir.existsSync()) {
      dir.deleteSync(recursive: true);
    }
  });

  Future<void> recordOpening(CurrencyCode currency, int minorUnits) {
    return session.openingBalances.record(
      RecordOpeningBalanceCommand(
        entryId: CustomerAccountEntryId('ob-${currency.value}'),
        merchantId: merchant,
        customerId: customerId,
        currency: currency,
        amount: Money(currency: currency, minorUnits: minorUnits),
        occurredAt: occurredAt,
      ),
    );
  }

  Future<void> pumpDetail(WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Directionality(
          textDirection: TextDirection.rtl,
          child: CustomerDetailScreen(
            session: session,
            customer: Customer(
              id: customerId,
              merchantId: merchant,
              name: customerName,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> reveal(WidgetTester tester, Finder finder) async {
    await tester.scrollUntilVisible(
      finder,
      120,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
  }

  Finder paymentField() =>
      find.widgetWithText(TextField, 'مبلغ الدفعة (وحدات صغرى)');
  Finder paymentButton() => find.widgetWithText(FilledButton, 'تسجيل دفعة');
  Finder paymentDropdown() =>
      find.byKey(const Key('payment-currency-dropdown'));

  CurrencyCode? selectedPaymentCurrency(WidgetTester tester) {
    return tester.widget<DropdownButton<CurrencyCode>>(paymentDropdown()).value;
  }

  Future<void> submitPayment(WidgetTester tester, String amount) async {
    await reveal(tester, paymentField());
    await tester.enterText(paymentField(), amount);
    await reveal(tester, paymentButton());
    await tester.tap(paymentButton());
    await tester.pumpAndSettle();
  }

  Future<void> selectPaymentCurrency(
    WidgetTester tester,
    CurrencyCode currency,
  ) async {
    await reveal(tester, paymentDropdown());
    await tester.tap(paymentDropdown());
    await tester.pumpAndSettle();
    await tester.tap(find.text(currency.value).last);
    await tester.pumpAndSettle();
  }

  int ledgerEntryCount() {
    return session.database.database
        .select('SELECT COUNT(*) AS c FROM ledger_entries;')
        .first['c'] as int;
  }

  Future<int> balanceOf(CurrencyCode currency) async {
    return (await session.ledger.getBalance(
      merchant,
      customerId,
      currency,
    ))
        .balanceMinorUnits;
  }

  testWidgets('a single YER balance selects YER', (tester) async {
    await recordOpening(CurrencyCode.yemeniRial, 1000);
    await pumpDetail(tester);

    expect(selectedPaymentCurrency(tester), CurrencyCode.yemeniRial);

    await submitPayment(tester, '400');

    expect(await balanceOf(CurrencyCode.yemeniRial), 600);
  });

  testWidgets('a single USD balance selects USD and never posts YER',
      (tester) async {
    await recordOpening(CurrencyCode.usDollar, 500);
    await pumpDetail(tester);

    expect(selectedPaymentCurrency(tester), CurrencyCode.usDollar);

    await submitPayment(tester, '200');

    expect(await balanceOf(CurrencyCode.usDollar), 300);
    expect(await balanceOf(CurrencyCode.yemeniRial), 0);
    final entries = await session.ledger.getEntries(merchant, customerId);
    expect(
      entries.where((entry) => entry.type == CustomerAccountEntryType.payment),
      hasLength(1),
    );
    expect(
      entries
          .firstWhere((e) => e.type == CustomerAccountEntryType.payment)
          .currency,
      CurrencyCode.usDollar,
    );
  });

  testWidgets('multiple positive balances require explicit selection',
      (tester) async {
    await recordOpening(CurrencyCode.yemeniRial, 1000);
    await recordOpening(CurrencyCode.usDollar, 500);
    await pumpDetail(tester);

    expect(selectedPaymentCurrency(tester), isNull);
    expect(
      find.text('لدى العميل أرصدة بعدة عملات. اختر عملة الدفعة.'),
      findsOneWidget,
    );
  });

  testWidgets('submitting without the required selection writes nothing',
      (tester) async {
    await recordOpening(CurrencyCode.yemeniRial, 1000);
    await recordOpening(CurrencyCode.usDollar, 500);
    await pumpDetail(tester);

    expect(ledgerEntryCount(), 2);
    await submitPayment(tester, '100');

    expect(find.text('اختر عملة الدفعة قبل الحفظ.'), findsOneWidget);
    expect(ledgerEntryCount(), 2);
    expect(await balanceOf(CurrencyCode.yemeniRial), 1000);
    expect(await balanceOf(CurrencyCode.usDollar), 500);
  });

  testWidgets('explicit selection posts only in that currency', (tester) async {
    await recordOpening(CurrencyCode.yemeniRial, 1000);
    await recordOpening(CurrencyCode.usDollar, 500);
    await pumpDetail(tester);

    await selectPaymentCurrency(tester, CurrencyCode.usDollar);
    await submitPayment(tester, '200');

    expect(await balanceOf(CurrencyCode.usDollar), 300);
    expect(await balanceOf(CurrencyCode.yemeniRial), 1000);
  });

  testWidgets('store default SAR prefills when no positive balance exists',
      (tester) async {
    await session.settings.saveDefaultCurrency(
      merchant,
      CurrencyCode.saudiRiyal,
    );
    await pumpDetail(tester);

    expect(selectedPaymentCurrency(tester), CurrencyCode.saudiRiyal);

    await submitPayment(tester, '300');

    expect(await balanceOf(CurrencyCode.saudiRiyal), -300);
  });

  testWidgets('store default never overrides a single outstanding currency',
      (tester) async {
    await session.settings.saveDefaultCurrency(
      merchant,
      CurrencyCode.saudiRiyal,
    );
    await recordOpening(CurrencyCode.usDollar, 500);
    await pumpDetail(tester);

    expect(selectedPaymentCurrency(tester), CurrencyCode.usDollar);
  });

  testWidgets('paying one currency leaves other balances unchanged',
      (tester) async {
    await recordOpening(CurrencyCode.yemeniRial, 1000);
    await recordOpening(CurrencyCode.saudiRiyal, 700);
    await pumpDetail(tester);

    await selectPaymentCurrency(tester, CurrencyCode.saudiRiyal);
    await submitPayment(tester, '200');

    expect(await balanceOf(CurrencyCode.saudiRiyal), 500);
    expect(await balanceOf(CurrencyCode.yemeniRial), 1000);
  });

  testWidgets('overpayment keeps the negative-balance behavior',
      (tester) async {
    await recordOpening(CurrencyCode.yemeniRial, 400);
    await pumpDetail(tester);

    await submitPayment(tester, '900');

    expect(await balanceOf(CurrencyCode.yemeniRial), -500);
    await reveal(tester, find.text('له 500 YER'));
    expect(find.text('له 500 YER'), findsOneWidget);
    expect(find.textContaining('له -'), findsNothing);
  });

  testWidgets('invalid or zero amount creates no ledger entry', (tester) async {
    await recordOpening(CurrencyCode.yemeniRial, 1000);
    await pumpDetail(tester);
    expect(ledgerEntryCount(), 1);

    await submitPayment(tester, '0');
    expect(ledgerEntryCount(), 1);

    await submitPayment(tester, 'abc');
    expect(ledgerEntryCount(), 1);
    expect(await balanceOf(CurrencyCode.yemeniRial), 1000);
  });
}
