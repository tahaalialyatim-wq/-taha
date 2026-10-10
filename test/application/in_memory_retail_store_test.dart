import 'package:awtad_retail/awtad_retail.dart';
import 'package:test/test.dart';

class _RejectingRetailStore implements RetailStore {
  _RejectingRetailStore(this._inner);

  final RetailStore _inner;
  Object? thrown;

  @override
  MerchantInventoryRepository get inventory => _inner.inventory;

  @override
  SaleRepository get sales => _inner.sales;

  @override
  CustomerRepository get customers => _inner.customers;

  @override
  CustomerAccountLedgerRepository get ledger => _inner.ledger;

  @override
  void commit(RetailWrites writes) {
    thrown = StateError('commit planning rejected');
    throw thrown!;
  }
}

void main() {
  const yer100 = Money(currency: CurrencyCode.yemeniRial, minorUnits: 100);
  final occurredAt = DateTime.utc(2026, 4, 1);

  late InMemoryRetailStore store;
  late MerchantInventoryService stock;

  final merchant = MerchantId('m1');
  final other = MerchantId('m2');
  final p1 = ProductId('p1');
  final p2 = ProductId('p2');
  final customerId = CustomerId('c1');

  setUp(() {
    store = InMemoryRetailStore();
    stock = MerchantInventoryService(store.inventory);
  });

  Future<void> addStock(
    ProductId product, {
    required Quantity quantity,
    MerchantId? owner,
    Money? sellingPrice,
    Money? purchasePrice,
    Quantity? minimumStock,
  }) {
    return stock.addProduct(
      owner ?? merchant,
      product,
      quantity: quantity,
      sellingPrice: sellingPrice ?? yer100,
      purchasePrice: purchasePrice,
      minimumStock: minimumStock,
    );
  }

  Future<void> addCustomer({
    CustomerId? id,
    MerchantId? owner,
    String name = 'Ali',
  }) {
    return store.customers.add(
      Customer(
        id: id ?? customerId,
        merchantId: owner ?? merchant,
        name: name,
      ),
    );
  }

  SaleLine line({String product = 'p1', Quantity? quantity}) => SaleLine(
        productId: ProductId(product),
        quantity: quantity ?? Quantity.whole(1),
        unitSellingPrice: yer100,
      );

  Sale sale({
    String id = 's1',
    MerchantId? owner,
    List<SaleLine>? lines,
    CustomerId? customer,
  }) =>
      Sale(
        id: SaleId(id),
        merchantId: owner ?? merchant,
        currency: CurrencyCode.yemeniRial,
        lines: lines ?? <SaleLine>[line()],
        customerId: customer,
      );

  CustomerAccountEntry credit({
    String id = 'e1',
    MerchantId? owner,
    CustomerId? customer,
    int minorUnits = 100,
    CustomerAccountEntryType type = CustomerAccountEntryType.credit,
  }) =>
      CustomerAccountEntry(
        id: CustomerAccountEntryId(id),
        merchantId: owner ?? merchant,
        customerId: customer ?? customerId,
        currency: CurrencyCode.yemeniRial,
        amount: Money(
          currency: CurrencyCode.yemeniRial,
          minorUnits: minorUnits,
        ),
        type: type,
        occurredAt: occurredAt,
        reference: 's1',
      );

  group('InMemoryRetailStore.commit', () {
    test('successful cash commit decrements inventory and persists Sale',
        () async {
      await addStock(p1, quantity: Quantity.whole(10));
      await addStock(p2, quantity: Quantity.whole(8));
      final item1 = (await stock.findByProduct(merchant, p1))!;
      final item2 = (await stock.findByProduct(merchant, p2))!;
      final committed = sale(
        lines: <SaleLine>[
          line(quantity: Quantity.whole(3)),
          line(product: 'p2', quantity: Quantity.whole(2)),
        ],
      );
      store.commit(
        RetailWrites(
          merchantId: merchant,
          sale: committed,
          decrements: <InventoryDecrement>[
            InventoryDecrement(
              inventoryItemId: item1.id,
              amount: Quantity.whole(3),
            ),
            InventoryDecrement(
              inventoryItemId: item2.id,
              amount: Quantity.whole(2),
            ),
          ],
        ),
      );
      expect(await store.sales.getById(merchant, SaleId('s1')), committed);
      expect(
        (await stock.findByProduct(merchant, p1))!.quantity,
        Quantity.whole(7),
      );
      expect(
        (await stock.findByProduct(merchant, p2))!.quantity,
        Quantity.whole(6),
      );
      expect(await store.ledger.getById(merchant, CustomerAccountEntryId('e1')),
          isNull);
    });

    test('insufficient stock leaves inventory, sales and ledger unchanged',
        () async {
      await addStock(p1, quantity: Quantity.whole(10));
      await addStock(p2, quantity: Quantity.whole(1));
      await addCustomer();
      final item1 = (await stock.findByProduct(merchant, p1))!;
      final item2 = (await stock.findByProduct(merchant, p2))!;
      expect(
        () => store.commit(
          RetailWrites(
            merchantId: merchant,
            sale: sale(
              lines: <SaleLine>[
                line(quantity: Quantity.whole(2)),
                line(product: 'p2', quantity: Quantity.whole(5)),
              ],
            ),
            decrements: <InventoryDecrement>[
              InventoryDecrement(
                inventoryItemId: item1.id,
                amount: Quantity.whole(2),
              ),
              InventoryDecrement(
                inventoryItemId: item2.id,
                amount: Quantity.whole(5),
              ),
            ],
            ledgerEntry: credit(minorUnits: 700),
          ),
        ),
        throwsA(isA<InsufficientStockException>()),
      );
      expect(await store.sales.getAll(merchant), isEmpty);
      expect(
        (await stock.findByProduct(merchant, p1))!.quantity,
        Quantity.whole(10),
      );
      expect(
        (await stock.findByProduct(merchant, p2))!.quantity,
        Quantity.whole(1),
      );
      expect(await store.ledger.getEntries(merchant, customerId), isEmpty);
    });

    test('duplicate sale leaves inventory, sales and ledger unchanged',
        () async {
      await addStock(p1, quantity: Quantity.whole(5));
      await addCustomer();
      final item = (await stock.findByProduct(merchant, p1))!;
      store.commit(
        RetailWrites(
          merchantId: merchant,
          sale: sale(),
          decrements: <InventoryDecrement>[
            InventoryDecrement(
              inventoryItemId: item.id,
              amount: Quantity.whole(1),
            ),
          ],
        ),
      );
      expect(
        () => store.commit(
          RetailWrites(
            merchantId: merchant,
            sale: sale(),
            decrements: <InventoryDecrement>[
              InventoryDecrement(
                inventoryItemId: item.id,
                amount: Quantity.whole(1),
              ),
            ],
            ledgerEntry: credit(),
          ),
        ),
        throwsA(isA<DuplicateSaleException>()),
      );
      expect(await store.sales.getAll(merchant), hasLength(1));
      expect(
        (await stock.findByProduct(merchant, p1))!.quantity,
        Quantity.whole(4),
      );
      expect(await store.ledger.getEntries(merchant, customerId), isEmpty);
    });

    test('missing customer ledger write leaves inventory and sales unchanged',
        () async {
      await addStock(p1, quantity: Quantity.whole(5));
      final item = (await stock.findByProduct(merchant, p1))!;
      expect(
        () => store.commit(
          RetailWrites(
            merchantId: merchant,
            sale: sale(customer: customerId),
            decrements: <InventoryDecrement>[
              InventoryDecrement(
                inventoryItemId: item.id,
                amount: Quantity.whole(1),
              ),
            ],
            ledgerEntry: credit(),
          ),
        ),
        throwsA(isA<CustomerNotFoundException>()),
      );
      expect(await store.sales.getAll(merchant), isEmpty);
      expect(
        (await stock.findByProduct(merchant, p1))!.quantity,
        Quantity.whole(5),
      );
    });

    test('duplicate ledger identity leaves inventory and sales unchanged',
        () async {
      await addStock(p1, quantity: Quantity.whole(5));
      await addCustomer();
      await store.ledger.append(credit());
      final item = (await stock.findByProduct(merchant, p1))!;
      expect(
        () => store.commit(
          RetailWrites(
            merchantId: merchant,
            sale: sale(customer: customerId),
            decrements: <InventoryDecrement>[
              InventoryDecrement(
                inventoryItemId: item.id,
                amount: Quantity.whole(1),
              ),
            ],
            ledgerEntry: credit(),
          ),
        ),
        throwsA(isA<DuplicateCustomerAccountEntryException>()),
      );
      expect(await store.sales.getAll(merchant), isEmpty);
      expect(
        (await stock.findByProduct(merchant, p1))!.quantity,
        Quantity.whole(5),
      );
      expect(await store.ledger.getEntries(merchant, customerId), hasLength(1));
    });

    test('opening-balance-not-first leaves inventory and sales unchanged',
        () async {
      await addStock(p1, quantity: Quantity.whole(5));
      await addCustomer();
      await store.ledger.append(credit());
      final item = (await stock.findByProduct(merchant, p1))!;
      expect(
        () => store.commit(
          RetailWrites(
            merchantId: merchant,
            sale: sale(customer: customerId),
            decrements: <InventoryDecrement>[
              InventoryDecrement(
                inventoryItemId: item.id,
                amount: Quantity.whole(1),
              ),
            ],
            ledgerEntry: credit(
              id: 'e2',
              type: CustomerAccountEntryType.openingBalance,
            ),
          ),
        ),
        throwsA(isA<OpeningBalanceNotFirstException>()),
      );
      expect(await store.sales.getAll(merchant), isEmpty);
      expect(
        (await stock.findByProduct(merchant, p1))!.quantity,
        Quantity.whole(5),
      );
      expect(await store.ledger.getEntries(merchant, customerId), hasLength(1));
    });

    test('injected commit failure leaves inventory, sales and ledger unchanged',
        () async {
      await addStock(p1, quantity: Quantity.whole(5));
      await addCustomer();
      final item = (await stock.findByProduct(merchant, p1))!;
      final rejecting = _RejectingRetailStore(store);
      expect(
        () => rejecting.commit(
          RetailWrites(
            merchantId: merchant,
            sale: sale(customer: customerId),
            decrements: <InventoryDecrement>[
              InventoryDecrement(
                inventoryItemId: item.id,
                amount: Quantity.whole(1),
              ),
            ],
            ledgerEntry: credit(),
          ),
        ),
        throwsA(isA<StateError>()),
      );
      expect(await store.sales.getAll(merchant), isEmpty);
      expect(
        (await stock.findByProduct(merchant, p1))!.quantity,
        Quantity.whole(5),
      );
      expect(await store.ledger.getEntries(merchant, customerId), isEmpty);
    });

    test('successful commit after a prior failure publishes the next snapshot',
        () async {
      await addStock(p1, quantity: Quantity.whole(5));
      final item = (await stock.findByProduct(merchant, p1))!;
      expect(
        () => store.commit(
          RetailWrites(
            merchantId: merchant,
            sale: sale(),
            decrements: <InventoryDecrement>[
              InventoryDecrement(
                inventoryItemId: item.id,
                amount: Quantity.whole(9),
              ),
            ],
          ),
        ),
        throwsA(isA<InsufficientStockException>()),
      );
      final committed = sale();
      store.commit(
        RetailWrites(
          merchantId: merchant,
          sale: committed,
          decrements: <InventoryDecrement>[
            InventoryDecrement(
              inventoryItemId: item.id,
              amount: Quantity.whole(2),
            ),
          ],
        ),
      );
      expect(await store.sales.getById(merchant, SaleId('s1')), committed);
      expect(
        (await stock.findByProduct(merchant, p1))!.quantity,
        Quantity.whole(3),
      );
    });

    test('all views from one store observe the same published snapshot',
        () async {
      await addStock(p1, quantity: Quantity.whole(6));
      await addCustomer();
      final item = (await stock.findByProduct(merchant, p1))!;
      final committed = sale(customer: customerId);
      final entry = credit();
      store.commit(
        RetailWrites(
          merchantId: merchant,
          sale: committed,
          decrements: <InventoryDecrement>[
            InventoryDecrement(
              inventoryItemId: item.id,
              amount: Quantity.whole(2),
            ),
          ],
          ledgerEntry: entry,
        ),
      );
      expect(
        (await store.inventory.getByProduct(merchant, p1))!.quantity,
        Quantity.whole(4),
      );
      expect(await store.sales.getById(merchant, SaleId('s1')), committed);
      expect(await store.customers.getById(merchant, customerId), isNotNull);
      expect(await store.ledger.getById(merchant, CustomerAccountEntryId('e1')),
          entry);
      final balance = await store.ledger.getBalance(
        merchant,
        customerId,
        CurrencyCode.yemeniRial,
      );
      expect(balance.balanceMinorUnits, 100);
    });

    test('merchant isolation is preserved across commit', () async {
      await addStock(p1, quantity: Quantity.whole(6));
      await addStock(p1, quantity: Quantity.whole(6), owner: other);
      await addCustomer();
      await addCustomer(owner: other, name: 'Other');
      final item = (await stock.findByProduct(merchant, p1))!;
      store.commit(
        RetailWrites(
          merchantId: merchant,
          sale: sale(customer: customerId),
          decrements: <InventoryDecrement>[
            InventoryDecrement(
              inventoryItemId: item.id,
              amount: Quantity.whole(2),
            ),
          ],
          ledgerEntry: credit(),
        ),
      );
      expect(
        (await stock.findByProduct(merchant, p1))!.quantity,
        Quantity.whole(4),
      );
      expect(
        (await stock.findByProduct(other, p1))!.quantity,
        Quantity.whole(6),
      );
      expect(await store.sales.getAll(other), isEmpty);
      expect(await store.ledger.getEntries(other, customerId), isEmpty);
    });

    test('ledger merchant mismatch leaves inventory and sales unchanged',
        () async {
      await addStock(p1, quantity: Quantity.whole(5));
      await addCustomer();
      final item = (await stock.findByProduct(merchant, p1))!;
      expect(
        () => store.commit(
          RetailWrites(
            merchantId: merchant,
            sale: sale(customer: customerId),
            decrements: <InventoryDecrement>[
              InventoryDecrement(
                inventoryItemId: item.id,
                amount: Quantity.whole(1),
              ),
            ],
            ledgerEntry: credit(owner: other),
          ),
        ),
        throwsA(isA<MerchantMismatchException>()),
      );
      expect(await store.sales.getAll(merchant), isEmpty);
      expect(
        (await stock.findByProduct(merchant, p1))!.quantity,
        Quantity.whole(5),
      );
    });
  });
}
