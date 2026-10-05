import 'package:awtad_retail/awtad_retail.dart';
import 'package:test/test.dart';

void main() {
  group('grocery-v1 starter catalog', () {
    late CatalogTemplate catalog;

    setUp(() {
      catalog = buildGroceryStarterCatalog();
    });

    test('has the documented identity and store type', () {
      expect(catalog.id, 'grocery-v1');
      expect(catalog.version, '1');
      expect(catalog.storeType, StoreType.grocery);
    });

    test('has exactly 9 categories and 45 products', () {
      expect(catalog.categoryCount, 9);
      expect(catalog.productCount, 45);
    });

    test('all product barcodes are empty', () {
      for (final product in catalog.products) {
        expect(product.barcodes, isEmpty, reason: product.id.value);
      }
    });

    test('product and category ids are unique', () {
      final productIds = catalog.productIds.map((id) => id.value).toSet();
      expect(productIds, hasLength(45));
      final categoryIds = catalog.categories.map((c) => c.id.value).toSet();
      expect(categoryIds, hasLength(9));
    });

    test('every product references a known category', () {
      final categoryIds = catalog.categories.map((c) => c.id).toSet();
      for (final product in catalog.products) {
        expect(categoryIds, contains(product.categoryId),
            reason: product.id.value);
      }
    });

    test('all categories are relevant to the grocery store type', () {
      for (final category in catalog.categories) {
        expect(category.relevantStoreTypes, contains(StoreType.grocery));
      }
    });

    test('exposed collections are unmodifiable', () {
      expect(() => catalog.products.add(catalog.products.first),
          throwsUnsupportedError);
      expect(
          () => catalog.productIds.add(ProductId('x')), throwsUnsupportedError);
      expect(() => catalog.categories.add(catalog.categories.first),
          throwsUnsupportedError);
      expect(() => catalog.entries.add(catalog.entries.first),
          throwsUnsupportedError);
      expect(
        () => catalog.recommendedProductIds.add(ProductId('x')),
        throwsUnsupportedError,
      );
    });

    test('recommended ids all exist in the catalog', () {
      final productIds = catalog.productIds.toSet();
      for (final id in catalog.recommendedProductIds) {
        expect(productIds, contains(id));
      }
    });

    test('ordering is deterministic between builds', () {
      final again = buildGroceryStarterCatalog();
      expect(again.productIds, catalog.productIds);
      expect(again.categories.map((c) => c.id),
          catalog.categories.map((c) => c.id));
    });

    test('supports Arabic alias search', () {
      final results = catalog.search('حليب');
      expect(results, isNotEmpty);
      expect(results.first.id, ProductId('prod-milk'));
    });

    test('entry sort order is deterministic and ascending', () {
      var previous = 0;
      for (final entry in catalog.entries) {
        expect(entry.sortOrder, greaterThan(previous));
        previous = entry.sortOrder;
      }
    });
  });
}
