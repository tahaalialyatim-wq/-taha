import 'package:awtad_retail/awtad_retail.dart';
import 'package:test/test.dart';

void main() {
  group('StoreId', () {
    test('trims its input', () {
      expect(StoreId('  s1 ').value, 's1');
    });

    test('rejects empty and whitespace-only values', () {
      expect(() => StoreId(''), throwsArgumentError);
      expect(() => StoreId('   '), throwsArgumentError);
    });

    test('has value equality and matching hashCode', () {
      expect(StoreId('s1'), StoreId('s1'));
      expect(StoreId('s1').hashCode, StoreId('s1').hashCode);
      expect(StoreId('s1') == StoreId('s2'), isFalse);
    });
  });

  group('StoreName', () {
    test('trims its input', () {
      expect(StoreName('  Main ').value, 'Main');
    });

    test('rejects empty names', () {
      expect(() => StoreName('  '), throwsArgumentError);
    });
  });

  group('StoreType', () {
    test('exposes the nine supported machine values', () {
      expect(StoreType.values, hasLength(9));
      expect(
        StoreType.values.map((t) => t.value),
        containsAllInOrder(<String>[
          'grocery',
          'mini-market',
          'pharmacy',
          'clothing',
          'electronics',
          'cafe',
          'restaurant',
          'fruit-vegetable',
          'other',
        ]),
      );
    });

    test('parses case-insensitively and trims', () {
      expect(StoreType.parse('  Grocery '), StoreType.grocery);
      expect(StoreType.parse('MINI-MARKET'), StoreType.miniMarket);
      expect(StoreType.parse('Fruit-Vegetable'), StoreType.fruitVegetable);
    });

    test('rejects unsupported values', () {
      expect(() => StoreType.parse('warehouse'), throwsArgumentError);
    });

    test('is a value object', () {
      expect(StoreType.grocery, StoreType.parse('grocery'));
      expect(StoreType.grocery.hashCode, StoreType.parse('grocery').hashCode);
      expect(StoreType.other.isOther, isTrue);
      expect(StoreType.grocery.isOther, isFalse);
    });
  });

  group('Store', () {
    Store build(StoreId id) => Store(
          id: id,
          merchantId: MerchantId('m1'),
          name: StoreName('Main'),
          type: StoreType.grocery,
          defaultCurrency: CurrencyCode.yemeniRial,
          defaultLanguage: LanguageCode.arabic,
        );

    test('requires explicit currency and language', () {
      final store = build(StoreId('s1'));
      expect(store.defaultCurrency, CurrencyCode.yemeniRial);
      expect(store.defaultLanguage, LanguageCode.arabic);
    });

    test('equality and hashCode are based on StoreId only', () {
      expect(build(StoreId('s1')), build(StoreId('s1')));
      expect(build(StoreId('s1')).hashCode, build(StoreId('s1')).hashCode);
      expect(build(StoreId('s1')) == build(StoreId('s2')), isFalse);
    });
  });
}
