import 'package:awtad_retail/awtad_retail.dart';
import 'package:test/test.dart';

void main() {
  group('ProductUnit', () {
    test('exposes the supported built-in units', () {
      expect(ProductUnit.values, hasLength(9));
      expect(
        ProductUnit.values.map((u) => u.value),
        containsAllInOrder(<String>[
          'piece',
          'box',
          'carton',
          'kg',
          'g',
          'L',
          'mL',
          'm',
          'other',
        ]),
      );
    });

    test('parses built-in units and trims', () {
      expect(ProductUnit.parse('kg'), ProductUnit.kg);
      expect(ProductUnit.parse(' L '), ProductUnit.litre);
      expect(ProductUnit.parse('mL'), ProductUnit.millilitre);
    });

    test('rejects unsupported units', () {
      expect(() => ProductUnit.parse('ton'), throwsArgumentError);
    });

    test('piece, box and carton require whole quantities', () {
      expect(ProductUnit.piece.requiresWhole, isTrue);
      expect(ProductUnit.box.requiresWhole, isTrue);
      expect(ProductUnit.carton.requiresWhole, isTrue);
      expect(ProductUnit.piece.allowsFractional, isFalse);
    });

    test('measurement units allow fractional quantities', () {
      for (final unit in <ProductUnit>[
        ProductUnit.kg,
        ProductUnit.g,
        ProductUnit.litre,
        ProductUnit.millilitre,
        ProductUnit.metre,
        ProductUnit.other,
      ]) {
        expect(unit.allowsFractional, isTrue, reason: unit.value);
        expect(unit.requiresWhole, isFalse, reason: unit.value);
      }
    });

    test('other can carry a custom label', () {
      final custom = ProductUnit.custom('sack');
      expect(custom.value, 'other');
      expect(custom.customLabel, 'sack');
      expect(custom, ProductUnit.custom('sack'));
      expect(custom == ProductUnit.custom('bale'), isFalse);
    });

    test('custom label must not be blank', () {
      expect(() => ProductUnit.custom('   '), throwsArgumentError);
    });
  });
}
