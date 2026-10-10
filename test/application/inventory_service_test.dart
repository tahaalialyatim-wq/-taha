import 'package:awtad_retail/awtad_retail.dart';
import 'package:test/test.dart';

void main() {
  late MerchantInventoryService service;

  setUp(() {
    service = MerchantInventoryService(InMemoryMerchantInventoryRepository());
  });

  final merchant = MerchantId('m1');
  final product = ProductId('p1');

  group('MerchantInventoryService', () {
    test('addProduct creates merchant-owned inventory using MerchantId',
        () async {
      final created = await service.addProduct(merchant, product);
      expect(created.merchantId, merchant);
      expect(created.productId, product);
      expect(created.quantity, Quantity.zero);
      expect(created.id, MerchantInventoryService.idFor(merchant, product));
    });

    test('findByProduct is product-scoped', () async {
      await service.addProduct(merchant, product, quantity: Quantity.whole(4));
      final found = await service.findByProduct(merchant, product);
      expect(found, isNotNull);
      expect(found!.quantity, Quantity.whole(4));
      expect(await service.findByProduct(merchant, ProductId('nope')), isNull);
    });

    test('duplicate add is rejected', () async {
      await service.addProduct(merchant, product);
      expect(
        () => service.addProduct(merchant, product),
        throwsA(isA<DuplicateInventoryItemException>()),
      );
    });

    test('setQuantity updates an existing item', () async {
      await service.addProduct(merchant, product);
      final updated =
          await service.setQuantity(merchant, product, Quantity.whole(9));
      expect(updated.quantity, Quantity.whole(9));
    });

    test('setQuantity on a missing item throws', () async {
      expect(
        () => service.setQuantity(merchant, product, Quantity.whole(1)),
        throwsA(isA<InventoryItemNotFoundException>()),
      );
    });

    test('getAll returns an unmodifiable snapshot', () async {
      await service.addProduct(merchant, product);
      final all = await service.getAll(merchant);
      expect(() => all.add(all.first), throwsUnsupportedError);
    });

    test('removeProduct returns false when absent and true when present',
        () async {
      expect(await service.removeProduct(merchant, product), isFalse);
      await service.addProduct(merchant, product);
      expect(await service.removeProduct(merchant, product), isTrue);
    });

    test('decrementQuantity deducts a valid amount', () async {
      await service.addProduct(merchant, product, quantity: Quantity.whole(10));
      final updated =
          await service.decrementQuantity(merchant, product, Quantity.whole(3));
      expect(updated.quantity, Quantity.whole(7));
    });

    test('decrementQuantity can reduce stock to exactly zero', () async {
      await service.addProduct(merchant, product, quantity: Quantity.whole(4));
      final updated =
          await service.decrementQuantity(merchant, product, Quantity.whole(4));
      expect(updated.quantity, Quantity.zero);
    });

    test('decrementQuantity greater than available throws', () async {
      await service.addProduct(merchant, product, quantity: Quantity.whole(2));
      expect(
        () => service.decrementQuantity(merchant, product, Quantity.whole(3)),
        throwsA(isA<InsufficientStockException>()),
      );
      expect(
        (await service.findByProduct(merchant, product))!.quantity,
        Quantity.whole(2),
      );
    });

    test('decrementQuantity of zero is rejected', () async {
      await service.addProduct(merchant, product, quantity: Quantity.whole(2));
      expect(
        () => service.decrementQuantity(merchant, product, Quantity.zero),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('decrementQuantity of a negative amount is rejected', () async {
      expect(() => Quantity.fromMilliUnits(-1), throwsArgumentError);
    });

    test('decrementQuantity of a missing product throws', () async {
      expect(
        () => service.decrementQuantity(merchant, product, Quantity.whole(1)),
        throwsA(isA<InventoryItemNotFoundException>()),
      );
    });

    test('decrementQuantity for another merchant does not find the item',
        () async {
      await service.addProduct(merchant, product, quantity: Quantity.whole(5));
      expect(
        () => service.decrementQuantity(
          MerchantId('m2'),
          product,
          Quantity.whole(1),
        ),
        throwsA(isA<InventoryItemNotFoundException>()),
      );
      expect(
        (await service.findByProduct(merchant, product))!.quantity,
        Quantity.whole(5),
      );
    });

    test('decrementQuantity preserves unrelated item fields', () async {
      const price = Money(
        currency: CurrencyCode.yemeniRial,
        minorUnits: 250,
      );
      await service.addProduct(
        merchant,
        product,
        quantity: Quantity.whole(8),
        sellingPrice: price,
        purchasePrice: const Money(
          currency: CurrencyCode.yemeniRial,
          minorUnits: 180,
        ),
        minimumStock: Quantity.whole(2),
      );
      final updated =
          await service.decrementQuantity(merchant, product, Quantity.whole(1));
      expect(updated.sellingPrice, price);
      expect(
        updated.purchasePrice,
        const Money(currency: CurrencyCode.yemeniRial, minorUnits: 180),
      );
      expect(updated.minimumStock, Quantity.whole(2));
      expect(updated.merchantId, merchant);
      expect(updated.productId, product);
      expect(updated.quantity, Quantity.whole(7));
    });

    test('decrementQuantity does not affect another merchant', () async {
      final other = MerchantId('m2');
      await service.addProduct(merchant, product, quantity: Quantity.whole(6));
      await service.addProduct(other, product, quantity: Quantity.whole(6));
      await service.decrementQuantity(merchant, product, Quantity.whole(2));
      expect(
        (await service.findByProduct(merchant, product))!.quantity,
        Quantity.whole(4),
      );
      expect(
        (await service.findByProduct(other, product))!.quantity,
        Quantity.whole(6),
      );
    });

    test('decrementQuantity does not mutate a previously read item', () async {
      await service.addProduct(merchant, product, quantity: Quantity.whole(9));
      final before = await service.findByProduct(merchant, product);
      final after =
          await service.decrementQuantity(merchant, product, Quantity.whole(4));
      expect(before!.quantity, Quantity.whole(9));
      expect(after.quantity, Quantity.whole(5));
      expect(identical(before, after), isFalse);
    });

    test('repeated decrementQuantity yields the remaining quantity', () async {
      await service.addProduct(merchant, product, quantity: Quantity.whole(10));
      await service.decrementQuantity(merchant, product, Quantity.whole(3));
      final remaining =
          await service.decrementQuantity(merchant, product, Quantity.whole(2));
      expect(remaining.quantity, Quantity.whole(5));
    });
  });
}
