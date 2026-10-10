import 'package:awtad_retail/awtad_retail.dart';
import 'package:test/test.dart';

void main() {
  late InMemoryCustomerRepository customers;
  late InMemoryCustomerAccountLedgerRepository ledger;

  final occurredAt = DateTime.utc(2026, 3, 1, 12);

  setUp(() async {
    customers = InMemoryCustomerRepository();
    ledger = InMemoryCustomerAccountLedgerRepository(customers: customers);
    await customers.add(
      Customer(
        id: CustomerId('c1'),
        merchantId: MerchantId('m1'),
        name: 'Ali',
      ),
    );
    await customers.add(
      Customer(
        id: CustomerId('c2'),
        merchantId: MerchantId('m1'),
        name: 'Sara',
      ),
    );
    await customers.add(
      Customer(
        id: CustomerId('c1'),
        merchantId: MerchantId('m2'),
        name: 'Other',
      ),
    );
  });

  CustomerAccountEntry entry({
    String id = 'e1',
    String merchant = 'm1',
    String customer = 'c1',
    CurrencyCode currency = CurrencyCode.yemeniRial,
    int minorUnits = 1000,
    CustomerAccountEntryType type = CustomerAccountEntryType.credit,
    DateTime? at,
    String? reference,
  }) =>
      CustomerAccountEntry(
        id: CustomerAccountEntryId(id),
        merchantId: MerchantId(merchant),
        customerId: CustomerId(customer),
        currency: currency,
        amount: Money(currency: currency, minorUnits: minorUnits),
        type: type,
        occurredAt: at ?? occurredAt,
        reference: reference,
      );

  group('InMemoryCustomerAccountLedgerRepository', () {
    test('openingBalance increases debt', () async {
      await ledger.append(
        entry(type: CustomerAccountEntryType.openingBalance, minorUnits: 500),
      );
      final balance = await ledger.getBalance(
        MerchantId('m1'),
        CustomerId('c1'),
        CurrencyCode.yemeniRial,
      );
      expect(balance.balanceMinorUnits, 500);
      expect(balance.currency, CurrencyCode.yemeniRial);
    });

    test('credit increases debt', () async {
      await ledger.append(
        entry(type: CustomerAccountEntryType.credit, minorUnits: 250),
      );
      final balance = await ledger.getBalance(
        MerchantId('m1'),
        CustomerId('c1'),
        CurrencyCode.yemeniRial,
      );
      expect(balance.balanceMinorUnits, 250);
    });

    test('payment decreases debt', () async {
      await ledger.append(
        entry(
          id: 'e1',
          type: CustomerAccountEntryType.openingBalance,
          minorUnits: 1000,
        ),
      );
      await ledger.append(
        entry(
          id: 'e2',
          type: CustomerAccountEntryType.payment,
          minorUnits: 400,
        ),
      );
      final balance = await ledger.getBalance(
        MerchantId('m1'),
        CustomerId('c1'),
        CurrencyCode.yemeniRial,
      );
      expect(balance.balanceMinorUnits, 600);
    });

    test('multiple entries produce the correct balance', () async {
      await ledger.append(
        entry(
          id: 'e1',
          type: CustomerAccountEntryType.openingBalance,
          minorUnits: 1000,
        ),
      );
      await ledger.append(
        entry(
          id: 'e2',
          type: CustomerAccountEntryType.credit,
          minorUnits: 500,
        ),
      );
      await ledger.append(
        entry(
          id: 'e3',
          type: CustomerAccountEntryType.payment,
          minorUnits: 300,
        ),
      );
      await ledger.append(
        entry(
          id: 'e4',
          type: CustomerAccountEntryType.credit,
          minorUnits: 200,
        ),
      );
      final balance = await ledger.getBalance(
        MerchantId('m1'),
        CustomerId('c1'),
        CurrencyCode.yemeniRial,
      );
      expect(balance.balanceMinorUnits, 1400);
    });

    test('zero balance after full settlement', () async {
      await ledger.append(
        entry(
          id: 'e1',
          type: CustomerAccountEntryType.credit,
          minorUnits: 750,
        ),
      );
      await ledger.append(
        entry(
          id: 'e2',
          type: CustomerAccountEntryType.payment,
          minorUnits: 750,
        ),
      );
      final balance = await ledger.getBalance(
        MerchantId('m1'),
        CustomerId('c1'),
        CurrencyCode.yemeniRial,
      );
      expect(balance.balanceMinorUnits, 0);
    });

    test('negative balance when payments exceed recorded debt', () async {
      await ledger.append(
        entry(
          id: 'e1',
          type: CustomerAccountEntryType.credit,
          minorUnits: 200,
        ),
      );
      await ledger.append(
        entry(
          id: 'e2',
          type: CustomerAccountEntryType.payment,
          minorUnits: 500,
        ),
      );
      final balance = await ledger.getBalance(
        MerchantId('m1'),
        CustomerId('c1'),
        CurrencyCode.yemeniRial,
      );
      expect(balance.balanceMinorUnits, -300);
    });

    test('payment with no prior debt is accepted as a customer credit',
        () async {
      await ledger.append(
        entry(
          type: CustomerAccountEntryType.payment,
          minorUnits: 400,
        ),
      );
      final balance = await ledger.getBalance(
        MerchantId('m1'),
        CustomerId('c1'),
        CurrencyCode.yemeniRial,
      );
      expect(balance.balanceMinorUnits, -400);
    });

    test('later credit after overpayment nets the remaining customer credit',
        () async {
      await ledger.append(
        entry(
          id: 'e1',
          type: CustomerAccountEntryType.payment,
          minorUnits: 500,
        ),
      );
      await ledger.append(
        entry(
          id: 'e2',
          type: CustomerAccountEntryType.credit,
          minorUnits: 200,
        ),
      );
      final balance = await ledger.getBalance(
        MerchantId('m1'),
        CustomerId('c1'),
        CurrencyCode.yemeniRial,
      );
      expect(balance.balanceMinorUnits, -300);
    });

    test('openingBalance is accepted as the first entry', () async {
      await ledger.append(
        entry(
          type: CustomerAccountEntryType.openingBalance,
          minorUnits: 1000,
        ),
      );
      final entries =
          await ledger.getEntries(MerchantId('m1'), CustomerId('c1'));
      expect(entries.single.type, CustomerAccountEntryType.openingBalance);
      expect(
        (await ledger.getBalance(
          MerchantId('m1'),
          CustomerId('c1'),
          CurrencyCode.yemeniRial,
        ))
            .balanceMinorUnits,
        1000,
      );
    });

    test('openingBalance after a credit entry is rejected', () async {
      await ledger.append(
        entry(id: 'e1', type: CustomerAccountEntryType.credit, minorUnits: 200),
      );
      expect(
        () => ledger.append(
          entry(
            id: 'e2',
            type: CustomerAccountEntryType.openingBalance,
            minorUnits: 300,
          ),
        ),
        throwsA(isA<OpeningBalanceNotFirstException>()),
      );
      final entries =
          await ledger.getEntries(MerchantId('m1'), CustomerId('c1'));
      expect(entries, hasLength(1));
      expect(entries.single.type, CustomerAccountEntryType.credit);
      expect(
        (await ledger.getBalance(
          MerchantId('m1'),
          CustomerId('c1'),
          CurrencyCode.yemeniRial,
        ))
            .balanceMinorUnits,
        200,
      );
    });

    test('openingBalance after a payment entry is rejected', () async {
      await ledger.append(
        entry(
          id: 'e1',
          type: CustomerAccountEntryType.payment,
          minorUnits: 400,
        ),
      );
      expect(
        () => ledger.append(
          entry(
            id: 'e2',
            type: CustomerAccountEntryType.openingBalance,
            minorUnits: 300,
          ),
        ),
        throwsA(isA<OpeningBalanceNotFirstException>()),
      );
      final entries =
          await ledger.getEntries(MerchantId('m1'), CustomerId('c1'));
      expect(entries, hasLength(1));
      expect(entries.single.type, CustomerAccountEntryType.payment);
      expect(
        (await ledger.getBalance(
          MerchantId('m1'),
          CustomerId('c1'),
          CurrencyCode.yemeniRial,
        ))
            .balanceMinorUnits,
        -400,
      );
    });

    test('a second openingBalance for the same currency is rejected', () async {
      await ledger.append(
        entry(
          id: 'e1',
          type: CustomerAccountEntryType.openingBalance,
          minorUnits: 1000,
        ),
      );
      expect(
        () => ledger.append(
          entry(
            id: 'e2',
            type: CustomerAccountEntryType.openingBalance,
            minorUnits: 500,
          ),
        ),
        throwsA(isA<DuplicateOpeningBalanceException>()),
      );
      final entries =
          await ledger.getEntries(MerchantId('m1'), CustomerId('c1'));
      expect(entries, hasLength(1));
      expect(
        (await ledger.getBalance(
          MerchantId('m1'),
          CustomerId('c1'),
          CurrencyCode.yemeniRial,
        ))
            .balanceMinorUnits,
        1000,
      );
    });

    test(
        'rejected out-of-order openingBalance does not change entries or balance',
        () async {
      await ledger.append(
        entry(id: 'e1', type: CustomerAccountEntryType.credit, minorUnits: 250),
      );
      expect(
        () => ledger.append(
          entry(
            id: 'e2',
            type: CustomerAccountEntryType.openingBalance,
            minorUnits: 900,
          ),
        ),
        throwsA(isA<OpeningBalanceNotFirstException>()),
      );
      final entries =
          await ledger.getEntries(MerchantId('m1'), CustomerId('c1'));
      expect(entries.map((e) => e.id.value), <String>['e1']);
      expect(
        (await ledger.getBalance(
          MerchantId('m1'),
          CustomerId('c1'),
          CurrencyCode.yemeniRial,
        ))
            .balanceMinorUnits,
        250,
      );
    });

    test('openingBalance is allowed independently in another currency',
        () async {
      await ledger.append(
        entry(
          id: 'e1',
          type: CustomerAccountEntryType.openingBalance,
          currency: CurrencyCode.yemeniRial,
          minorUnits: 1000,
        ),
      );
      await ledger.append(
        entry(
          id: 'e2',
          type: CustomerAccountEntryType.openingBalance,
          currency: CurrencyCode.saudiRiyal,
          minorUnits: 400,
        ),
      );
      final entries =
          await ledger.getEntries(MerchantId('m1'), CustomerId('c1'));
      expect(entries, hasLength(2));
      expect(
        (await ledger.getBalance(
          MerchantId('m1'),
          CustomerId('c1'),
          CurrencyCode.yemeniRial,
        ))
            .balanceMinorUnits,
        1000,
      );
      expect(
        (await ledger.getBalance(
          MerchantId('m1'),
          CustomerId('c1'),
          CurrencyCode.saudiRiyal,
        ))
            .balanceMinorUnits,
        400,
      );
    });

    test('credit remains allowed after an openingBalance', () async {
      await ledger.append(
        entry(
          id: 'e1',
          type: CustomerAccountEntryType.openingBalance,
          minorUnits: 1000,
        ),
      );
      await ledger.append(
        entry(id: 'e2', type: CustomerAccountEntryType.credit, minorUnits: 250),
      );
      expect(
        (await ledger.getBalance(
          MerchantId('m1'),
          CustomerId('c1'),
          CurrencyCode.yemeniRial,
        ))
            .balanceMinorUnits,
        1250,
      );
    });

    test('openingBalance is isolated per merchant and customer', () async {
      await ledger.append(
        entry(
          id: 'e1',
          merchant: 'm1',
          customer: 'c1',
          type: CustomerAccountEntryType.openingBalance,
          minorUnits: 1000,
        ),
      );
      await ledger.append(
        entry(
          id: 'e2',
          merchant: 'm1',
          customer: 'c2',
          type: CustomerAccountEntryType.openingBalance,
          minorUnits: 400,
        ),
      );
      await ledger.append(
        entry(
          id: 'e1',
          merchant: 'm2',
          customer: 'c1',
          type: CustomerAccountEntryType.openingBalance,
          minorUnits: 250,
        ),
      );
      expect(
        (await ledger.getBalance(
          MerchantId('m1'),
          CustomerId('c1'),
          CurrencyCode.yemeniRial,
        ))
            .balanceMinorUnits,
        1000,
      );
      expect(
        (await ledger.getBalance(
          MerchantId('m1'),
          CustomerId('c2'),
          CurrencyCode.yemeniRial,
        ))
            .balanceMinorUnits,
        400,
      );
      expect(
        (await ledger.getBalance(
          MerchantId('m2'),
          CustomerId('c1'),
          CurrencyCode.yemeniRial,
        ))
            .balanceMinorUnits,
        250,
      );
    });

    test('existing customer with no entries has empty list and zero balance',
        () async {
      expect(
        await ledger.getEntries(MerchantId('m1'), CustomerId('c1')),
        isEmpty,
      );
      final balance = await ledger.getBalance(
        MerchantId('m1'),
        CustomerId('c1'),
        CurrencyCode.yemeniRial,
      );
      expect(balance.balanceMinorUnits, 0);
      expect(balance.currency, CurrencyCode.yemeniRial);
    });

    test('append of a mixed currency is independent per currency', () async {
      await ledger.append(entry(id: 'e1', currency: CurrencyCode.yemeniRial));
      await ledger.append(entry(id: 'e2', currency: CurrencyCode.saudiRiyal));
      expect(
        await ledger.getEntries(MerchantId('m1'), CustomerId('c1')),
        hasLength(2),
      );
      expect(
        (await ledger.getBalance(
          MerchantId('m1'),
          CustomerId('c1'),
          CurrencyCode.yemeniRial,
        ))
            .balanceMinorUnits,
        1000,
      );
      expect(
        (await ledger.getBalance(
          MerchantId('m1'),
          CustomerId('c1'),
          CurrencyCode.saudiRiyal,
        ))
            .balanceMinorUnits,
        1000,
      );
    });

    test('getBalance ignores entries in another currency', () async {
      await ledger.append(entry(currency: CurrencyCode.yemeniRial));
      final balance = await ledger.getBalance(
        MerchantId('m1'),
        CustomerId('c1'),
        CurrencyCode.saudiRiyal,
      );
      expect(balance.balanceMinorUnits, 0);
      expect(balance.currency, CurrencyCode.saudiRiyal);
    });

    test('merchant isolation is preserved', () async {
      await ledger.append(entry(merchant: 'm1', minorUnits: 1000));
      await ledger.append(
        entry(merchant: 'm2', minorUnits: 250),
      );
      expect(
        (await ledger.getBalance(
          MerchantId('m1'),
          CustomerId('c1'),
          CurrencyCode.yemeniRial,
        ))
            .balanceMinorUnits,
        1000,
      );
      expect(
        (await ledger.getBalance(
          MerchantId('m2'),
          CustomerId('c1'),
          CurrencyCode.yemeniRial,
        ))
            .balanceMinorUnits,
        250,
      );
      expect(
        await ledger.getEntries(MerchantId('m1'), CustomerId('c1')),
        hasLength(1),
      );
    });

    test('customer isolation is preserved', () async {
      await ledger.append(entry(customer: 'c1', minorUnits: 1000));
      await ledger.append(
        entry(id: 'e2', customer: 'c2', minorUnits: 400),
      );
      expect(
        (await ledger.getBalance(
          MerchantId('m1'),
          CustomerId('c1'),
          CurrencyCode.yemeniRial,
        ))
            .balanceMinorUnits,
        1000,
      );
      expect(
        (await ledger.getBalance(
          MerchantId('m1'),
          CustomerId('c2'),
          CurrencyCode.yemeniRial,
        ))
            .balanceMinorUnits,
        400,
      );
    });

    test('duplicate entry identity for one merchant is rejected', () async {
      await ledger.append(entry(id: 'e1', customer: 'c1'));
      expect(
        () => ledger.append(entry(id: 'e1', customer: 'c2')),
        throwsA(isA<DuplicateCustomerAccountEntryException>()),
      );
    });

    test('the same entry id may exist for different merchants', () async {
      await ledger.append(entry(id: 'e1', merchant: 'm1'));
      await ledger.append(entry(id: 'e1', merchant: 'm2'));
      expect(
        await ledger.getEntries(MerchantId('m1'), CustomerId('c1')),
        hasLength(1),
      );
      expect(
        await ledger.getEntries(MerchantId('m2'), CustomerId('c1')),
        hasLength(1),
      );
    });

    test('entries are append-only and preserved as stored', () async {
      final stored = entry(id: 'e1', reference: 'open');
      await ledger.append(stored);
      final found =
          (await ledger.getEntries(MerchantId('m1'), CustomerId('c1'))).single;
      expect(found, stored);
      expect(found.reference, 'open');
      expect(found.amount.minorUnits, 1000);
    });

    test('getEntries preserves append order', () async {
      await ledger.append(entry(id: 'e1'));
      await ledger.append(entry(id: 'e2'));
      await ledger.append(entry(id: 'e3'));
      final first = await ledger.getEntries(MerchantId('m1'), CustomerId('c1'));
      final second =
          await ledger.getEntries(MerchantId('m1'), CustomerId('c1'));
      expect(
        first.map((e) => e.id.value).toList(),
        <String>['e1', 'e2', 'e3'],
      );
      expect(
        second.map((e) => e.id.value).toList(),
        first.map((e) => e.id.value).toList(),
      );
    });

    test('getEntries result cannot mutate repository state', () async {
      await ledger.append(entry());
      final all = await ledger.getEntries(MerchantId('m1'), CustomerId('c1'));
      expect(() => all.add(entry(id: 'e2')), throwsUnsupportedError);
      expect(
        await ledger.getEntries(MerchantId('m1'), CustomerId('c1')),
        hasLength(1),
      );
    });

    test('missing customer throws CustomerNotFoundException on append',
        () async {
      expect(
        () => ledger.append(entry(customer: 'missing')),
        throwsA(isA<CustomerNotFoundException>()),
      );
    });

    test('missing customer throws CustomerNotFoundException on getEntries',
        () async {
      expect(
        () => ledger.getEntries(MerchantId('m1'), CustomerId('missing')),
        throwsA(isA<CustomerNotFoundException>()),
      );
    });

    test('missing customer throws CustomerNotFoundException on getBalance',
        () async {
      expect(
        () => ledger.getBalance(
          MerchantId('m1'),
          CustomerId('missing'),
          CurrencyCode.yemeniRial,
        ),
        throwsA(isA<CustomerNotFoundException>()),
      );
    });

    test('does not invent a zero balance for a customer that does not exist',
        () async {
      expect(
        () => ledger.getBalance(
          MerchantId('m3'),
          CustomerId('c1'),
          CurrencyCode.yemeniRial,
        ),
        throwsA(isA<CustomerNotFoundException>()),
      );
    });

    test('positive overflow is rejected', () async {
      await ledger.append(
        entry(
          id: 'e1',
          type: CustomerAccountEntryType.openingBalance,
          minorUnits: 9223372036854775807,
        ),
      );
      await ledger.append(
        entry(
          id: 'e2',
          type: CustomerAccountEntryType.credit,
          minorUnits: 1,
        ),
      );
      expect(
        () => ledger.getBalance(
          MerchantId('m1'),
          CustomerId('c1'),
          CurrencyCode.yemeniRial,
        ),
        throwsA(isA<LedgerBalanceOverflowException>()),
      );
    });

    test('negative overflow is rejected', () async {
      await ledger.append(
        entry(
          id: 'e1',
          type: CustomerAccountEntryType.payment,
          minorUnits: 9223372036854775807,
        ),
      );
      await ledger.append(
        entry(
          id: 'e2',
          type: CustomerAccountEntryType.payment,
          minorUnits: 2,
        ),
      );
      expect(
        () => ledger.getBalance(
          MerchantId('m1'),
          CustomerId('c1'),
          CurrencyCode.yemeniRial,
        ),
        throwsA(isA<LedgerBalanceOverflowException>()),
      );
    });
  });
}
