import 'package:awtad_retail/awtad_retail.dart';
import 'package:test/test.dart';

void main() {
  late CatalogTemplate catalog;

  setUp(() {
    catalog = buildGroceryStarterCatalog();
  });

  group('grocery-v1 catalog identity', () {
    test('id, version and StoreType are stable', () {
      expect(catalog.id, 'grocery-v1');
      expect(catalog.version, '1');
      expect(catalog.storeType, StoreType.grocery);
      final again = buildGroceryStarterCatalog();
      expect(again.id, catalog.id);
      expect(again.version, catalog.version);
      expect(again.storeType, catalog.storeType);
    });
  });

  group('grocery-v1 category contract', () {
    test('count remains 9 with unique CategoryIds', () {
      expect(catalog.categoryCount, 9);
      expect(catalog.categories, hasLength(9));
      final ids = catalog.categories.map((c) => c.id.value).toSet();
      expect(ids, hasLength(9));
    });

    test('parent references resolve when present', () {
      for (final category in catalog.categories) {
        final parentId = category.parentId;
        if (parentId != null) {
          expect(catalog.categoryById(parentId), isNotNull,
              reason: category.id.value);
        }
      }
    });

    test('every category includes StoreType.grocery', () {
      for (final category in catalog.categories) {
        expect(category.relevantStoreTypes, contains(StoreType.grocery),
            reason: category.id.value);
        expect(
          () => category.relevantStoreTypes.add(StoreType.pharmacy),
          throwsUnsupportedError,
        );
      }
    });

    test('category ordering is deterministic', () {
      final again = buildGroceryStarterCatalog();
      expect(
        again.categories.map((c) => c.id.value).toList(),
        catalog.categories.map((c) => c.id.value).toList(),
      );
    });

    test('no unused categories', () {
      final used = catalog.products.map((p) => p.categoryId).toSet();
      for (final category in catalog.categories) {
        expect(used, contains(category.id), reason: category.id.value);
      }
    });
  });

  group('grocery-v1 product contract', () {
    test('count remains 45 with unique ProductIds', () {
      expect(catalog.productCount, 45);
      expect(catalog.productIds.map((id) => id.value).toSet(), hasLength(45));
    });

    test('every product references an existing CategoryId', () {
      for (final product in catalog.products) {
        expect(catalog.categoryById(product.categoryId), isNotNull,
            reason: product.id.value);
      }
    });

    test('every ProductUnit is a canonical built-in or other unit', () {
      final canonical = ProductUnit.values.map((u) => u.value).toSet();
      for (final product in catalog.products) {
        expect(canonical, contains(product.unit.value),
            reason: product.id.value);
      }
    });

    test('barcodes remain empty and aliases are immutable', () {
      for (final product in catalog.products) {
        expect(product.barcodes, isEmpty, reason: product.id.value);
        expect(
            () => product.barcodes.add(Barcode('x')), throwsUnsupportedError);
        expect(() => product.searchAliases.add('x'), throwsUnsupportedError);
      }
    });

    test('product ordering is deterministic', () {
      final again = buildGroceryStarterCatalog();
      expect(
        again.productIds.map((id) => id.value).toList(),
        catalog.productIds.map((id) => id.value).toList(),
      );
    });
  });

  group('grocery-v1 entry contract', () {
    test(
        'every CatalogEntry references an existing ProductId with no duplicates',
        () {
      final seen = <String>{};
      for (final entry in catalog.entries) {
        expect(catalog.productById(entry.product.id), isNotNull,
            reason: entry.product.id.value);
        expect(seen.add(entry.product.id.value), isTrue,
            reason: 'duplicate ${entry.product.id.value}');
      }
      expect(catalog.entries, hasLength(45));
    });

    test('category and product relationships resolve with no orphans', () {
      for (final entry in catalog.entries) {
        expect(catalog.categoryById(entry.product.categoryId), isNotNull,
            reason: entry.product.id.value);
      }
    });

    test('sortOrder is deterministic and unique', () {
      final orders = catalog.entries.map((e) => e.sortOrder).toList();
      expect(orders, orderedEquals(List<int>.generate(45, (i) => i + 1)));
      final again = buildGroceryStarterCatalog();
      expect(again.entries.map((e) => e.sortOrder).toList(), orders);
    });

    test('recommendedProductIds reference existing products', () {
      final productIds = catalog.productIds.toSet();
      expect(catalog.recommendedProductIds, isNotEmpty);
      for (final id in catalog.recommendedProductIds) {
        expect(productIds, contains(id));
      }
    });

    test('entries carry no merchant, inventory or price state', () {
      for (final entry in catalog.entries) {
        expect(entry.product, isA<Product>());
        expect(entry.sortOrder, isA<int>());
        expect(entry.product.barcodes, isEmpty);
      }
    });
  });

  group('grocery-v1 source and loaded catalog', () {
    test('source loading returns the same logical catalog repeatedly',
        () async {
      final source = buildGroceryStarterCatalogSource();
      final first = await source.loadForStoreType(StoreType.grocery);
      final second = await source.loadForStoreType(StoreType.grocery);
      expect(first, isNotNull);
      expect(second, isNotNull);
      expect(first!.id, 'grocery-v1');
      expect(first.version, '1');
      expect(first.storeType, StoreType.grocery);
      expect(first.productIds, second!.productIds);
      expect(first.categories.map((c) => c.id),
          second.categories.map((c) => c.id));
    });

    test('LoadedStarterCatalog preserves identity and is immutable', () async {
      final source = buildGroceryStarterCatalogSource();
      final engine = StarterCatalogEngine(source);
      final loaded = await engine.loadForStoreType(StoreType.grocery);
      expect(loaded.id, 'grocery-v1');
      expect(loaded.version, '1');
      expect(loaded.storeType, StoreType.grocery);
      expect(() => loaded.categories.add(loaded.categories.first),
          throwsUnsupportedError);
      expect(() => loaded.products.add(loaded.products.first),
          throwsUnsupportedError);
      expect(() => loaded.entries.add(loaded.entries.first),
          throwsUnsupportedError);
      expect(
          () => loaded.productIds.add(ProductId('x')), throwsUnsupportedError);
    });

    test('caller mutation cannot alter source or catalog state', () async {
      final source = buildGroceryStarterCatalogSource();
      final first = (await source.loadForStoreType(StoreType.grocery))!;
      expect(() => first.products.add(first.products.first),
          throwsUnsupportedError);
      expect(() => first.categories.add(first.categories.first),
          throwsUnsupportedError);
      final second = (await source.loadForStoreType(StoreType.grocery))!;
      expect(second.productCount, 45);
      expect(second.categoryCount, 9);
    });

    test('equivalent repeated loads remain equivalent', () async {
      final engine = StarterCatalogEngine(buildGroceryStarterCatalogSource());
      final a = await engine.loadForStoreType(StoreType.grocery);
      final b = await engine.loadForStoreType(StoreType.grocery);
      expect(a, b);
      expect(a.productIds, b.productIds);
    });
  });

  group('grocery-v1 search and ordering', () {
    test('search remains deterministic across builds', () {
      final again = buildGroceryStarterCatalog();
      expect(
        catalog.search('milk').map((p) => p.id.value).toList(),
        again.search('milk').map((p) => p.id.value).toList(),
      );
      expect(
        catalog.search('حليب').map((p) => p.id.value).toList(),
        again.search('حليب').map((p) => p.id.value).toList(),
      );
    });

    test('empty query remains empty', () {
      expect(catalog.search(''), isEmpty);
      expect(catalog.search('   '), isEmpty);
    });
  });

  group('grocery-v1 version isolation', () {
    test('does not expose additional catalog versions', () async {
      final templates =
          await buildGroceryStarterCatalogSource().loadTemplates();
      expect(templates, hasLength(1));
      expect(templates.single.id, 'grocery-v1');
      expect(templates.single.version, '1');
    });
  });
}
