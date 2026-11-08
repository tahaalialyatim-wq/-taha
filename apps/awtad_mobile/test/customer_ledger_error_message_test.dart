import 'package:awtad_mobile/core/database/database_init_exception.dart';
import 'package:awtad_mobile/presentation/utils/customer_ledger_error_message.dart';
import 'package:awtad_retail/awtad_retail.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('duplicate-like errors map to Arabic duplicate feedback', () {
    final typed = DuplicateCustomerPhoneException(
      merchantId: MerchantId('m1'),
      customerId: CustomerId('c-new'),
      existingCustomerId: CustomerId('c-old'),
      phone: '777',
    );
    final fromMessage = Exception('UNIQUE constraint failed: customers.phone');
    for (final error in <Object>[typed, fromMessage]) {
      final message = customerLedgerErrorMessage(error);
      expect(
        message.contains('مسجل بالفعل') || message.contains('مكرر'),
        isTrue,
      );
      expect(message, isNot(error.toString()));
    }
  });

  test('validation-like errors map to Arabic validation feedback', () {
    final typed = ArgumentError.value(-1, 'amount', 'invalid');
    final fromMessage = Exception('validation failed for amount');
    for (final error in <Object>[typed, fromMessage]) {
      final message = customerLedgerErrorMessage(error);
      expect(message, contains('غير صحيحة'));
      expect(message, isNot(error.toString()));
    }
  });

  test('storage-like errors map to Arabic storage feedback', () {
    final typed = DatabaseInitException('failed to open sqlite file');
    final fromMessage = Exception('storage write failed');
    for (final error in <Object>[typed, fromMessage]) {
      final message = customerLedgerErrorMessage(error);
      expect(message, contains('تعذر حفظ'));
      expect(message, isNot(error.toString()));
    }
  });

  test('unknown errors map to Arabic fallback and never leak toString', () {
    const error = 'totally-unknown-failure-xyz';
    final message = customerLedgerErrorMessage(error);
    expect(message, contains('غير متوقع'));
    expect(message, isNot(error.toString()));
  });
}
