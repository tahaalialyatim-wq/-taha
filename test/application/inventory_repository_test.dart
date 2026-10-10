import 'package:awtad_retail/awtad_retail.dart';
import 'package:test/test.dart';

MerchantInventoryItem item(
  String merchant,
  String product, {
  String? id,
  Quantity? quantity,
}) =>
    MerchantInventoryItem(
      id: InventoryItemId(id ?? '$merchant:$product'),
      merchantId: MerchantId(merchant),
      productId: ProductId(product),
      quantity: quantity ?? Quantity.zero,
    );

void main() {
  late InMemoryMerchantInventoryRepository repository;

  setUp(() {
    repository = InMemoryMerchantInventoryRepository();
  });

  group('InMemoryMerchantInventoryRepository', () {
    test('adds and reads an item', () async {
      final added = await repository.add(item('m1', 'p1'));
      final found = await repository.getById(
        MerchantId('m1'),
        InventoryItemId('m1:p1'),
      );
      expect(found, added);
    });

    test('getAll returns an unmodifiable snapshot', () async {
      await repository.add(item('m1', 'p1'));
      await repository.add(item('m1', 'p2'));
      final all = await repository.getAll(MerchantId('m1'));
      expect(all, hasLength(2));
      expect(() => all.add(item('m1', 'p3')), throwsUnsupportedError);
    });

    test('duplicate MerchantId + ProductId is rejected', () async {
      await repository.add(item('m1', 'p1', id: 'a'));
      expect(
        () => repository.add(item('m1', 'p1', id: 'b')),
        throwsA(isA<DuplicateInventoryItemException>()),
      );
    });

    test('same product for different merchants is allowed', () async {
      await repository.add(item('m1', 'p1', id: 'a'));
      await repository.add(item('m2', 'p1', id: 'b'));
      expect(await repository.getByProduct(MerchantId('m2'), ProductId('p1')),
          isNotNull);
    });

    test('wrong merchant reads return null/false', () async {
      await repository.add(item('m1', 'p1'));
      expect(
        await repository.getById(MerchantId('m2'), InventoryItemId('m1:p1')),
        isNull,
      );
      expect(
        await repository.getByProduct(MerchantId('m2'), ProductId('p1')),
        isNull,
      );
      expect(
        await repository.exists(MerchantId('m2'), InventoryItemId('m1:p1')),
        isFalse,
      );
    });

    test('wrong merchant update throws MerchantMismatchException', () async {
      await repository.add(item('m1', 'p1'));
      expect(
        () => repository.update(item('m2', 'p1', id: 'm1:p1')),
        throwsA(isA<MerchantMismatchException>()),
      );
    });

    test('wrong merchant quantity mutation throws MerchantMismatchException',
        () async {
      await repository.add(item('m1', 'p1'));
      expect(
        () => repository.updateQuantity(
          MerchantId('m2'),
          InventoryItemId('m1:p1'),
          Quantity.whole(2),
        ),
        throwsA(isA<MerchantMismatchException>()),
      );
    });

    test('missing item mutation throws InventoryItemNotFoundException',
        () async {
      expect(
        () => repository.updateQuantity(
          MerchantId('m1'),
          InventoryItemId('missing'),
          Quantity.whole(1),
        ),
        throwsA(isA<InventoryItemNotFoundException>()),
      );
      expect(
        () => repository.update(item('m1', 'p1', id: 'missing')),
        throwsA(isA<InventoryItemNotFoundException>()),
      );
    });

    test('updateQuantity is atomic at the repository boundary', () async {
      await repository.add(item('m1', 'p1'));
      final updated = await repository.updateQuantity(
        MerchantId('m1'),
        InventoryItemId('m1:p1'),
        Quantity.whole(7),
      );
      expect(updated.quantity, Quantity.whole(7));
      final reread = await repository.getById(
        MerchantId('m1'),
        InventoryItemId('m1:p1'),
      );
      expect(reread!.quantity, Quantity.whole(7));
    });

    test('remove returns false for missing and true when removed', () async {
      expect(
        await repository.remove(MerchantId('m1'), InventoryItemId('missing')),
        isFalse,
      );
      await repository.add(item('m1', 'p1'));
      expect(
        await repository.remove(MerchantId('m1'), InventoryItemId('m1:p1')),
        isTrue,
      );
      expect(
        await repository.getById(MerchantId('m1'), InventoryItemId('m1:p1')),
        isNull,
      );
    });

    test('remove for the wrong merchant throws', () async {
      await repository.add(item('m1', 'p1'));
      expect(
        () => repository.remove(MerchantId('m2'), InventoryItemId('m1:p1')),
        throwsA(isA<MerchantMismatchException>()),
      );
    });

    test('decrementQuantity deducts a valid amount', () async {
      await repository.add(item('m1', 'p1', quantity: Quantity.whole(10)));
      await repository.decrementQuantity(
        MerchantId('m1'),
        InventoryItemId('m1:p1'),
        Quantity.whole(3),
      );
      final remaining = await repository.getById(
        MerchantId('m1'),
        InventoryItemId('m1:p1'),
      );
      expect(remaining!.quantity, Quantity.whole(7));
    });

    test('decrementQuantity can reduce stock to exactly zero', () async {
      await repository.add(item('m1', 'p1', quantity: Quantity.whole(4)));
      await repository.decrementQuantity(
        MerchantId('m1'),
        InventoryItemId('m1:p1'),
        Quantity.whole(4),
      );
      final remaining = await repository.getById(
        MerchantId('m1'),
        InventoryItemId('m1:p1'),
      );
      expect(remaining!.quantity, Quantity.zero);
    });

    test('decrementQuantity greater than available throws', () async {
      await repository.add(item('m1', 'p1', quantity: Quantity.whole(2)));
      expect(
        () => repository.decrementQuantity(
          MerchantId('m1'),
          InventoryItemId('m1:p1'),
          Quantity.whole(3),
        ),
        throwsA(isA<InsufficientStockException>()),
      );
      final remaining = await repository.getById(
        MerchantId('m1'),
        InventoryItemId('m1:p1'),
      );
      expect(remaining!.quantity, Quantity.whole(2));
    });

    test('decrementQuantity of zero is rejected', () async {
      await repository.add(item('m1', 'p1', quantity: Quantity.whole(2)));
      expect(
        () => repository.decrementQuantity(
          MerchantId('m1'),
          InventoryItemId('m1:p1'),
          Quantity.zero,
        ),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('decrementQuantity of a negative amount is rejected', () async {
      expect(() => Quantity.fromMilliUnits(-1), throwsArgumentError);
    });

    test('decrementQuantity of a missing item throws', () async {
      expect(
        () => repository.decrementQuantity(
          MerchantId('m1'),
          InventoryItemId('missing'),
          Quantity.whole(1),
        ),
        throwsA(isA<InventoryItemNotFoundException>()),
      );
    });

    test('decrementQuantity for the wrong merchant throws', () async {
      await repository.add(item('m1', 'p1', quantity: Quantity.whole(5)));
      expect(
        () => repository.decrementQuantity(
          MerchantId('m2'),
          InventoryItemId('m1:p1'),
          Quantity.whole(1),
        ),
        throwsA(isA<MerchantMismatchException>()),
      );
    });

    test('decrementQuantity preserves unrelated item fields', () async {
      final added = await repository.add(
        MerchantInventoryItem(
          id: InventoryItemId('m1:p1'),
          merchantId: MerchantId('m1'),
          productId: ProductId('p1'),
          quantity: Quantity.whole(8),
          sellingPrice: const Money(
            currency: CurrencyCode.yemeniRial,
            minorUnits: 250,
          ),
          purchasePrice: const Money(
            currency: CurrencyCode.yemeniRial,
            minorUnits: 180,
          ),
          minimumStock: Quantity.whole(2),
        ),
      );
      await repository.decrementQuantity(
        MerchantId('m1'),
        InventoryItemId('m1:p1'),
        Quantity.whole(1),
      );
      final remaining = await repository.getById(
        MerchantId('m1'),
        InventoryItemId('m1:p1'),
      );
      expect(remaining!.id, added.id);
      expect(remaining.merchantId, added.merchantId);
      expect(remaining.productId, added.productId);
      expect(remaining.sellingPrice, added.sellingPrice);
      expect(remaining.purchasePrice, added.purchasePrice);
      expect(remaining.minimumStock, added.minimumStock);
      expect(remaining.quantity, Quantity.whole(7));
    });

    test('decrementQuantity does not affect another merchant', () async {
      await repository.add(item('m1', 'p1', quantity: Quantity.whole(6)));
      await repository.add(
        item('m2', 'p1', id: 'm2:p1', quantity: Quantity.whole(6)),
      );
      await repository.decrementQuantity(
        MerchantId('m1'),
        InventoryItemId('m1:p1'),
        Quantity.whole(2),
      );
      expect(
        (await repository.getById(MerchantId('m1'), InventoryItemId('m1:p1')))!
            .quantity,
        Quantity.whole(4),
      );
      expect(
        (await repository.getById(MerchantId('m2'), InventoryItemId('m2:p1')))!
            .quantity,
        Quantity.whole(6),
      );
    });

    test('decrementQuantity does not mutate a previously read item', () async {
      await repository.add(item('m1', 'p1', quantity: Quantity.whole(9)));
      final before = await repository.getById(
        MerchantId('m1'),
        InventoryItemId('m1:p1'),
      );
      await repository.decrementQuantity(
        MerchantId('m1'),
        InventoryItemId('m1:p1'),
        Quantity.whole(4),
      );
      expect(before!.quantity, Quantity.whole(9));
      final after = await repository.getById(
        MerchantId('m1'),
        InventoryItemId('m1:p1'),
      );
      expect(after!.quantity, Quantity.whole(5));
      expect(identical(before, after), isFalse);
    });

    test('repeated decrementQuantity yields the remaining quantity', () async {
      await repository.add(item('m1', 'p1', quantity: Quantity.whole(10)));
      await repository.decrementQuantity(
        MerchantId('m1'),
        InventoryItemId('m1:p1'),
        Quantity.whole(3),
      );
      await repository.decrementQuantity(
        MerchantId('m1'),
        InventoryItemId('m1:p1'),
        Quantity.whole(2),
      );
      final remaining = await repository.getById(
        MerchantId('m1'),
        InventoryItemId('m1:p1'),
      );
      expect(remaining!.quantity, Quantity.whole(5));
    });

    test('decrementQuantities validates all items before mutation', () async {
      await repository.add(item('m1', 'p1', quantity: Quantity.whole(10)));
      await repository.add(item('m1', 'p2', quantity: Quantity.whole(1)));
      expect(
        () => repository.decrementQuantities(
          MerchantId('m1'),
          <InventoryDecrement>[
            InventoryDecrement(
              inventoryItemId: InventoryItemId('m1:p1'),
              amount: Quantity.whole(2),
            ),
            InventoryDecrement(
              inventoryItemId: InventoryItemId('m1:p2'),
              amount: Quantity.whole(5),
            ),
          ],
        ),
        throwsA(isA<InsufficientStockException>()),
      );
      expect(
        (await repository.getById(MerchantId('m1'), InventoryItemId('m1:p1')))!
            .quantity,
        Quantity.whole(10),
      );
      expect(
        (await repository.getById(MerchantId('m1'), InventoryItemId('m1:p2')))!
            .quantity,
        Quantity.whole(1),
      );
    });

    test('decrementQuantities preserves single-item decrement behavior',
        () async {
      await repository.add(item('m1', 'p1', quantity: Quantity.whole(10)));
      await repository.decrementQuantity(
        MerchantId('m1'),
        InventoryItemId('m1:p1'),
        Quantity.whole(3),
      );
      expect(
        (await repository.getById(MerchantId('m1'), InventoryItemId('m1:p1')))!
            .quantity,
        Quantity.whole(7),
      );
      await repository.decrementQuantities(
        MerchantId('m1'),
        <InventoryDecrement>[
          InventoryDecrement(
            inventoryItemId: InventoryItemId('m1:p1'),
            amount: Quantity.whole(2),
          ),
        ],
      );
      expect(
        (await repository.getById(MerchantId('m1'), InventoryItemId('m1:p1')))!
            .quantity,
        Quantity.whole(5),
      );
    });

    test('decrementQuantities cannot produce negative stock', () async {
      await repository.add(item('m1', 'p1', quantity: Quantity.whole(4)));
      expect(
        () => repository.decrementQuantities(
          MerchantId('m1'),
          <InventoryDecrement>[
            InventoryDecrement(
              inventoryItemId: InventoryItemId('m1:p1'),
              amount: Quantity.whole(5),
            ),
          ],
        ),
        throwsA(isA<InsufficientStockException>()),
      );
      expect(
        (await repository.getById(MerchantId('m1'), InventoryItemId('m1:p1')))!
            .quantity,
        Quantity.whole(4),
      );
    });
  });
}
