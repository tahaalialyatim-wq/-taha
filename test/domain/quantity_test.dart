import 'package:awtad_retail/awtad_retail.dart';
import 'package:test/test.dart';

void main() {
  group('Quantity', () {
    test('uses a milli-unit scale of 1000', () {
      expect(Quantity.scale, 1000);
      expect(Quantity.fromMilliUnits(1000).isWhole, isTrue);
      expect(Quantity.fromMilliUnits(999).isWhole, isFalse);
    });

    test('1.5 kg is 1500 milli-units', () {
      expect(Quantity.of(ProductUnit.kg, 1500).milliUnits, 1500);
    });

    test('0.75 L is 750 milli-units', () {
      expect(Quantity.of(ProductUnit.litre, 750).milliUnits, 750);
    });

    test('piece/box/carton require whole quantities', () {
      expect(() => Quantity.of(ProductUnit.piece, 1500), throwsArgumentError);
      expect(() => Quantity.of(ProductUnit.box, 1), throwsArgumentError);
      expect(() => Quantity.of(ProductUnit.carton, 250), throwsArgumentError);
      expect(Quantity.of(ProductUnit.piece, 2000).wholeUnits, 2);
    });

    test('fractional units accept fractional quantities', () {
      expect(Quantity.of(ProductUnit.kg, 1).milliUnits, 1);
      expect(Quantity.of(ProductUnit.other, 333).milliUnits, 333);
    });

    test('zero is allowed', () {
      expect(Quantity.zero.milliUnits, 0);
      expect(Quantity.zero.isWhole, isTrue);
    });

    test('negative quantities are rejected', () {
      expect(() => Quantity.of(ProductUnit.kg, -1), throwsArgumentError);
      expect(() => Quantity.whole(-1), throwsArgumentError);
      expect(() => Quantity.fromMilliUnits(-1), throwsArgumentError);
    });

    test('milli-units are integers with no double representation', () {
      final quantity = Quantity.fromMilliUnits(1500);
      expect(quantity.milliUnits, isA<int>());
      expect(quantity.milliUnits, 1500);
      expect(Quantity.scale, 1000);
    });

    test('has value equality', () {
      expect(Quantity.fromMilliUnits(1500), Quantity.of(ProductUnit.kg, 1500));
      expect(
        Quantity.fromMilliUnits(1500).hashCode,
        Quantity.of(ProductUnit.kg, 1500).hashCode,
      );
    });
  });
}
