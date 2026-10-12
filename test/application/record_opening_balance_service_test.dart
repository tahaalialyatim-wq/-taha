import 'package:awtad_retail/awtad_retail.dart';
import 'package:test/test.dart';

void main() {
  late InMemoryRetailStore store;
  late RecordOpeningBalanceService service;

  final merchant = MerchantId('m1');
  final customerId = CustomerId('c1');
  final occurredAt = DateTime.utc(2026, 6, 1, 8);
  const yer500 = Money(currency: CurrencyCode.yemeniRial, minorUnits: 500);
  const sar200 = Money(currency: CurrencyCode.saudiRiyal, minorUnits: 200);

  setUp(() async {
    store = InMemoryRetailStore();
    service = RecordOpeningBalanceService.forStore(store);
    await store.customers.add(
      Customer(id: customerId, merchantId: merchant, name: 'Ali'),
    );
  });

  RecordOpeningBalanceCommand command({
    String id = 'e1',
    MerchantId? owner,
    CustomerId? customer,
    CurrencyCode currency = CurrencyCode.yemeniRial,
    Money? amount,
    DateTime? at,
    String? reference,
  }) =>
      RecordOpeningBalanceCommand(
        entryId: CustomerAccountEntryId(id),
        merchantId: owner ?? merchant,
        customerId: customer ?? customerId,
        currency: currency,
        amount: amount ?? yer500,
        occurredAt: at ?? occurredAt,
        reference: reference,
      );

  group('store wiring', () {
    test('forStore uses the store ledger', () {
      expect(identical(service.ledger, store.ledger), isTrue);
    });
  });

  group('successful opening balance', () {
    test('appends openingBalance as the first entry and increases debt',
        () async {
      final entry = await service.record(command(reference: 'brought-forward'));
      expect(entry.type, CustomerAccountEntryType.openingBalance);
      expect(entry.amount, yer500);
      expect(entry.currency, CurrencyCode.yemeniRial);
      expect(entry.reference, 'brought-forward');
      expect(await store.ledger.getById(merchant, entry.id), entry);
      final balance = await store.ledger.getBalance(
        merchant,
        customerId,
        CurrencyCode.yemeniRial,
      );
      expect(balance.balanceMinorUnits, 500);
      expect(balance.currency, CurrencyCode.yemeniRial);
    });

    test('opening balances in different currencies are independent', () async {
      await service.record(command());
      await service.record(
        command(
          id: 'e2',
          currency: CurrencyCode.saudiRiyal,
          amount: sar200,
        ),
      );
      expect(
        (await store.ledger.getBalance(
          merchant,
          customerId,
          CurrencyCode.yemeniRial,
        ))
            .balanceMinorUnits,
        500,
      );
      expect(
        (await store.ledger.getBalance(
          merchant,
          customerId,
          CurrencyCode.saudiRiyal,
        ))
            .balanceMinorUnits,
        200,
      );
    });
  });

  group('rejected opening balance', () {
    test('missing customer is rejected', () {
      expect(
        () => service.record(command(customer: CustomerId('missing'))),
        throwsA(isA<CustomerNotFoundException>()),
      );
    });

    test('amount currency mismatch is rejected before append', () {
      expect(
        () => service.record(
          command(
            currency: CurrencyCode.yemeniRial,
            amount: sar200,
          ),
        ),
        throwsArgumentError,
      );
    });

    test('zero amount is rejected', () {
      expect(
        () => service.record(
          command(
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
      await service.record(command());
      expect(
        () => service.record(command()),
        throwsA(isA<DuplicateCustomerAccountEntryException>()),
      );
    });

    test('second opening balance for the same currency is rejected', () async {
      await service.record(command());
      expect(
        () => service.record(command(id: 'e2')),
        throwsA(isA<DuplicateOpeningBalanceException>()),
      );
      expect(
        (await store.ledger.getEntries(merchant, customerId)),
        hasLength(1),
      );
    });

    test('opening balance after a credit is rejected', () async {
      await store.ledger.append(
        CustomerAccountEntry(
          id: CustomerAccountEntryId('credit-1'),
          merchantId: merchant,
          customerId: customerId,
          currency: CurrencyCode.yemeniRial,
          amount: yer500,
          type: CustomerAccountEntryType.credit,
          occurredAt: occurredAt,
        ),
      );
      expect(
        () => service.record(command()),
        throwsA(isA<OpeningBalanceNotFirstException>()),
      );
    });

    test('opening balance after a payment is rejected', () async {
      await store.ledger.append(
        CustomerAccountEntry(
          id: CustomerAccountEntryId('pay-1'),
          merchantId: merchant,
          customerId: customerId,
          currency: CurrencyCode.yemeniRial,
          amount: yer500,
          type: CustomerAccountEntryType.payment,
          occurredAt: occurredAt,
        ),
      );
      expect(
        () => service.record(command()),
        throwsA(isA<OpeningBalanceNotFirstException>()),
      );
    });
  });
}
