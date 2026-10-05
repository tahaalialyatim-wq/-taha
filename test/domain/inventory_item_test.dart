import 'package:awtad_retail/awtad_retail.dart';
import 'package:test/test.dart';

void main() {
  group('Inventory value objects', () {
    test('InventoryItemId trims and rejects empty', () {
      expect(InventoryItemId(' i1 ').value, 'i1');
      expect(() => InventoryItemId(''), throwsArgumentError);
    });

    test('SupplierId trims and rejects empty', () {
      expect(SupplierId(' s1 ').value, 's1');
      expect(() => SupplierId('  '), throwsArgumentError);
    });
  });

  group('MerchantInventoryItem', () {
    MerchantInventoryItem build({
      MerchantId? merchantId,
      Quantity? quantity,
      InventoryItemId? id,
    }) =>
        MerchantInventoryItem(
          id: id ?? InventoryItemId('i1'),
          merchantId: merchantId ?? MerchantId('m1'),
          productId: ProductId('p1'),
          quantity: quantity ?? Quantity.zero,
        );

    test('explicitly carries MerchantId, ProductId and identity', () {
      final item = build(merchantId: MerchantId('m9'));
      expect(item.merchantId, MerchantId('m9'));
      expect(item.productId, ProductId('p1'));
      expect(item.id, InventoryItemId('i1'));
    });

    test('quantity may be zero', () {
      expect(build(quantity: Quantity.zero).quantity, Quantity.zero);
    });

    test('selling, purchase and minimum-stock values may be absent', () {
      final item = build();
      expect(item.sellingPrice, isNull);
      expect(item.purchasePrice, isNull);
      expect(item.minimumStock, isNull);
    });

    test('copyWith updates quantity while preserving identity', () {
      final updated = build().copyWith(quantity: Quantity.whole(3));
      expect(updated.quantity, Quantity.whole(3));
      expect(updated.id, InventoryItemId('i1'));
      expect(updated.merchantId, MerchantId('m1'));
    });

    test('equality is by InventoryItemId', () {
      expect(
          build(quantity: Quantity.zero), build(quantity: Quantity.whole(5)));
      expect(
        build(id: InventoryItemId('i1')) == build(id: InventoryItemId('i2')),
        isFalse,
      );
    });
  });
}
