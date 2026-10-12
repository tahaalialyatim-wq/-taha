import 'package:awtad_retail/awtad_retail.dart';
import 'package:test/test.dart';

void main() {
  late InMemoryRetailStore store;
  late RecordCustomerPaymentService payments;
  late RecordOpeningBalanceService openings;

  final merchant = MerchantId('m1');
  final customerId = CustomerId('c1');
  final occurredAt = DateTime.utc(2026, 6, 2, 10);
  const yer1000 = Money(currency: CurrencyCode.yemeniRial, minorUnits: 1000);
  const yer400 = Money(currency: CurrencyCode.yemeniRial, minorUnits: 400);
  const yer1500 = Money(currency: CurrencyCode.yemeniRial, minorUnits: 1500);
  const sar100 = Money(currency: CurrencyCode.saudiRiyal, minorUnits: 100);

  setUp(() async {
    store = InMemoryRetailStore();
    payments = RecordCustomerPaymentService.forStore(store);
    openings = RecordOpeningBalanceService.forStore(store);
    await store.customers.add(
      Customer(id: customerId, merchantId: merchant, name: 'Ali'),
    );
  });

  RecordCustomerPaymentCommand payment({
    String id = 'p1',
    MerchantId? owner,
    CustomerId? customer,
    CurrencyCode currency = CurrencyCode.yemeniRial,
    Money? amount,
    DateTime? at,
    String? reference,
  }) =>
      RecordCustomerPaymentCommand(
        entryId: CustomerAccountEntryId(id),
        merchantId: owner ?? merchant,
        customerId: customer ?? customerId,
        currency: currency,
        amount: amount ?? yer400,
        occurredAt: at ?? occurredAt,
        reference: reference,
      );

  group('store wiring', () {
    test('forStore uses the store ledger', () {
      expect(identical(payments.ledger, store.ledger), isTrue);
    });
  });

  group('successful payment', () {
    test('decreases outstanding debt after an opening balance', () async {
      await openings.record(
        RecordOpeningBalanceCommand(
          entryId: CustomerAccountEntryId('ob1'),
          merchantId: merchant,
          customerId: customerId,
          currency: CurrencyCode.yemeniRial,
          amount: yer1000,
          occurredAt: occurredAt,
        ),
      );
      final entry = await payments.record(payment(reference: 'cash'));
      expect(entry.type, CustomerAccountEntryType.payment);
      expect(entry.amount, yer400);
      expect(entry.reference, 'cash');
      final balance = await store.ledger.getBalance(
        merchant,
        customerId,
        CurrencyCode.yemeniRial,
      );
      expect(balance.balanceMinorUnits, 600);
    });

    test('overpayment is stored as a customer credit, not an advance type',
        () async {
      await openings.record(
        RecordOpeningBalanceCommand(
          entryId: CustomerAccountEntryId('ob1'),
          merchantId: merchant,
          customerId: customerId,
          currency: CurrencyCode.yemeniRial,
          amount: yer1000,
          occurredAt: occurredAt,
        ),
      );
      final entry = await payments.record(payment(amount: yer1500));
      expect(entry.type, CustomerAccountEntryType.payment);
      expect(entry.type, isNot(CustomerAccountEntryType.credit));
      expect(entry.type.value, 'payment');
      final balance = await store.ledger.getBalance(
        merchant,
        customerId,
        CurrencyCode.yemeniRial,
      );
      expect(balance.balanceMinorUnits, -500);
    });

    test('payment with no prior debt is accepted as a customer credit',
        () async {
      await payments.record(payment());
      final balance = await store.ledger.getBalance(
        merchant,
        customerId,
        CurrencyCode.yemeniRial,
      );
      expect(balance.balanceMinorUnits, -400);
      final entries = await store.ledger.getEntries(merchant, customerId);
      expect(entries.single.type, CustomerAccountEntryType.payment);
    });

    test('payments in different currencies are independent', () async {
      await payments.record(payment());
      await payments.record(
        payment(
          id: 'p2',
          currency: CurrencyCode.saudiRiyal,
          amount: sar100,
        ),
      );
      expect(
        (await store.ledger.getBalance(
          merchant,
          customerId,
          CurrencyCode.yemeniRial,
        ))
            .balanceMinorUnits,
        -400,
      );
      expect(
        (await store.ledger.getBalance(
          merchant,
          customerId,
          CurrencyCode.saudiRiyal,
        ))
            .balanceMinorUnits,
        -100,
      );
    });
  });

  group('rejected payment', () {
    test('missing customer is rejected', () {
      expect(
        () => payments.record(payment(customer: CustomerId('missing'))),
        throwsA(isA<CustomerNotFoundException>()),
      );
    });

    test('amount currency mismatch is rejected before append', () {
      expect(
        () => payments.record(
          payment(
            currency: CurrencyCode.yemeniRial,
            amount: sar100,
          ),
        ),
        throwsArgumentError,
      );
    });

    test('zero amount is rejected', () {
      expect(
        () => payments.record(
          payment(
            amount: const Money(
              currency: CurrencyCode.yemeniRial,
              minorUnits: 0,
            ),
          ),
        ),
        throwsArgumentError,
      );
    });

    test('duplicate entry id is rejected', () async {
      await payments.record(payment());
      expect(
        () => payments.record(payment()),
        throwsA(isA<DuplicateCustomerAccountEntryException>()),
      );
      expect(
        (await store.ledger.getEntries(merchant, customerId)),
        hasLength(1),
      );
    });
  });
}
