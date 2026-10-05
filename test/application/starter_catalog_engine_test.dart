import 'package:awtad_retail/awtad_retail.dart';
import 'package:test/test.dart';

/// Minimal fake source used to assert the [StarterCatalogSource] contract.
class _FakeSource implements StarterCatalogSource {
  _FakeSource(this._templates);

  final List<CatalogTemplate> _templates;
  int loadTemplatesCalls = 0;

  @override
  Future<List<CatalogTemplate>> loadTemplates() async {
    loadTemplatesCalls++;
    return List<CatalogTemplate>.unmodifiable(_templates);
  }

  @override
  Future<CatalogTemplate?> loadForStoreType(StoreType storeType) async {
    for (final template in _templates) {
      if (template.storeType == storeType) {
        return template;
      }
    }
    return null;
  }
}

CatalogTemplate _template({
  String id = 'demo-v1',
  String version = '1',
  StoreType storeType = StoreType.grocery,
}) =>
    CatalogTemplate(
      id: id,
      version: version,
      storeType: storeType,
      name: 'Demo',
      categories: <Category>[
        Category(id: CategoryId('c1'), name: 'One'),
      ],
      entries: <CatalogEntry>[
        CatalogEntry(
          product: Product(
            id: ProductId('p1'),
            genericName: 'One',
            categoryId: CategoryId('c1'),
            unit: ProductUnit.piece,
          ),
          sortOrder: 1,
        ),
      ],
    );

