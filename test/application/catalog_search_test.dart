import 'package:awtad_retail/awtad_retail.dart';
import 'package:test/test.dart';

Product product(
  String id,
  String name, {
  String category = 'c1',
  List<String> aliases = const <String>[],
  List<Barcode> barcodes = const <Barcode>[],
}) =>
    Product(
      id: ProductId(id),
      genericName: name,
      categoryId: CategoryId(category),
      unit: ProductUnit.kg,
      searchAliases: aliases,
      barcodes: barcodes,
    );

CatalogTemplate template(List<CatalogEntry> entries) => CatalogTemplate(
      id: 't',
      version: '1',
      storeType: StoreType.grocery,
      name: 'Template',
      categories: <Category>[
        Category(id: CategoryId('c1'), name: 'One'),
        Category(id: CategoryId('c2'), name: 'Two'),
      ],
      entries: entries,
    );

CatalogEntry entry(Product p, int order) =>
    CatalogEntry(product: p, sortOrder: order);

void main() {
  group('CatalogTemplate.search ranking', () {
    final t = template(<CatalogEntry>[
      entry(
          product('p-barcode', 'Sparkling Water',
              barcodes: <Barcode>[Barcode('555')]),
          1),
      entry(product('p-exact', 'Milk'), 2),
      entry(product('p-start-1', 'Milk Chocolate'), 3),
      entry(product('p-contains', 'Almond Milk'), 4),
      entry(product('p-alias', 'Fresh Dairy Drink', aliases: <String>['milk']),
          5),
      entry(product('p-start-2', 'Milk Tea'), 6),
    ]);

    test('barcodeExact beats everything', () {
      final results = t.search('555');
      expect(results.map((p) => p.id.value), <String>['p-barcode']);
    });

    test('ranks exact, startsWith, aliasExact, contains, then sortOrder', () {
      final results = t.search('milk');
      expect(
        results.map((p) => p.id.value),
        <String>[
          'p-exact',
          'p-start-1',
          'p-start-2',
          'p-alias',
          'p-contains',
        ],
      );
    });

    test('equal rank is broken by sortOrder', () {
      final t2 = template(<CatalogEntry>[
        entry(product('later', 'Milk B'), 10),
        entry(product('earlier', 'Milk A'), 4),
      ]);
      expect(
        t2.search('milk').map((p) => p.id.value),
        <String>['earlier', 'later'],
      );
    });

    test('empty query returns no results', () {
      expect(t.search('   '), isEmpty);
    });

    test('case insensitive and trimmed', () {
      expect(t.search('  MILK ').first.id.value, 'p-exact');
    });
  });
}
