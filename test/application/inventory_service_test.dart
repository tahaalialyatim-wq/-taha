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
  });
}
