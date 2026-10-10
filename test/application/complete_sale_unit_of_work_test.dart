import 'package:awtad_retail/awtad_retail.dart';
import 'package:test/test.dart';

class _RecordingUnitOfWork implements CompleteSaleUnitOfWork {
  int calls = 0;
  Sale? lastSale;
  List<InventoryDecrement>? lastDecrements;

  @override
  Future<Sale> executeCompleteSale(
    MerchantId merchantId,
    Sale sale,
    List<InventoryDecrement> decrements,
  ) async {
    calls += 1;
    lastSale = sale;
    lastDecrements = decrements;
    return sale;
  }
}

void main() {
  const yer100 = Money(currency: CurrencyCode.yemeniRial, minorUnits: 100);

  late InMemoryRetailStore store;
  late MerchantInventoryRepository inventory;
  late SaleRepository sales;
  late InMemoryCompleteSaleUnitOfWork unitOfWork;
  late MerchantInventoryService stock;

  final merchant = MerchantId('m1');
  final other = MerchantId('m2');
  final p1 = ProductId('p1');
  final p2 = ProductId('p2');

  setUp(() {
    store = InMemoryRetailStore();
    inventory = store.inventory;
    sales = store.sales;
    unitOfWork = InMemoryCompleteSaleUnitOfWork(store);
    stock = MerchantInventoryService(inventory);
  });

  SaleLine line({String product = 'p1', Quantity? quantity}) => SaleLine(
        productId: ProductId(product),
        quantity: quantity ?? Quantity.whole(1),
        unitSellingPrice: yer100,
      );

  Sale sale({
    String id = 's1',
    MerchantId? owner,
    List<SaleLine>? lines,
  }) =>
      Sale(
        id: SaleId(id),
        merchantId: owner ?? merchant,
        currency: CurrencyCode.yemeniRial,
        lines: lines ?? <SaleLine>[line()],
      );

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

  group('InMemoryCompleteSaleUnitOfWork', () {
    test('multi-line sale commits inventory changes and Sale together',
        () async {
      await addStock(p1, quantity: Quantity.whole(10));
      await addStock(p2, quantity: Quantity.whole(8));
      final item1 = (await stock.findByProduct(merchant, p1))!;
      final item2 = (await stock.findByProduct(merchant, p2))!;
      final committed = await unitOfWork.executeCompleteSale(
        merchant,
        sale(
          lines: <SaleLine>[
            line(quantity: Quantity.whole(3)),
            line(product: 'p2', quantity: Quantity.whole(2)),
          ],
        ),
        <InventoryDecrement>[
          InventoryDecrement(
            inventoryItemId: item1.id,
            amount: Quantity.whole(3),
          ),
          InventoryDecrement(
            inventoryItemId: item2.id,
            amount: Quantity.whole(2),
          ),
        ],
      );
      expect(await sales.getById(merchant, SaleId('s1')), committed);
      expect(
        (await stock.findByProduct(merchant, p1))!.quantity,
        Quantity.whole(7),
      );
      expect(
        (await stock.findByProduct(merchant, p2))!.quantity,
        Quantity.whole(6),
      );
    });

    test('one insufficient line causes zero inventory mutation and no Sale',
        () async {
      await addStock(p1, quantity: Quantity.whole(10));
      await addStock(p2, quantity: Quantity.whole(1));
      final item1 = (await stock.findByProduct(merchant, p1))!;
      final item2 = (await stock.findByProduct(merchant, p2))!;
      expect(
        () => unitOfWork.executeCompleteSale(
          merchant,
          sale(
            lines: <SaleLine>[
              line(quantity: Quantity.whole(2)),
              line(product: 'p2', quantity: Quantity.whole(5)),
            ],
          ),
          <InventoryDecrement>[
            InventoryDecrement(
              inventoryItemId: item1.id,
              amount: Quantity.whole(2),
            ),
            InventoryDecrement(
              inventoryItemId: item2.id,
              amount: Quantity.whole(5),
            ),
          ],
        ),
        throwsA(isA<InsufficientStockException>()),
      );
      expect(await sales.getAll(merchant), isEmpty);
      expect(
        (await stock.findByProduct(merchant, p1))!.quantity,
        Quantity.whole(10),
      );
      expect(
        (await stock.findByProduct(merchant, p2))!.quantity,
        Quantity.whole(1),
      );
    });

    test('duplicate SaleId is rejected before inventory mutation', () async {
      await addStock(p1, quantity: Quantity.whole(5));
      final item = (await stock.findByProduct(merchant, p1))!;
      await unitOfWork.executeCompleteSale(
        merchant,
        sale(),
        <InventoryDecrement>[
          InventoryDecrement(
            inventoryItemId: item.id,
            amount: Quantity.whole(1),
          ),
        ],
      );
      expect(
        () => unitOfWork.executeCompleteSale(
          merchant,
          sale(lines: <SaleLine>[line(quantity: Quantity.whole(2))]),
          <InventoryDecrement>[
            InventoryDecrement(
              inventoryItemId: item.id,
              amount: Quantity.whole(2),
            ),
          ],
        ),
        throwsA(isA<DuplicateSaleException>()),
      );
      expect(await sales.getAll(merchant), hasLength(1));
      expect(
        (await stock.findByProduct(merchant, p1))!.quantity,
        Quantity.whole(4),
      );
    });

    test('duplicate Sale already in store causes zero inventory mutation',
        () async {
      await addStock(p1, quantity: Quantity.whole(5));
      final item = (await stock.findByProduct(merchant, p1))!;
      await sales.add(sale());
      expect(
        () => unitOfWork.executeCompleteSale(
          merchant,
          sale(),
          <InventoryDecrement>[
            InventoryDecrement(
              inventoryItemId: item.id,
              amount: Quantity.whole(1),
            ),
          ],
        ),
        throwsA(isA<DuplicateSaleException>()),
      );
      expect(
        (await stock.findByProduct(merchant, p1))!.quantity,
        Quantity.whole(5),
      );
    });

    test('unrelated inventory fields remain unchanged', () async {
      await addStock(
        p1,
        quantity: Quantity.whole(8),
        purchasePrice: yer100,
        minimumStock: Quantity.whole(2),
      );
      final item = (await stock.findByProduct(merchant, p1))!;
      await unitOfWork.executeCompleteSale(
        merchant,
        sale(),
        <InventoryDecrement>[
          InventoryDecrement(
            inventoryItemId: item.id,
            amount: Quantity.whole(1),
          ),
        ],
      );
      final remaining = (await stock.findByProduct(merchant, p1))!;
      expect(remaining.sellingPrice, yer100);
      expect(remaining.purchasePrice, yer100);
      expect(remaining.minimumStock, Quantity.whole(2));
      expect(remaining.quantity, Quantity.whole(7));
    });

    test('merchant isolation is preserved', () async {
      await addStock(p1, quantity: Quantity.whole(6));
      await addStock(p1, quantity: Quantity.whole(6), owner: other);
      final item = (await stock.findByProduct(merchant, p1))!;
      await unitOfWork.executeCompleteSale(
        merchant,
        sale(),
        <InventoryDecrement>[
          InventoryDecrement(
            inventoryItemId: item.id,
            amount: Quantity.whole(2),
          ),
        ],
      );
      expect(
        (await stock.findByProduct(merchant, p1))!.quantity,
        Quantity.whole(4),
      );
      expect(
        (await stock.findByProduct(other, p1))!.quantity,
        Quantity.whole(6),
      );
      expect(await sales.getAll(other), isEmpty);
    });
  });

  group('CompleteSaleService coordination', () {
    test('uses the unit-of-work rather than mutating repositories directly',
        () async {
      await addStock(p1, quantity: Quantity.whole(5));
      final recording = _RecordingUnitOfWork();
      final service = CompleteSaleService(
        inventory: inventory,
        unitOfWork: recording,
      );
      final completed = await service.complete(
        CompleteSaleCommand(
          saleId: SaleId('s1'),
          merchantId: merchant,
          currency: CurrencyCode.yemeniRial,
          lines: <SaleCommandLine>[
            SaleCommandLine(productId: p1, quantity: Quantity.whole(1)),
          ],
        ),
      );
      expect(recording.calls, 1);
      expect(recording.lastSale, completed);
      expect(recording.lastDecrements, isNotNull);
      expect(recording.lastDecrements, hasLength(1));
      expect(
        (await stock.findByProduct(merchant, p1))!.quantity,
        Quantity.whole(5),
      );
      expect(await sales.getAll(merchant), isEmpty);
    });
  });
}
