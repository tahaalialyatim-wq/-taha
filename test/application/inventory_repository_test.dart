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
  });
}
