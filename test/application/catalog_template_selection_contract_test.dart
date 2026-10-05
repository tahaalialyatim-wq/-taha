import 'package:awtad_retail/awtad_retail.dart';
import 'package:test/test.dart';

Product _product(
  String id, {
  String category = 'c1',
  String name = 'Item',
}) =>
    Product(
      id: ProductId(id),
      genericName: name,
      categoryId: CategoryId(category),
      unit: ProductUnit.kg,
    );

CatalogTemplate _template({
  String id = 'demo-v1',
  String version = '1',
  StoreType storeType = StoreType.grocery,
  List<Category>? categories,
  List<CatalogEntry>? entries,
  List<ProductId>? recommended,
}) {
  final cats = categories ??
      <Category>[
        Category(id: CategoryId('c1'), name: 'One'),
        Category(id: CategoryId('c2'), name: 'Two'),
      ];
  final ents = entries ??
      <CatalogEntry>[
        CatalogEntry(product: _product('p1', category: 'c1'), sortOrder: 1),
        CatalogEntry(product: _product('p2', category: 'c1'), sortOrder: 2),
        CatalogEntry(product: _product('p3', category: 'c2'), sortOrder: 3),
      ];
  return CatalogTemplate(
    id: id,
    version: version,
    storeType: storeType,
    name: 'Demo',
    categories: cats,
    entries: ents,
    recommendedProductIds: recommended ?? <ProductId>[ProductId('p2')],
  );
}

