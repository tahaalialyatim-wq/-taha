import 'package:awtad_retail/awtad_retail.dart';
import 'package:test/test.dart';

void main() {
  group('Barcode', () {
    test('trims its value', () {
      expect(Barcode('  12345 ').value, '12345');
    });

    test('rejects empty and whitespace-only values', () {
      expect(() => Barcode(''), throwsArgumentError);
      expect(() => Barcode('   '), throwsArgumentError);
    });

    test('defaults to the other type and is not primary', () {
      final barcode = Barcode('12345');
      expect(barcode.type, BarcodeType.other);
      expect(barcode.isPrimary, isFalse);
    });

    test('equality includes value, type and primary flag', () {
      final a = Barcode('123', type: BarcodeType.ean13, isPrimary: true);
      final b = Barcode('123', type: BarcodeType.ean13, isPrimary: true);
      expect(a, b);
      expect(a.hashCode, b.hashCode);
      expect(a == Barcode('123', type: BarcodeType.ean13), isFalse);
      expect(a == Barcode('124', type: BarcodeType.ean13, isPrimary: true),
          isFalse);
    });
  });

  group('ProductImageRef', () {
    test('rejects empty references', () {
      expect(() => ProductImageRef('  '), throwsArgumentError);
    });

    test('has value equality', () {
      expect(ProductImageRef('a/b.png'), ProductImageRef('a/b.png'));
    });
  });
}
