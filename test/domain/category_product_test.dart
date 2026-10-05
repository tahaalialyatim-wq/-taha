import 'package:awtad_retail/awtad_retail.dart';
import 'package:test/test.dart';

void main() {
  group('Category', () {
    test('defaults to active', () {
      final category = Category(id: CategoryId('c1'), name: 'C');
      expect(category.isActive, isTrue);
    });

    test('exposes unmodifiable relevant store types', () {
      final category = Category(
        id: CategoryId('c1'),
        name: 'C',
        relevantStoreTypes: <StoreType>{StoreType.grocery},
      );
      expect(
        () => category.relevantStoreTypes.add(StoreType.pharmacy),
        throwsUnsupportedError,
      );
    });

    test('equality is by CategoryId only', () {
      final a = Category(id: CategoryId('c1'), name: 'A');
      final b = Category(id: CategoryId('c1'), name: 'B');
      expect(a, b);
      expect(a.hashCode, b.hashCode);
      expect(a == Category(id: CategoryId('c2'), name: 'A'), isFalse);
    });

    test('rejects empty names', () {
      expect(() => Category(id: CategoryId('c1'), name: '  '),
          throwsArgumentError);
    });
  });

  group('Product', () {
    Product build({ProductId? id}) => Product(
          id: id ?? ProductId('p1'),
          genericName: 'Milk',
          categoryId: CategoryId('c1'),
          unit: ProductUnit.litre,
        );

    test('exposes unmodifiable barcodes and aliases', () {
      final product = Product(
        id: ProductId('p1'),
        genericName: 'Milk',
        categoryId: CategoryId('c1'),
        unit: ProductUnit.litre,
        barcodes: <Barcode>[Barcode('123')],
        searchAliases: <String>['حليب'],
      );
      expect(
          () => product.barcodes.add(Barcode('456')), throwsUnsupportedError);
      expect(() => product.searchAliases.add('x'), throwsUnsupportedError);
    });

    test('equality is by ProductId only', () {
      expect(build(id: ProductId('p1')), build(id: ProductId('p1')));
      expect(build(id: ProductId('p1')).hashCode,
          build(id: ProductId('p1')).hashCode);
      expect(build(id: ProductId('p1')) == build(id: ProductId('p2')), isFalse);
    });

    test('brand is trimmed and blank becomes null', () {
      final blank = Product(
        id: ProductId('p1'),
        genericName: 'Milk',
        categoryId: CategoryId('c1'),
        unit: ProductUnit.litre,
        brand: '   ',
      );
      expect(blank.brand, isNull);
    });

    test('rejects empty generic names', () {
      expect(
        () => Product(
          id: ProductId('p1'),
          genericName: ' ',
          categoryId: CategoryId('c1'),
          unit: ProductUnit.litre,
        ),
        throwsArgumentError,
      );
    });
  });
}