void main() {
  group('StarterCatalogSource contract', () {
    test('is an abstraction implemented by an in-memory source', () {
      final source = InMemoryStarterCatalogSource(
        templates: <CatalogTemplate>[_template()],
      );
      expect(source, isA<StarterCatalogSource>());
    });

    test('loadTemplates returns an unmodifiable snapshot', () async {
      final source = _FakeSource(<CatalogTemplate>[_template()]);
      final templates = await source.loadTemplates();
      expect(templates, hasLength(1));
      expect(() => templates.add(_template()), throwsUnsupportedError);
    });

    test('loadForStoreType returns null for an unavailable store type',
        () async {
      final source = _FakeSource(<CatalogTemplate>[_template()]);
      expect(await source.loadForStoreType(StoreType.pharmacy), isNull);
    });
  });

  group('Loading grocery-v1 through the source', () {
    late StarterCatalogSource source;
    late StarterCatalogEngine engine;

    setUp(() {
      source = buildGroceryStarterCatalogSource();
      engine = StarterCatalogEngine(source);
    });

    test('loads the grocery catalog with stable id and version', () async {
      final loaded = await engine.loadForStoreType(StoreType.grocery);
      expect(loaded.id, 'grocery-v1');
      expect(loaded.version, '1');
      expect(loaded.name, isNotEmpty);
    });

    test('preserves the StoreType association', () async {
      final loaded = await engine.loadForStoreType(StoreType.grocery);
      expect(loaded.storeType, StoreType.grocery);
    });

    test('exposes the existing fixture counts without duplicating data',
        () async {
      final loaded = await engine.loadForStoreType(StoreType.grocery);
      expect(loaded.categoryCount, 9);
      expect(loaded.productCount, 45);
      expect(loaded.productIds, hasLength(45));
      expect(loaded.categories, hasLength(9));
    });

    test('is the same source data as the existing grocery fixture', () async {
      final loaded = await engine.loadForStoreType(StoreType.grocery);
      final fixture = buildGroceryStarterCatalog();
      expect(loaded.id, fixture.id);
      expect(loaded.version, fixture.version);
      expect(loaded.productIds, fixture.productIds);
      expect(loaded.categories.map((c) => c.id),
          fixture.categories.map((c) => c.id));
    });

    test('unknown StoreType follows the project exception convention',
        () async {
      expect(
        () => engine.loadForStoreType(StoreType.pharmacy),
        throwsA(isA<StarterCatalogNotFoundException>()),
      );
    });

    test('the exception reports the requested store type', () async {
      try {
        await engine.loadForStoreType(StoreType.restaurant);
        fail('expected StarterCatalogNotFoundException');
      } on StarterCatalogNotFoundException catch (error) {
        expect(error.storeType, StoreType.restaurant);
      }
    });
  });

  group('LoadedStarterCatalog immutability', () {
    late LoadedStarterCatalog loaded;

    setUp(() async {
      loaded = await StarterCatalogEngine(buildGroceryStarterCatalogSource())
          .loadForStoreType(StoreType.grocery);
    });

    test('exposed collections are unmodifiable', () {
      expect(() => loaded.categories.add(loaded.categories.first),
          throwsUnsupportedError);
      expect(() => loaded.entries.add(loaded.entries.first),
          throwsUnsupportedError);
      expect(() => loaded.products.add(loaded.products.first),
          throwsUnsupportedError);
      expect(
          () => loaded.productIds.add(ProductId('x')), throwsUnsupportedError);
      expect(
        () => loaded.recommendedProductIds.add(ProductId('x')),
        throwsUnsupportedError,
      );
    });

    test('products and categories cannot be mutated through loaded results',
        () async {
      final fixture = buildGroceryStarterCatalog();
      final beforeCount = fixture.productCount;
      final product = loaded.products.first;
      expect(
          () => product.barcodes.add(Barcode('999')), throwsUnsupportedError);
      expect(() => product.searchAliases.add('x'), throwsUnsupportedError);
      expect(loaded.productCount, beforeCount);
    });

    test('repeated loads are deterministic and equivalent', () async {
      final engine = StarterCatalogEngine(buildGroceryStarterCatalogSource());
      final first = await engine.loadForStoreType(StoreType.grocery);
      final second = await engine.loadForStoreType(StoreType.grocery);
      expect(first, second);
      expect(first.hashCode, second.hashCode);
      expect(first.productIds, second.productIds);
    });

    test('can create the existing CatalogProductSelection flow', () async {
      final engine = StarterCatalogEngine(buildGroceryStarterCatalogSource());
      final selection = await engine.createSelection(
        MerchantId('m1'),
        StoreType.grocery,
      );
      expect(selection, isA<CatalogProductSelection>());
      expect(selection.isLoaded, isTrue);
      expect(selection.browse(), hasLength(45));
    });

    test('created selection does not mutate the loaded template', () async {
      final engine = StarterCatalogEngine(buildGroceryStarterCatalogSource());
      final selection = await engine.createSelection(
        MerchantId('m1'),
        StoreType.grocery,
      );
      selection.select(ProductId('prod-apple'));
      expect(loaded.productCount, 45);
      expect(selection.browse(), hasLength(45));
    });
  });

  group('InMemoryStarterCatalogSource', () {
    test('is empty by default and returns unmodifiable lists', () async {
      final source = InMemoryStarterCatalogSource();
      final templates = await source.loadTemplates();
      expect(templates, isEmpty);
      expect(() => templates.add(_template()), throwsUnsupportedError);
    });

    test('rejects source mutation after construction', () async {
      final input = <CatalogTemplate>[_template()];
      final source = InMemoryStarterCatalogSource(templates: input);
      input.add(_template(id: 'other-v1'));
      final templates = await source.loadTemplates();
      expect(templates, hasLength(1));
    });
  });

  group('StarterCatalogEngine with a custom source', () {
    test('uses the injected source abstraction', () async {
      final source = _FakeSource(<CatalogTemplate>[
        _template(id: 'demo-v1', storeType: StoreType.pharmacy),
      ]);
      final engine = StarterCatalogEngine(source);
      final loaded = await engine.loadForStoreType(StoreType.pharmacy);
      expect(loaded.id, 'demo-v1');
      expect(source.loadTemplatesCalls, 0);
    });
  });
}
