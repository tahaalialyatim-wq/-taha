import 'package:awtad_retail/awtad_retail.dart';
import 'package:test/test.dart';

class _RecordingUnitOfWork implements CompleteSaleUnitOfWork {
  @override
  Future<Sale> executeCompleteSale(
    MerchantId merchantId,
    Sale sale,
    List<InventoryDecrement> decrements,
  ) async {
    return sale;
  }
}

void main() {
  const yer100 = Money(currency: CurrencyCode.yemeniRial, minorUnits: 100);
  const yer250 = Money(currency: CurrencyCode.yemeniRial, minorUnits: 250);
  const sar100 = Money(currency: CurrencyCode.saudiRiyal, minorUnits: 100);

  late InMemoryRetailStore store;
  late MerchantInventoryRepository repository;
  late SaleRepository saleRepository;
  late MerchantInventoryService inventory;
  late CompleteSaleService sales;

  final merchant = MerchantId('m1');
  final other = MerchantId('m2');
  final p1 = ProductId('p1');
  final p2 = ProductId('p2');

  setUp(() {
    store = InMemoryRetailStore();
    repository = store.inventory;
    saleRepository = store.sales;
    inventory = MerchantInventoryService(repository);
    sales = CompleteSaleService.forStore(store);
  });

  Future<void> stock(
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

  CompleteSaleCommand command({
    String id = 'sale-1',
    MerchantId? owner,
    CurrencyCode currency = CurrencyCode.yemeniRial,
    required List<SaleCommandLine> lines,
  }) =>
      CompleteSaleCommand(
        saleId: SaleId(id),
        merchantId: owner ?? merchant,
        currency: currency,
        lines: lines,
      );

  group('CompleteSaleCommand', () {
    test('empty sale rejected', () {
      expect(
        () => command(lines: const <SaleCommandLine>[]),
        throwsArgumentError,
      );
    });

    test('zero quantity rejected', () {
      expect(
        () => SaleCommandLine(productId: p1, quantity: Quantity.zero),
        throwsArgumentError,
      );
    });

    test('negative quantity rejected', () {
      expect(() => Quantity.fromMilliUnits(-1), throwsArgumentError);
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

    test('caller mutation of command line list cannot mutate command', () {
      final input = <SaleCommandLine>[
        SaleCommandLine(
          productId: p1,
          quantity: Quantity.whole(1),
          unitSellingPrice: yer100,
        ),
      ];
      final cmd = command(lines: input);
      input.add(
        SaleCommandLine(
          productId: p2,
          quantity: Quantity.whole(1),
          unitSellingPrice: yer100,
        ),
      );
      expect(cmd.lines, hasLength(1));
      expect(() => cmd.lines.add(input.first), throwsUnsupportedError);
    });
  });

  group('store wiring', () {
    test('forStore uses the same inventory as the unit of work', () {
      expect(identical(sales.inventory, store.inventory), isTrue);
      expect(
        identical(
          (sales.unitOfWork as InMemoryCompleteSaleUnitOfWork).store,
          store,
        ),
        isTrue,
      );
    });

    test('standalone inventory with a store-backed UoW is rejected', () {
      expect(
        () => CompleteSaleService(
          inventory: InMemoryMerchantInventoryRepository(),
          unitOfWork: InMemoryCompleteSaleUnitOfWork(store),
        ),
        throwsArgumentError,
      );
    });

    test('inventory from a different RetailStore is rejected', () {
      expect(
        () => CompleteSaleService(
          inventory: InMemoryRetailStore().inventory,
          unitOfWork: InMemoryCompleteSaleUnitOfWork(store),
        ),
        throwsArgumentError,
      );
    });

    test('mismatched wiring cannot silently complete a sale', () async {
      final readStore = InMemoryRetailStore();
      final writeStore = InMemoryRetailStore();
      await MerchantInventoryService(readStore.inventory).addProduct(
        merchant,
        p1,
        quantity: Quantity.whole(5),
        sellingPrice: yer100,
      );
      expect(
        () => CompleteSaleService(
          inventory: readStore.inventory,
          unitOfWork: InMemoryCompleteSaleUnitOfWork(writeStore),
        ),
        throwsArgumentError,
      );
      expect(
        (await readStore.inventory.getByProduct(merchant, p1))!.quantity,
        Quantity.whole(5),
      );
      expect(await writeStore.sales.getAll(merchant), isEmpty);
      expect(await readStore.sales.getAll(merchant), isEmpty);
    });

    test('matching store inventory with store-backed UoW is accepted', () {
      expect(
        CompleteSaleService(
          inventory: store.inventory,
          unitOfWork: InMemoryCompleteSaleUnitOfWork(store),
        ),
        isA<CompleteSaleService>(),
      );
    });

    test('non-store UoW may use a standalone inventory for tests', () {
      expect(
        CompleteSaleService(
          inventory: InMemoryMerchantInventoryRepository(),
          unitOfWork: _RecordingUnitOfWork(),
        ),
        isA<CompleteSaleService>(),
      );
    });
  });

  group('price resolution', () {
    test('inventory sellingPrice is used when present', () async {
      await stock(p1, quantity: Quantity.whole(5), sellingPrice: yer250);
      final sale = await sales.complete(
        command(
          lines: <SaleCommandLine>[
            SaleCommandLine(productId: p1, quantity: Quantity.whole(1)),
          ],
        ),
      );
      expect(sale.lines.single.unitSellingPrice, yer250);
    });

    test('supplied command price is used when inventory has no sellingPrice',
        () async {
      await stock(p1, quantity: Quantity.whole(5));
      final sale = await sales.complete(
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
      expect(sale.lines.single.unitSellingPrice, yer100);
    });

    test('inventory sellingPrice takes precedence over supplied price',
        () async {
      await stock(p1, quantity: Quantity.whole(5), sellingPrice: yer250);
      final sale = await sales.complete(
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
    });

    test('missing price is rejected', () async {
      await stock(p1, quantity: Quantity.whole(5));
      expect(
        () => sales.complete(
          command(
            lines: <SaleCommandLine>[
              SaleCommandLine(productId: p1, quantity: Quantity.whole(1)),
            ],
          ),
        ),
        throwsArgumentError,
      );
      expect(
        (await inventory.findByProduct(merchant, p1))!.quantity,
        Quantity.whole(5),
      );
    });

    test('currency mismatch is rejected', () async {
      await stock(p1, quantity: Quantity.whole(5), sellingPrice: sar100);
      expect(
        () => sales.complete(
          command(
            lines: <SaleCommandLine>[
              SaleCommandLine(productId: p1, quantity: Quantity.whole(1)),
            ],
          ),
        ),
        throwsArgumentError,
      );
      expect(
        (await inventory.findByProduct(merchant, p1))!.quantity,
        Quantity.whole(5),
      );
    });
  });

  group('inventory validation', () {
    test('missing inventory item rejected', () async {
      expect(
        () => sales.complete(
          command(
            lines: <SaleCommandLine>[
              SaleCommandLine(
                productId: p1,
                quantity: Quantity.whole(1),
                unitSellingPrice: yer100,
              ),
            ],
          ),
        ),
        throwsA(isA<InventoryItemNotFoundException>()),
      );
    });

    test('insufficient stock rejected', () async {
      await stock(p1, quantity: Quantity.whole(2), sellingPrice: yer100);
      expect(
        () => sales.complete(
          command(
            lines: <SaleCommandLine>[
              SaleCommandLine(productId: p1, quantity: Quantity.whole(3)),
            ],
          ),
        ),
        throwsA(isA<InsufficientStockException>()),
      );
      expect(
        (await inventory.findByProduct(merchant, p1))!.quantity,
        Quantity.whole(2),
      );
    });

    test('exact-stock sale succeeds', () async {
      await stock(p1, quantity: Quantity.whole(4), sellingPrice: yer100);
      final sale = await sales.complete(
        command(
          lines: <SaleCommandLine>[
            SaleCommandLine(productId: p1, quantity: Quantity.whole(4)),
          ],
        ),
      );
      expect(sale.lines.single.quantity, Quantity.whole(4));
      expect(
        (await inventory.findByProduct(merchant, p1))!.quantity,
        Quantity.zero,
      );
    });

    test('fractional Quantity sale succeeds', () async {
      await stock(
        p1,
        quantity: Quantity.fromMilliUnits(1500),
        sellingPrice: yer250,
      );
      final sale = await sales.complete(
        command(
          lines: <SaleCommandLine>[
            SaleCommandLine(
              productId: p1,
              quantity: Quantity.fromMilliUnits(750),
            ),
          ],
        ),
      );
      expect(sale.lines.single.quantity, Quantity.fromMilliUnits(750));
      expect(
        sale.lines.single.lineTotal,
        const Money(currency: CurrencyCode.yemeniRial, minorUnits: 187),
      );
      expect(
        (await inventory.findByProduct(merchant, p1))!.quantity,
        Quantity.fromMilliUnits(750),
      );
    });

    test('merchant isolation preserved', () async {
      await stock(p1, quantity: Quantity.whole(6), sellingPrice: yer100);
      await stock(
        p1,
        quantity: Quantity.whole(6),
        sellingPrice: yer100,
        owner: other,
      );
      await sales.complete(
        command(
          lines: <SaleCommandLine>[
            SaleCommandLine(productId: p1, quantity: Quantity.whole(2)),
          ],
        ),
      );
      expect(
        (await inventory.findByProduct(merchant, p1))!.quantity,
        Quantity.whole(4),
      );
      expect(
        (await inventory.findByProduct(other, p1))!.quantity,
        Quantity.whole(6),
      );
    });
  });

  group('atomicity', () {
    test('multi-line sale succeeds and decrements every line exactly once',
        () async {
      await stock(p1, quantity: Quantity.whole(10), sellingPrice: yer100);
      await stock(p2, quantity: Quantity.whole(8), sellingPrice: yer250);
      final sale = await sales.complete(
        command(
          lines: <SaleCommandLine>[
            SaleCommandLine(productId: p1, quantity: Quantity.whole(3)),
            SaleCommandLine(productId: p2, quantity: Quantity.whole(2)),
          ],
        ),
      );
      expect(sale.lines, hasLength(2));
      expect(
        (await inventory.findByProduct(merchant, p1))!.quantity,
        Quantity.whole(7),
      );
      expect(
        (await inventory.findByProduct(merchant, p2))!.quantity,
        Quantity.whole(6),
      );
    });

    test('one insufficient line causes ZERO inventory changes to every line',
        () async {
      await stock(p1, quantity: Quantity.whole(10), sellingPrice: yer100);
      await stock(p2, quantity: Quantity.whole(1), sellingPrice: yer250);
      expect(
        () => sales.complete(
          command(
            lines: <SaleCommandLine>[
              SaleCommandLine(productId: p1, quantity: Quantity.whole(2)),
              SaleCommandLine(productId: p2, quantity: Quantity.whole(5)),
            ],
          ),
        ),
        throwsA(isA<InsufficientStockException>()),
      );
      expect(
        (await inventory.findByProduct(merchant, p1))!.quantity,
        Quantity.whole(10),
      );
      expect(
        (await inventory.findByProduct(merchant, p2))!.quantity,
        Quantity.whole(1),
      );
    });

    test('validation failure causes ZERO inventory changes', () async {
      await stock(p1, quantity: Quantity.whole(10), sellingPrice: yer100);
      expect(
        () => sales.complete(
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
        Quantity.whole(10),
      );
    });

    test('unrelated inventory fields remain unchanged', () async {
      await stock(
        p1,
        quantity: Quantity.whole(8),
        sellingPrice: yer250,
        purchasePrice: yer100,
        minimumStock: Quantity.whole(2),
      );
      await sales.complete(
        command(
          lines: <SaleCommandLine>[
            SaleCommandLine(productId: p1, quantity: Quantity.whole(1)),
          ],
        ),
      );
      final item = (await inventory.findByProduct(merchant, p1))!;
      expect(item.sellingPrice, yer250);
      expect(item.purchasePrice, yer100);
      expect(item.minimumStock, Quantity.whole(2));
      expect(item.merchantId, merchant);
      expect(item.productId, p1);
      expect(item.quantity, Quantity.whole(7));
    });

    test('repeated successful sales decrement correctly', () async {
      await stock(p1, quantity: Quantity.whole(10), sellingPrice: yer100);
      await sales.complete(
        command(
          id: 'sale-1',
          lines: <SaleCommandLine>[
            SaleCommandLine(productId: p1, quantity: Quantity.whole(3)),
          ],
        ),
      );
      await sales.complete(
        command(
          id: 'sale-2',
          lines: <SaleCommandLine>[
            SaleCommandLine(productId: p1, quantity: Quantity.whole(2)),
          ],
        ),
      );
      expect(
        (await inventory.findByProduct(merchant, p1))!.quantity,
        Quantity.whole(5),
      );
    });
  });

  group('sale result', () {
    test('returned Sale has requested SaleId, MerchantId and CurrencyCode',
        () async {
      await stock(p1, quantity: Quantity.whole(5), sellingPrice: yer100);
      final sale = await sales.complete(
        command(
          id: 'sale-99',
          lines: <SaleCommandLine>[
            SaleCommandLine(productId: p1, quantity: Quantity.whole(1)),
          ],
        ),
      );
      expect(sale.id, SaleId('sale-99'));
      expect(sale.merchantId, merchant);
      expect(sale.currency, CurrencyCode.yemeniRial);
    });

    test('returned Sale contains resolved SaleLines with correct totals',
        () async {
      await stock(p1, quantity: Quantity.whole(5), sellingPrice: yer250);
      await stock(p2, quantity: Quantity.whole(5));
      final sale = await sales.complete(
        command(
          lines: <SaleCommandLine>[
            SaleCommandLine(productId: p1, quantity: Quantity.whole(2)),
            SaleCommandLine(
              productId: p2,
              quantity: Quantity.whole(3),
              unitSellingPrice: yer100,
            ),
          ],
        ),
      );
      expect(sale.lines, hasLength(2));
      expect(sale.lines[0].productId, p1);
      expect(sale.lines[0].unitSellingPrice, yer250);
      expect(
        sale.lines[0].lineTotal,
        const Money(currency: CurrencyCode.yemeniRial, minorUnits: 500),
      );
      expect(sale.lines[1].productId, p2);
      expect(sale.lines[1].unitSellingPrice, yer100);
      expect(
        sale.lines[1].lineTotal,
        const Money(currency: CurrencyCode.yemeniRial, minorUnits: 300),
      );
    });

    test('returned Sale lines are immutable', () async {
      await stock(p1, quantity: Quantity.whole(5), sellingPrice: yer100);
      final sale = await sales.complete(
        command(
          lines: <SaleCommandLine>[
            SaleCommandLine(productId: p1, quantity: Quantity.whole(1)),
          ],
        ),
      );
      expect(
        () => sale.lines.add(
          SaleLine(
            productId: p2,
            quantity: Quantity.whole(1),
            unitSellingPrice: yer100,
          ),
        ),
        throwsUnsupportedError,
      );
    });
  });

  group('persistence coordination', () {
    test('successful complete sale persists Sale and decrements inventory',
        () async {
      await stock(p1, quantity: Quantity.whole(5), sellingPrice: yer100);
      final sale = await sales.complete(
        command(
          lines: <SaleCommandLine>[
            SaleCommandLine(productId: p1, quantity: Quantity.whole(2)),
          ],
        ),
      );
      final persisted =
          await saleRepository.getById(merchant, SaleId('sale-1'));
      expect(persisted, sale);
      expect(
        (await inventory.findByProduct(merchant, p1))!.quantity,
        Quantity.whole(3),
      );
    });

    test('validation failure causes no inventory mutation and no Sale',
        () async {
      await stock(p1, quantity: Quantity.whole(5), sellingPrice: yer100);
      expect(
        () => sales.complete(
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
      expect(await saleRepository.getAll(merchant), isEmpty);
    });

    test('duplicate SaleId is rejected before inventory mutation', () async {
      await stock(p1, quantity: Quantity.whole(5), sellingPrice: yer100);
      await sales.complete(
        command(
          lines: <SaleCommandLine>[
            SaleCommandLine(productId: p1, quantity: Quantity.whole(1)),
          ],
        ),
      );
      expect(
        () => sales.complete(
          command(
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
      expect(await saleRepository.getAll(merchant), hasLength(1));
    });

    test('returned Sale is exactly the persisted Sale', () async {
      await stock(p1, quantity: Quantity.whole(5), sellingPrice: yer100);
      final sale = await sales.complete(
        command(
          lines: <SaleCommandLine>[
            SaleCommandLine(productId: p1, quantity: Quantity.whole(1)),
          ],
        ),
      );
      expect(await saleRepository.getById(merchant, sale.id), sale);
    });

    test('merchant A cannot collide with merchant B SaleId', () async {
      await stock(p1, quantity: Quantity.whole(5), sellingPrice: yer100);
      await stock(
        p1,
        quantity: Quantity.whole(5),
        sellingPrice: yer100,
        owner: other,
      );
      await sales.complete(
        command(
          lines: <SaleCommandLine>[
            SaleCommandLine(productId: p1, quantity: Quantity.whole(1)),
          ],
        ),
      );
      final otherSale = await sales.complete(
        command(
          owner: other,
          lines: <SaleCommandLine>[
            SaleCommandLine(productId: p1, quantity: Quantity.whole(1)),
          ],
        ),
      );
      expect(otherSale.id, SaleId('sale-1'));
      expect(await saleRepository.getAll(merchant), hasLength(1));
      expect(await saleRepository.getAll(other), hasLength(1));
    });

    test('persisted Sale remains immutable', () async {
      await stock(p1, quantity: Quantity.whole(5), sellingPrice: yer100);
      await sales.complete(
        command(
          lines: <SaleCommandLine>[
            SaleCommandLine(productId: p1, quantity: Quantity.whole(1)),
          ],
        ),
      );
      final persisted =
          await saleRepository.getById(merchant, SaleId('sale-1'));
      expect(
        () => persisted!.lines.add(
          SaleLine(
            productId: p2,
            quantity: Quantity.whole(1),
            unitSellingPrice: yer100,
          ),
        ),
        throwsUnsupportedError,
      );
    });
  });
}
