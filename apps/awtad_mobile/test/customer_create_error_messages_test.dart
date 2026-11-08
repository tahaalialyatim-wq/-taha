import 'package:awtad_mobile/core/database/database_init_exception.dart';
import 'package:awtad_mobile/core/database/retail_session.dart';
import 'package:awtad_mobile/presentation/screens/customers_screen.dart';
import 'package:awtad_mobile/presentation/utils/customer_create_error_message.dart';
import 'package:awtad_retail/awtad_retail.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'phase1_fakes.dart';

const _duplicate = 'رقم الهاتف مسجل بالفعل لعميل آخر.';
const _validation = 'البيانات المدخلة غير صحيحة. تحقق من الحقول.';
const _storage = 'تعذر حفظ العميل في قاعدة البيانات. حاول مرة أخرى.';
const _fallback = 'حدث خطأ غير متوقع. حاول مرة أخرى.';

void main() {
  test('duplicate-like create errors map to Arabic duplicate phone feedback',
      () {
    final typed = DuplicateCustomerPhoneException(
      merchantId: MerchantId('m1'),
      customerId: CustomerId('c-new'),
      existingCustomerId: CustomerId('c-old'),
      phone: '777',
    );
    final fromMessage = Exception('UNIQUE constraint failed: customers.phone');
    for (final error in <Object>[typed, fromMessage]) {
      final message = customerCreateErrorMessage(error);
      expect(message, _duplicate);
      expect(message, isNot(error.toString()));
    }
  });

  test('validation-like create errors map to Arabic validation feedback', () {
    final typed = ArgumentError.value('', 'name', 'invalid');
    final fromMessage = Exception('validation failed for name');
    for (final error in <Object>[typed, fromMessage]) {
      final message = customerCreateErrorMessage(error);
      expect(message, _validation);
      expect(message, isNot(error.toString()));
    }
  });

  test('storage-like create errors map to Arabic storage feedback', () {
    final typed = DatabaseInitException('failed to open sqlite file');
    final fromMessage = Exception('storage write failed');
    for (final error in <Object>[typed, fromMessage]) {
      final message = customerCreateErrorMessage(error);
      expect(message, _storage);
      expect(message, isNot(error.toString()));
    }
  });

  test('unknown create errors map to Arabic fallback and never leak toString',
      () {
    const error = 'totally-unknown-failure-xyz';
    final message = customerCreateErrorMessage(error);
    expect(message, _fallback);
    expect(message, isNot(error.toString()));
  });

  testWidgets('create screen shows Arabic duplicate feedback', (tester) async {
    await _pumpCreateFailure(
      tester,
      DuplicateCustomerPhoneException(
        merchantId: RetailSession.defaultMerchant,
        customerId: CustomerId('c-new'),
        existingCustomerId: CustomerId('c-old'),
        phone: '777',
      ),
    );
    expect(find.text(_duplicate), findsOneWidget);
    expect(find.textContaining('DuplicateCustomer'), findsNothing);
  });

  testWidgets('create screen shows Arabic validation feedback', (tester) async {
    await _pumpCreateFailure(
      tester,
      ArgumentError.value('', 'name', 'invalid'),
    );
    expect(find.text(_validation), findsOneWidget);
  });

  testWidgets('create screen shows Arabic storage feedback', (tester) async {
    await _pumpCreateFailure(
      tester,
      DatabaseInitException('sqlite open failed'),
    );
    expect(find.text(_storage), findsOneWidget);
    expect(find.textContaining('DatabaseInitException'), findsNothing);
  });

  testWidgets('create screen shows Arabic fallback and hides toString',
      (tester) async {
    const error = 'totally-unknown-failure-xyz';
    await _pumpCreateFailure(tester, error);
    expect(find.text(_fallback), findsOneWidget);
    expect(find.text(error), findsNothing);
  });
}

Future<void> _pumpCreateFailure(WidgetTester tester, Object error) async {
  final customers = FakeCustomerRepository(addError: error);
  final session = sessionWithoutSqlite(customers: customers);
  await tester.pumpWidget(
    MaterialApp(
      home: Directionality(
        textDirection: TextDirection.rtl,
        child: Scaffold(body: CustomersScreen(session: session)),
      ),
    ),
  );
  await tester.pumpAndSettle();
  await tester.enterText(find.byKey(const Key('customer-name-field')), 'علي');
  await tester.enterText(find.byKey(const Key('customer-phone-field')), '777');
  await tester.tap(find.widgetWithText(FilledButton, 'إنشاء حساب'));
  await tester.pumpAndSettle();
  expect(find.byKey(const Key('customer-create-message')), findsOneWidget);
}
