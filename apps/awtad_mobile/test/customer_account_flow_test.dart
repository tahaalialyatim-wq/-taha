import 'dart:io';

import 'package:awtad_mobile/core/database/database_service.dart';
import 'package:awtad_mobile/core/database/retail_session.dart';
import 'package:awtad_mobile/presentation/screens/customer_detail_screen.dart';
import 'package:awtad_mobile/presentation/screens/customers_screen.dart';
import 'package:awtad_retail/awtad_retail.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late Directory dir;
  late DatabaseService database;
  late RetailSession session;
  final merchant = RetailSession.defaultMerchant;
  final customerId = CustomerId('c1');
  const customerName = 'عميل الأوتاد';
  final occurredAt = DateTime.utc(2026, 10, 12);

  setUp(() async {
    dir = Directory.systemTemp.createTempSync('awtad-ui-');
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

  Finder openingButton() =>
      find.widgetWithText(FilledButton, 'تسجيل الرصيد الافتتاحي');
  Finder paymentButton() => find.widgetWithText(FilledButton, 'تسجيل دفعة');
  Finder openingField() =>
      find.widgetWithText(TextField, 'المبلغ (وحدات صغرى)');
  Finder paymentField() =>
      find.widgetWithText(TextField, 'مبلغ الدفعة (وحدات صغرى)');

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

  Future<void> recordOpening(CurrencyCode currency, int minorUnits) async {
    await session.openingBalances.record(
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

  testWidgets('opening balance and payment actions are visible for a customer',
      (tester) async {
    await pumpDetail(tester);
    expect(openingButton(), findsOneWidget);
    expect(paymentButton(), findsOneWidget);
  });

  testWidgets('recording an opening balance updates and persists the balance',
      (tester) async {
    await pumpDetail(tester);
    await tester.enterText(openingField(), '1000');
    await tester.tap(openingButton());
    await tester.pumpAndSettle();

    expect(find.text('عليه 1000 YER'), findsOneWidget);
    expect(find.text('تم تسجيل الرصيد الافتتاحي.'), findsOneWidget);

    final reopened = DatabaseService(
      databasePath: DatabaseService.pathIn(dir.path),
    );
    await reopened.initialize();
    addTearDown(reopened.close);
    final reopenedSession = RetailSession(reopened);
    expect(
      (await reopenedSession.ledger.getBalance(
        merchant,
        customerId,
        CurrencyCode.yemeniRial,
      ))
          .balanceMinorUnits,
      1000,
    );
  });

  testWidgets('recording a payment reduces the balance without a double minus',
      (tester) async {
    await recordOpening(CurrencyCode.yemeniRial, 400);
    await pumpDetail(tester);
    await tester.enterText(paymentField(), '500');
    await tester.tap(paymentButton());
    await tester.pumpAndSettle();

    expect(find.text('له 100 YER'), findsOneWidget);
    expect(find.textContaining('له -'), findsNothing);
  });

  testWidgets('opening balances are independent per currency', (tester) async {
    await pumpDetail(tester);
    await tester.enterText(openingField(), '1000');
    await tester.tap(openingButton());
    await tester.pumpAndSettle();
    await tester.enterText(openingField(), '200');
    await tester.tap(openingButton());
    await tester.pumpAndSettle();

    expect(find.text('عليه 1000 YER'), findsOneWidget);
    expect(find.text('عليه 200 SAR'), findsOneWidget);
  });

  testWidgets('actions stay reachable when the entry history is long',
      (tester) async {
    await recordOpening(CurrencyCode.yemeniRial, 100000);
    for (var i = 0; i < 40; i++) {
      await session.payments.record(
        RecordCustomerPaymentCommand(
          entryId: CustomerAccountEntryId('p$i'),
          merchantId: merchant,
          customerId: customerId,
          currency: CurrencyCode.yemeniRial,
          amount: const Money(
            currency: CurrencyCode.yemeniRial,
            minorUnits: 100,
          ),
          occurredAt: occurredAt,
        ),
      );
    }
    await pumpDetail(tester);

    expect(paymentButton(), findsOneWidget);
    expect(openingButton(), findsOneWidget);
  });

  testWidgets('opening action explains when every currency already has entries',
      (tester) async {
    for (final currency in CurrencyCode.values) {
      await recordOpening(currency, 100);
    }
    await pumpDetail(tester);

    expect(
      find.text('لكل عملة قيود مسجلة، فلا يمكن إضافة رصيد افتتاحي.'),
      findsOneWidget,
    );
    expect(openingButton(), findsNothing);
    expect(paymentButton(), findsOneWidget);
  });

  testWidgets('customer row exposes and opens the account action screen',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Directionality(
          textDirection: TextDirection.rtl,
          child: Scaffold(body: CustomersScreen(session: session)),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.chevron_left), findsOneWidget);
    await tester.tap(find.text(customerName));
    await tester.pumpAndSettle();

    expect(openingButton(), findsOneWidget);
    expect(paymentButton(), findsOneWidget);
  });
}
