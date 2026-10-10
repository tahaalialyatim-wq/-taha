import 'package:awtad_retail/awtad_retail.dart';
import 'package:test/test.dart';

void main() {
  const yer = Money(currency: CurrencyCode.yemeniRial, minorUnits: 1000);
  final occurredAt = DateTime.utc(2026, 1, 15, 8, 30);

  CustomerAccountEntry entry({
    String id = 'e1',
    String merchant = 'm1',
    String customer = 'c1',
    CurrencyCode currency = CurrencyCode.yemeniRial,
    Money? amount,
    CustomerAccountEntryType type = CustomerAccountEntryType.credit,
    DateTime? at,
    String? reference,
  }) =>
      CustomerAccountEntry(
        id: CustomerAccountEntryId(id),
        merchantId: MerchantId(merchant),
        customerId: CustomerId(customer),
        currency: currency,
        amount: amount ?? yer,
        type: type,
        occurredAt: at ?? occurredAt,
        reference: reference,
      );

  group('CustomerAccountEntryId', () {
    test('rejects empty and whitespace-only values', () {
      expect(() => CustomerAccountEntryId(''), throwsArgumentError);
      expect(() => CustomerAccountEntryId('   '), throwsArgumentError);
    });

    test('trims correctly', () {
      expect(CustomerAccountEntryId('  e1 ').value, 'e1');
    });

    test('has value equality', () {
      expect(CustomerAccountEntryId('e1'), CustomerAccountEntryId('e1'));
      expect(
        CustomerAccountEntryId('e1').hashCode,
        CustomerAccountEntryId('e1').hashCode,
      );
      expect(
        CustomerAccountEntryId('e1') == CustomerAccountEntryId('e2'),
        isFalse,
      );
    });
  });

  group('CustomerAccountEntryType', () {
    test('exposes only openingBalance, credit and payment', () {
      expect(CustomerAccountEntryType.values, hasLength(3));
      expect(
        CustomerAccountEntryType.values,
        <CustomerAccountEntryType>[
          CustomerAccountEntryType.openingBalance,
          CustomerAccountEntryType.credit,
          CustomerAccountEntryType.payment,
        ],
      );
    });

    test('openingBalance and credit increase debt; payment decreases it', () {
      expect(CustomerAccountEntryType.openingBalance.increasesDebt, isTrue);
      expect(CustomerAccountEntryType.credit.increasesDebt, isTrue);
      expect(CustomerAccountEntryType.payment.increasesDebt, isFalse);
      expect(CustomerAccountEntryType.payment.decreasesDebt, isTrue);
      expect(CustomerAccountEntryType.openingBalance.decreasesDebt, isFalse);
      expect(CustomerAccountEntryType.credit.decreasesDebt, isFalse);
    });
  });

  group('CustomerAccountEntry', () {
    test('rejects zero and negative amounts', () {
      expect(
        () => entry(
          amount: const Money(currency: CurrencyCode.yemeniRial, minorUnits: 0),
        ),
        throwsArgumentError,
      );
      expect(
        () => entry(
          amount:
              const Money(currency: CurrencyCode.yemeniRial, minorUnits: -1),
        ),
        throwsArgumentError,
      );
    });

    test('rejects amount currency that does not match entry currency', () {
      expect(
        () => entry(
          currency: CurrencyCode.yemeniRial,
          amount: const Money(
            currency: CurrencyCode.saudiRiyal,
            minorUnits: 100,
          ),
        ),
        throwsArgumentError,
      );
    });

    test('trims optional reference and blank becomes null', () {
      expect(entry(reference: '  sale-1 ').reference, 'sale-1');
      expect(entry(reference: '   ').reference, isNull);
      expect(entry().reference, isNull);
    });

    test('stores occurredAt as provided', () {
      expect(entry().occurredAt, occurredAt);
      expect(entry().occurredAt.isUtc, isTrue);
    });

    test('equality is by CustomerAccountEntryId only', () {
      final a = entry(id: 'e1', type: CustomerAccountEntryType.credit);
      final b = entry(
        id: 'e1',
        merchant: 'm2',
        type: CustomerAccountEntryType.payment,
      );
      expect(a, b);
      expect(a.hashCode, b.hashCode);
      expect(a == entry(id: 'e2'), isFalse);
    });

    test('does not embed a running balance', () {
      expect(entry().toString(),
          'CustomerAccountEntry(CustomerAccountEntryId(e1))');
    });
  });

  group('CustomerAccountBalance', () {
    test('positive means the customer owes the merchant', () {
      const balance = CustomerAccountBalance(
        currency: CurrencyCode.yemeniRial,
        balanceMinorUnits: 500,
      );
      expect(balance.balanceMinorUnits > 0, isTrue);
      expect(balance.currency, CurrencyCode.yemeniRial);
    });

    test('zero means settled', () {
      const balance = CustomerAccountBalance(
        currency: CurrencyCode.yemeniRial,
        balanceMinorUnits: 0,
      );
      expect(balance.balanceMinorUnits, 0);
    });

    test('negative means the customer has a credit in their favor', () {
      const balance = CustomerAccountBalance(
        currency: CurrencyCode.yemeniRial,
        balanceMinorUnits: -250,
      );
      expect(balance.balanceMinorUnits < 0, isTrue);
    });

    test('equality includes currency and minor units', () {
      const a = CustomerAccountBalance(
        currency: CurrencyCode.yemeniRial,
        balanceMinorUnits: 100,
      );
      const b = CustomerAccountBalance(
        currency: CurrencyCode.yemeniRial,
        balanceMinorUnits: 100,
      );
      const differentAmount = CustomerAccountBalance(
        currency: CurrencyCode.yemeniRial,
        balanceMinorUnits: 200,
      );
      const differentCurrency = CustomerAccountBalance(
        currency: CurrencyCode.usDollar,
        balanceMinorUnits: 100,
      );
      expect(a, b);
      expect(a.hashCode, b.hashCode);
      expect(a == differentAmount, isFalse);
      expect(a == differentCurrency, isFalse);
    });
  });
}
