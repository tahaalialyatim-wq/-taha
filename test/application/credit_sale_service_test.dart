import 'package:awtad_retail/awtad_retail.dart';
import 'package:test/test.dart';

class _RecordingCreditUnitOfWork implements CreditSaleUnitOfWork {
  int calls = 0;
  Sale? lastSale;
  List<InventoryDecrement>? lastDecrements;
  CustomerAccountEntry? lastEntry;

  @override
  Future<Sale> executeCreditSale(
    MerchantId merchantId,
    Sale sale,
    List<InventoryDecrement> decrements,
    CustomerAccountEntry ledgerEntry,
  ) async {
    calls += 1;
    lastSale = sale;
    lastDecrements = decrements;
    lastEntry = ledgerEntry;
    return sale;
  }
}

void main() {
  const yer100 = Money(currency: CurrencyCode.yemeniRial, minorUnits: 100);
  const yer250 = Money(currency: CurrencyCode.yemeniRial, minorUnits: 250);
  const sar100 = Money(currency: CurrencyCode.saudiRiyal, minorUnits: 100);
  final occurredAt = DateTime.utc(2026, 5, 1, 9);

  late InMemoryRetailStore store;
  late MerchantInventoryService inventory;
  late CreditSaleService creditSales;
  late CompleteSaleService cashSales;

  final merchant = MerchantId('m1');
  final other = MerchantId('m2');
  final p1 = ProductId('p1');
  final p2 = ProductId('p2');
  final customerId = CustomerId('c1');

  setUp(() {
    store = InMemoryRetailStore();
    inventory = MerchantInventoryService(store.inventory);
    creditSales = CreditSaleService.forStore(store);
    cashSales = CompleteSaleService.forStore(store);
  });

  Future<void> addStock(
    ProductId product, {
    required Quantity quantity,
    Money? sellingPrice,
    MerchantId? owner,
    Money? purchasePrice,
    Quantity? minimumStock,
  }) {
    return inventory.addProduct(
      owner ?? merchant,
      product,
      quantity: quantity,
      sellingPrice: sellingPrice,
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

  CreditSaleCommand command({
    String id = 'sale-1',
    String entryId = 'e1',
    MerchantId? owner,
    CustomerId? customer,
    CurrencyCode currency = CurrencyCode.yemeniRial,
    DateTime? at,
    required List<SaleCommandLine> lines,
  }) =>
      CreditSaleCommand(
        saleId: SaleId(id),
        merchantId: owner ?? merchant,
        customerId: customer ?? customerId,
        ledgerEntryId: CustomerAccountEntryId(entryId),
        currency: currency,
        occurredAt: at ?? occurredAt,
        lines: lines,
      );

  group('CreditSaleCommand', () {
    test('empty sale rejected', () {
      expect(
        () => command(lines: const <SaleCommandLine>[]),
        throwsArgumentError,
      );
    });

    test('duplicate ProductId rejected', () {
      expect(
        () => command(
          lines: <SaleCommandLine>[
            SaleCommandLine(
              productId: p1,
              quantity: Quantity.whole(1),
              unitSellingPrice: yer100,
            ),
            SaleCommandLine(
              productId: p1,
              quantity: Quantity.whole(2),
              unitSellingPrice: yer100,
            ),
          ],
        ),
        throwsArgumentError,
      );
    });
  });

  group('store wiring', () {
    test('forStore uses the same inventory and customers as the unit of work',
        () {
      expect(identical(creditSales.inventory, store.inventory), isTrue);
      expect(identical(creditSales.customers, store.customers), isTrue);
      expect(
        identical(
          (creditSales.unitOfWork as InMemoryCreditSaleUnitOfWork).store,
          store,
        ),
        isTrue,
      );
    });

    test('standalone inventory with a store-backed UoW is rejected', () {
      expect(
        () => CreditSaleService(
          inventory: InMemoryMerchantInventoryRepository(),
          customers: store.customers,
          unitOfWork: InMemoryCreditSaleUnitOfWork(store),
        ),
        throwsArgumentError,
      );
    });

    test('standalone customers with a store-backed UoW is rejected', () {
      expect(
        () => CreditSaleService(
          inventory: store.inventory,
          customers: InMemoryCustomerRepository(),
          unitOfWork: InMemoryCreditSaleUnitOfWork(store),
        ),
        throwsArgumentError,
      );
    });

    test('non-store UoW may use injected repositories for tests', () {
      expect(
        CreditSaleService(
          inventory: InMemoryMerchantInventoryRepository(),
          customers: InMemoryCustomerRepository(),
          unitOfWork: _RecordingCreditUnitOfWork(),
        ),
        isA<CreditSaleService>(),
      );
    });
  });

  group('successful credit sale', () {
    test('persists Sale, decrements stock, and appends one matching credit',
        () async {
      await addStock(p1, quantity: Quantity.whole(5), sellingPrice: yer100);
      await addStock(p2, quantity: Quantity.whole(8), sellingPrice: yer250);
      await addCustomer();
      final sale = await creditSales.complete(
        command(
          lines: <SaleCommandLine>[
            SaleCommandLine(productId: p1, quantity: Quantity.whole(2)),
            SaleCommandLine(productId: p2, quantity: Quantity.whole(1)),
          ],
        ),
      );
      expect(sale.id, SaleId('sale-1'));
      expect(sale.merchantId, merchant);
      expect(sale.customerId, customerId);
      expect(sale.currency, CurrencyCode.yemeniRial);
      expect(
        sale.total,
        const Money(currency: CurrencyCode.yemeniRial, minorUnits: 450),
      );
      expect(await store.sales.getById(merchant, sale.id), sale);
      expect(
        (await inventory.findByProduct(merchant, p1))!.quantity,
        Quantity.whole(3),
      );
      expect(
        (await inventory.findByProduct(merchant, p2))!.quantity,
        Quantity.whole(7),
      );
      final entries = await store.ledger.getEntries(merchant, customerId);
      expect(entries, hasLength(1));
      expect(entries.single.id, CustomerAccountEntryId('e1'));
      expect(entries.single.type, CustomerAccountEntryType.credit);
      expect(entries.single.amount, sale.total);
      expect(entries.single.currency, CurrencyCode.yemeniRial);
      expect(entries.single.customerId, customerId);
      expect(entries.single.occurredAt, occurredAt);
      expect(entries.single.reference, 'sale-1');
      final balance = await store.ledger.getBalance(
        merchant,
        customerId,
        CurrencyCode.yemeniRial,
      );
      expect(balance.balanceMinorUnits, 450);
    });

    test('inventory sellingPrice takes precedence over command price',
        () async {
      await addStock(p1, quantity: Quantity.whole(5), sellingPrice: yer250);
      await addCustomer();
      final sale = await creditSales.complete(
        command(
          lines: <SaleCommandLine>[
            SaleCommandLine(
              productId: p1,
              quantity: Quantity.whole(1),
              unitSellingPrice: yer100,
            ),
          ],
        ),
      );
      expect(sale.lines.single.unitSellingPrice, yer250);
      expect(sale.total, yer250);
      final entries = await store.ledger.getEntries(merchant, customerId);
      expect(entries.single.amount, yer250);
    });

    test('command price is used when inventory has no sellingPrice', () async {
      await addStock(p1, quantity: Quantity.whole(5));
      await addCustomer();
      final sale = await creditSales.complete(
        command(
          lines: <SaleCommandLine>[
            SaleCommandLine(
              productId: p1,
              quantity: Quantity.whole(2),
              unitSellingPrice: yer100,
            ),
          ],
        ),
      );
      expect(sale.total.minorUnits, 200);
    });

    test('balance increases by exactly the sale total', () async {
      await addStock(p1, quantity: Quantity.whole(10), sellingPrice: yer100);
      await addCustomer();
      await store.ledger.append(
        CustomerAccountEntry(
          id: CustomerAccountEntryId('open'),
          merchantId: merchant,
          customerId: customerId,
          currency: CurrencyCode.yemeniRial,
          amount: const Money(
            currency: CurrencyCode.yemeniRial,
            minorUnits: 300,
          ),
          type: CustomerAccountEntryType.openingBalance,
          occurredAt: occurredAt,
        ),
      );
      final sale = await creditSales.complete(
        command(
          lines: <SaleCommandLine>[
            SaleCommandLine(productId: p1, quantity: Quantity.whole(2)),
          ],
        ),
      );
      final balance = await store.ledger.getBalance(
        merchant,
        customerId,
        CurrencyCode.yemeniRial,
      );
      expect(balance.balanceMinorUnits, 300 + sale.total.minorUnits);
    });

    test('does not change another merchant inventory, sales or ledger',
        () async {
      await addStock(p1, quantity: Quantity.whole(5), sellingPrice: yer100);
      await addStock(
        p1,
        quantity: Quantity.whole(5),
        sellingPrice: yer100,
        owner: other,
      );
      await addCustomer();
      await addCustomer(owner: other, name: 'Other');
      await creditSales.complete(
        command(
          lines: <SaleCommandLine>[
            SaleCommandLine(productId: p1, quantity: Quantity.whole(1)),
          ],
        ),
      );
      expect(
        (await inventory.findByProduct(other, p1))!.quantity,
        Quantity.whole(5),
      );
      expect(await store.sales.getAll(other), isEmpty);
      expect(await store.ledger.getEntries(other, customerId), isEmpty);
    });
  });

  group('failures leave inventory, sales and ledger unchanged', () {
    Future<void> expectUnchanged({
      required Quantity stock,
      required Matcher matcher,
      required CreditSaleCommand cmd,
    }) async {
      expect(() => creditSales.complete(cmd), matcher);
      expect(
        (await inventory.findByProduct(merchant, p1))!.quantity,
        stock,
      );
      expect(await store.sales.getAll(merchant), isEmpty);
      if (await store.customers.exists(merchant, customerId)) {
        expect(await store.ledger.getEntries(merchant, customerId), isEmpty);
      }
    }

    test('missing customer', () async {
      await addStock(p1, quantity: Quantity.whole(5), sellingPrice: yer100);
      await expectUnchanged(
        stock: Quantity.whole(5),
        matcher: throwsA(isA<CustomerNotFoundException>()),
        cmd: command(
          lines: <SaleCommandLine>[
            SaleCommandLine(productId: p1, quantity: Quantity.whole(1)),
          ],
        ),
      );
    });

    test('cross-merchant customer', () async {
      await addStock(p1, quantity: Quantity.whole(5), sellingPrice: yer100);
      await addCustomer(owner: other, name: 'Other');
      await expectUnchanged(
        stock: Quantity.whole(5),
        matcher: throwsA(isA<CustomerNotFoundException>()),
        cmd: command(
          lines: <SaleCommandLine>[
            SaleCommandLine(productId: p1, quantity: Quantity.whole(1)),
          ],
        ),
      );
      expect(await store.sales.getAll(other), isEmpty);
      expect(await store.ledger.getEntries(other, customerId), isEmpty);
      expect(
        (await inventory.findByProduct(other, p1)),
        isNull,
      );
    });

    test('insufficient stock', () async {
      await addStock(p1, quantity: Quantity.whole(2), sellingPrice: yer100);
      await addCustomer();
      await expectUnchanged(
        stock: Quantity.whole(2),
        matcher: throwsA(isA<InsufficientStockException>()),
        cmd: command(
          lines: <SaleCommandLine>[
            SaleCommandLine(productId: p1, quantity: Quantity.whole(3)),
          ],
        ),
      );
    });

    test('currency mismatch', () async {
      await addStock(p1, quantity: Quantity.whole(5), sellingPrice: sar100);
      await addCustomer();
      await expectUnchanged(
        stock: Quantity.whole(5),
        matcher: throwsArgumentError,
        cmd: command(
          lines: <SaleCommandLine>[
            SaleCommandLine(productId: p1, quantity: Quantity.whole(1)),
          ],
        ),
      );
    });

    test('missing inventory item', () async {
      await addStock(p1, quantity: Quantity.whole(5), sellingPrice: yer100);
      await addCustomer();
      expect(
        () => creditSales.complete(
          command(
            lines: <SaleCommandLine>[
              SaleCommandLine(productId: p1, quantity: Quantity.whole(1)),
              SaleCommandLine(
                productId: p2,
                quantity: Quantity.whole(1),
                unitSellingPrice: yer100,
              ),
            ],
          ),
        ),
        throwsA(isA<InventoryItemNotFoundException>()),
      );
      expect(
        (await inventory.findByProduct(merchant, p1))!.quantity,
        Quantity.whole(5),
      );
      expect(await store.sales.getAll(merchant), isEmpty);
      expect(await store.ledger.getEntries(merchant, customerId), isEmpty);
    });

    test('duplicate SaleId', () async {
      await addStock(p1, quantity: Quantity.whole(5), sellingPrice: yer100);
      await addCustomer();
      await creditSales.complete(
        command(
          lines: <SaleCommandLine>[
            SaleCommandLine(productId: p1, quantity: Quantity.whole(1)),
          ],
        ),
      );
      expect(
        () => creditSales.complete(
          command(
            entryId: 'e2',
            lines: <SaleCommandLine>[
              SaleCommandLine(productId: p1, quantity: Quantity.whole(1)),
            ],
          ),
        ),
        throwsA(isA<DuplicateSaleException>()),
      );
      expect(
        (await inventory.findByProduct(merchant, p1))!.quantity,
        Quantity.whole(4),
      );
      expect(await store.sales.getAll(merchant), hasLength(1));
      expect(await store.ledger.getEntries(merchant, customerId), hasLength(1));
    });

    test('duplicate ledger entry id', () async {
      await addStock(p1, quantity: Quantity.whole(5), sellingPrice: yer100);
      await addCustomer();
      await store.ledger.append(
        CustomerAccountEntry(
          id: CustomerAccountEntryId('e1'),
          merchantId: merchant,
          customerId: customerId,
          currency: CurrencyCode.yemeniRial,
          amount: yer100,
          type: CustomerAccountEntryType.credit,
          occurredAt: occurredAt,
        ),
      );
      expect(
        () => creditSales.complete(
          command(
            lines: <SaleCommandLine>[
              SaleCommandLine(productId: p1, quantity: Quantity.whole(1)),
            ],
          ),
        ),
        throwsA(isA<DuplicateCustomerAccountEntryException>()),
      );
      expect(
        (await inventory.findByProduct(merchant, p1))!.quantity,
        Quantity.whole(5),
      );
      expect(await store.sales.getAll(merchant), isEmpty);
      expect(await store.ledger.getEntries(merchant, customerId), hasLength(1));
    });

    test('missing price', () async {
      await addStock(p1, quantity: Quantity.whole(5));
      await addCustomer();
      await expectUnchanged(
        stock: Quantity.whole(5),
        matcher: throwsArgumentError,
        cmd: command(
          lines: <SaleCommandLine>[
            SaleCommandLine(productId: p1, quantity: Quantity.whole(1)),
          ],
        ),
      );
    });
  });

  group('cash sale remains unchanged', () {
    test('cash sale still commits without a ledger entry', () async {
      await addStock(p1, quantity: Quantity.whole(5), sellingPrice: yer100);
      await addCustomer();
      final sale = await cashSales.complete(
        CompleteSaleCommand(
          saleId: SaleId('cash-1'),
          merchantId: merchant,
          currency: CurrencyCode.yemeniRial,
          lines: <SaleCommandLine>[
            SaleCommandLine(productId: p1, quantity: Quantity.whole(1)),
          ],
        ),
      );
      expect(sale.customerId, isNull);
      expect(await store.sales.getById(merchant, SaleId('cash-1')), sale);
      expect(await store.ledger.getEntries(merchant, customerId), isEmpty);
      expect(
        (await inventory.findByProduct(merchant, p1))!.quantity,
        Quantity.whole(4),
      );
    });
  });

  group('CreditSaleService coordination', () {
    test('uses the unit-of-work rather than mutating repositories directly',
        () async {
      await addStock(p1, quantity: Quantity.whole(5), sellingPrice: yer100);
      await addCustomer();
      final recording = _RecordingCreditUnitOfWork();
      final service = CreditSaleService(
        inventory: store.inventory,
        customers: store.customers,
        unitOfWork: recording,
      );
      final completed = await service.complete(
        command(
          lines: <SaleCommandLine>[
            SaleCommandLine(productId: p1, quantity: Quantity.whole(1)),
          ],
        ),
      );
      expect(recording.calls, 1);
      expect(recording.lastSale, completed);
      expect(recording.lastSale!.customerId, customerId);
      expect(recording.lastDecrements, hasLength(1));
      expect(recording.lastEntry!.amount, completed.total);
      expect(recording.lastEntry!.type, CustomerAccountEntryType.credit);
      expect(
        (await inventory.findByProduct(merchant, p1))!.quantity,
        Quantity.whole(5),
      );
      expect(await store.sales.getAll(merchant), isEmpty);
      expect(await store.ledger.getEntries(merchant, customerId), isEmpty);
    });
  });

  group('purchase cost snapshot', () {
    test('credit sales snapshot the inventory purchase cost', () async {
      const cost = Money(
        currency: CurrencyCode.yemeniRial,
        minorUnits: 60,
      );
      await addStock(
        p1,
        quantity: Quantity.whole(5),
        sellingPrice: yer100,
        purchasePrice: cost,
      );
      await addCustomer();
      final sale = await creditSales.complete(
        command(
          lines: <SaleCommandLine>[
            SaleCommandLine(productId: p1, quantity: Quantity.whole(2)),
          ],
        ),
      );
      expect(sale.lines.single.unitPurchaseCost, cost);
      expect(
        sale.lines.single.grossProfit,
        const Money(currency: CurrencyCode.yemeniRial, minorUnits: 80),
      );
    });

    test('foreign purchase-cost currency leaves profit unknown', () async {
      await addStock(
        p1,
        quantity: Quantity.whole(5),
        sellingPrice: yer100,
        purchasePrice: sar100,
      );
      await addCustomer();
      final sale = await creditSales.complete(
        command(
          lines: <SaleCommandLine>[
            SaleCommandLine(productId: p1, quantity: Quantity.whole(1)),
          ],
        ),
      );
      expect(sale.lines.single.unitPurchaseCost, sar100);
      expect(sale.lines.single.grossProfit, isNull);
    });
  });
}