void main() {
  group('CatalogTemplate contract', () {
    test('exposes a stable id, version and associated StoreType', () {
      final template = _template(
        id: 'grocery-v1',
        version: '1',
        storeType: StoreType.grocery,
      );
      expect(template.id, 'grocery-v1');
      expect(template.version, '1');
      expect(template.storeType, StoreType.grocery);
    });

    test('every product references a category that exists on the template', () {
      final template = _template();
      final categoryIds = template.categories.map((c) => c.id).toSet();
      for (final product in template.products) {
        expect(categoryIds, contains(product.categoryId),
            reason: product.id.value);
      }
    });

    test('entryFor, productById and categoryById resolve known references', () {
      final template = _template();
      expect(template.entryFor(ProductId('p2'))!.sortOrder, 2);
      expect(template.productById(ProductId('p3'))!.id, ProductId('p3'));
      expect(template.categoryById(CategoryId('c1'))!.name, 'One');
      expect(template.entryFor(ProductId('missing')), isNull);
      expect(template.productById(ProductId('missing')), isNull);
      expect(template.categoryById(CategoryId('missing')), isNull);
    });

    test('entriesForCategory preserves template order', () {
      final template = _template();
      final inC1 = template.entriesForCategory(CategoryId('c1'));
      expect(inC1.map((e) => e.product.id.value), <String>['p1', 'p2']);
      expect(() => inC1.add(inC1.first), throwsUnsupportedError);
    });

    test('ordering is deterministic across equivalent constructions', () {
      final a = _template();
      final b = _template();
      expect(a.productIds, b.productIds);
      expect(
          a.entries.map((e) => e.sortOrder), b.entries.map((e) => e.sortOrder));
      expect(a.categories.map((c) => c.id), b.categories.map((c) => c.id));
    });

    test('externally exposed collections are immutable', () {
      final template = _template();
      expect(() => template.categories.add(template.categories.first),
          throwsUnsupportedError);
      expect(() => template.entries.add(template.entries.first),
          throwsUnsupportedError);
      expect(() => template.products.add(template.products.first),
          throwsUnsupportedError);
      expect(() => template.productIds.add(ProductId('x')),
          throwsUnsupportedError);
      expect(() => template.recommendedProductIds.add(ProductId('x')),
          throwsUnsupportedError);
    });

    test(
        'constructor copies input so later mutation of the caller list is ignored',
        () {
      final categories = <Category>[
        Category(id: CategoryId('c1'), name: 'One'),
      ];
      final entries = <CatalogEntry>[
        CatalogEntry(product: _product('p1'), sortOrder: 1),
      ];
      final recommended = <ProductId>[ProductId('p1')];
      final template = CatalogTemplate(
        id: 'demo-v1',
        version: '1',
        storeType: StoreType.grocery,
        name: 'Demo',
        categories: categories,
        entries: entries,
        recommendedProductIds: recommended,
      );
      categories.add(Category(id: CategoryId('c2'), name: 'Two'));
      entries.add(CatalogEntry(product: _product('p2'), sortOrder: 2));
      recommended.add(ProductId('p2'));
      expect(template.categoryCount, 1);
      expect(template.productCount, 1);
      expect(template.recommendedProductIds, hasLength(1));
    });

    test('is metadata only: no merchant, inventory, price or sales fields', () {
      final template = _template();
      expect(template, isNot(isA<MerchantInventoryItem>()));
      expect(template.id, isA<String>());
      expect(template.version, isA<String>());
      expect(template.storeType, isA<StoreType>());
    });
  });

  group('CatalogEntry contract', () {
    test('references an existing ProductId and preserves category data', () {
      final product = _product('p1', category: 'c1', name: 'Apple');
      final entry = CatalogEntry(product: product, sortOrder: 7);
      expect(entry.product.id, ProductId('p1'));
      expect(entry.product.categoryId, CategoryId('c1'));
      expect(entry.sortOrder, 7);
    });

    test('has no pricing, inventory, merchant or sales fields', () {
      final entry = CatalogEntry(
        product: _product('p1'),
        sortOrder: 1,
      );
      expect(entry.product, isA<Product>());
      expect(entry.sortOrder, isA<int>());
    });

    test('does not currently carry a suggested initial quantity', () {
      final entry = CatalogEntry(product: _product('p1'), sortOrder: 1);
      expect(entry.product, isNot(isA<Quantity>()));
    });

    test('recommended/default-selection metadata lives on the template', () {
      final template = _template(recommended: <ProductId>[ProductId('p2')]);
      expect(template.recommendedProductIds, <ProductId>[ProductId('p2')]);
      for (final entry in template.entries) {
        expect(entry.sortOrder, isA<int>());
      }
    });

    test('sort order is preserved and deterministic', () {
      final template = _template();
      expect(
        template.entries.map((e) => e.sortOrder).toList(),
        <int>[1, 2, 3],
      );
    });
  });

  group('CatalogProductSelection contract', () {
    final merchant = MerchantId('m1');

    test('is mutable session state only', () {
      final template = _template();
      final selection =
          CatalogProductSelection(merchantId: merchant, template: template);
      expect(selection.isLoaded, isTrue);
      expect(selection.selectedCount, 0);
      selection.select(ProductId('p1'), quantity: Quantity.whole(2));
      expect(selection.selectedCount, 1);
      expect(selection.isSelected(ProductId('p1')), isTrue);
      selection.deselect(ProductId('p1'));
      expect(selection.selectedCount, 0);
    });

    test(
        'selected ProductIds and quantities stay separate from Product/CatalogEntry',
        () {
      final template = _template();
      final entryBefore = template.entryFor(ProductId('p1'))!;
      final selection =
          CatalogProductSelection(merchantId: merchant, template: template);
      selection.select(ProductId('p1'), quantity: Quantity.whole(4));
      expect(selection.getSelected().single.quantity, Quantity.whole(4));
      expect(
          template.entryFor(ProductId('p1'))!.sortOrder, entryBefore.sortOrder);
      expect(template.productById(ProductId('p1'))!.id, ProductId('p1'));
    });

    test('externally exposed selected collections are immutable', () {
      final selection =
          CatalogProductSelection(merchantId: merchant, template: _template());
      selection.select(ProductId('p1'));
      final selected = selection.getSelected();
      expect(() => selected.add(selected.first), throwsUnsupportedError);
      expect(() => selected.removeLast(), throwsUnsupportedError);
    });

    test(
        'selection changes do not mutate Product, CatalogEntry, CatalogTemplate or source',
        () {
      final template = _template();
      final source = InMemoryStarterCatalogSource(
        templates: <CatalogTemplate>[template],
      );
      final selection =
          CatalogProductSelection(merchantId: merchant, template: template);
      selection.select(ProductId('p1'), quantity: Quantity.whole(9));
      selection.setQuantity(ProductId('p1'), Quantity.whole(3));
      selection.select(ProductId('p2'));
      selection.deselect(ProductId('p2'));
      expect(template.productCount, 3);
      expect(template.entries.map((e) => e.sortOrder), <int>[1, 2, 3]);
      expect(() => template.products.first.barcodes.add(Barcode('1')),
          throwsUnsupportedError);
      expect(() => template.entries.add(template.entries.first),
          throwsUnsupportedError);
      expectLater(source.loadTemplates(), completion(hasLength(1)));
    });

    test('browse results are unmodifiable and do not mutate the template', () {
      final template = _template();
      final selection =
          CatalogProductSelection(merchantId: merchant, template: template);
      final browsed = selection.browse(categoryId: CategoryId('c1'));
      expect(browsed, hasLength(2));
      expect(() => browsed.add(browsed.first), throwsUnsupportedError);
      expect(template.productCount, 3);
    });
  });

  group('Selection to inventory boundary', () {
    late MerchantInventoryService service;
    final merchant = MerchantId('m1');

    setUp(() {
      service = MerchantInventoryService(InMemoryMerchantInventoryRepository());
    });

    test('catalog remains catalog-owned until confirm creates inventory',
        () async {
      final template = _template();
      final selection =
          CatalogProductSelection(merchantId: merchant, template: template);
      selection.select(ProductId('p1'), quantity: Quantity.whole(2));
      expect(await service.getAll(merchant), isEmpty);
      expect(template.products, isNotEmpty);
      expect(selection.getSelected().single.product.id, ProductId('p1'));
    });

    test('confirm creates MerchantInventoryItem using MerchantId and ProductId',
        () async {
      final template = _template();
      final selection =
          CatalogProductSelection(merchantId: merchant, template: template);
      selection.select(ProductId('p1'), quantity: Quantity.whole(2));
      final created = await selection.confirm(service);
      expect(created, hasLength(1));
      expect(created.single, isA<MerchantInventoryItem>());
      expect(created.single.merchantId, merchant);
      expect(created.single.productId, ProductId('p1'));
      expect(created.single.quantity, Quantity.whole(2));
      expect(await service.findByProduct(merchant, ProductId('p1')), isNotNull);
    });

    test('confirm result is unmodifiable and does not mutate the catalog',
        () async {
      final template = _template();
      final selection =
          CatalogProductSelection(merchantId: merchant, template: template);
      selection.select(ProductId('p1'));
      final created = await selection.confirm(service);
      expect(() => created.add(created.first), throwsUnsupportedError);
      expect(template.productCount, 3);
      expect(template.storeType, StoreType.grocery);
    });
  });

  group('grocery-v1 through CatalogTemplate contract', () {
    test('placeholder grocery identities remain catalog-owned metadata', () {
      final catalog = buildGroceryStarterCatalog();
      expect(catalog.id, 'grocery-v1');
      expect(catalog.version, '1');
      expect(catalog.storeType, StoreType.grocery);
      for (final entry in catalog.entries) {
        expect(catalog.categoryById(entry.product.categoryId), isNotNull);
        expect(entry.product.barcodes, isEmpty);
      }
    });
  });
}
