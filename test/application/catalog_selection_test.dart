import 'package:awtad_retail/awtad_retail.dart';
import 'package:test/test.dart';

Product product(String id, String category) => Product(
      id: ProductId(id),
      genericName: id,
      categoryId: CategoryId(category),
      unit: ProductUnit.kg,
    );

CatalogTemplate buildTemplate() => CatalogTemplate(
      id: 't',
      version: '1',
      storeType: StoreType.grocery,
      name: 'Template',
      categories: <Category>[
        Category(id: CategoryId('c1'), name: 'One'),
        Category(id: CategoryId('c2'), name: 'Two'),
      ],
      entries: <CatalogEntry>[
        CatalogEntry(product: product('p1', 'c1'), sortOrder: 1),
        CatalogEntry(product: product('p2', 'c1'), sortOrder: 2),
        CatalogEntry(product: product('p3', 'c2'), sortOrder: 3),
      ],
      recommendedProductIds: <ProductId>[ProductId('p2')],
    );

void main() {
  final merchant = MerchantId('m1');
  late MerchantInventoryService service;

  setUp(() {
    service = MerchantInventoryService(InMemoryMerchantInventoryRepository());
  });

  group('CatalogProductSelection', () {
    test('loads a template', () {
      final selection = CatalogProductSelection(merchantId: merchant);
      expect(selection.isLoaded, isFalse);
      selection.load(buildTemplate());
      expect(selection.isLoaded, isTrue);
    });

    test('browse filters by category and query', () {
      final selection = CatalogProductSelection(
          merchantId: merchant, template: buildTemplate());
      expect(selection.browse(), hasLength(3));
      expect(selection.browse(categoryId: CategoryId('c1')), hasLength(2));
      expect(selection.browse(query: 'p3'), hasLength(1));
    });

    test('select, deselect and getSelected behave as expected', () {
      final selection = CatalogProductSelection(
          merchantId: merchant, template: buildTemplate());
      selection.select(ProductId('p1'), quantity: Quantity.whole(2));
      expect(selection.isSelected(ProductId('p1')), isTrue);
      expect(selection.selectedCount, 1);
      selection.deselect(ProductId('p1'));
      expect(selection.isSelected(ProductId('p1')), isFalse);
    });

    test('getSelected is unmodifiable and does not expose mutable state', () {
      final selection = CatalogProductSelection(
          merchantId: merchant, template: buildTemplate());
      selection.select(ProductId('p1'));
      final selected = selection.getSelected();
      expect(() => selected.add(selected.first), throwsUnsupportedError);
    });

    test('selecting an unknown product throws', () {
      final selection = CatalogProductSelection(
          merchantId: merchant, template: buildTemplate());
      expect(() => selection.select(ProductId('nope')), throwsArgumentError);
    });

    test('setQuantity requires the product to be selected', () {
      final selection = CatalogProductSelection(
          merchantId: merchant, template: buildTemplate());
      expect(
        () => selection.setQuantity(ProductId('p1'), Quantity.whole(1)),
        throwsArgumentError,
      );
      selection.select(ProductId('p1'));
      selection.setQuantity(ProductId('p1'), Quantity.whole(3));
      expect(selection.getSelected().single.quantity, Quantity.whole(3));
    });

    test('loadRecommended selects recommended products at zero', () {
      final selection = CatalogProductSelection(
          merchantId: merchant, template: buildTemplate());
      selection.loadRecommended();
      expect(selection.selectedCount, 1);
      expect(selection.isSelected(ProductId('p2')), isTrue);
      expect(selection.getSelected().single.quantity, Quantity.zero);
    });

    test('selection does not mutate the catalog source', () {
      final template = buildTemplate();
      final selection =
          CatalogProductSelection(merchantId: merchant, template: template);
      selection.select(ProductId('p1'));
      expect(template.productCount, 3);
      expect(template.categories, hasLength(2));
      expect(() => template.products.add(template.products.first),
          throwsUnsupportedError);
    });

    test('confirm creates merchant-owned inventory using ProductId', () async {
      final selection = CatalogProductSelection(
          merchantId: merchant, template: buildTemplate());
      selection.select(ProductId('p1'),
          quantity: Quantity.of(ProductUnit.kg, 1500));
      final created = await selection.confirm(service);
      expect(created, hasLength(1));
      expect(created.single.merchantId, merchant);
      expect(created.single.productId, ProductId('p1'));
      expect(created.single.quantity, Quantity.of(ProductUnit.kg, 1500));
      expect(await service.findByProduct(merchant, ProductId('p1')), isNotNull);
    });

    test('confirm updates existing inventory without duplicating', () async {
      await service.addProduct(merchant, ProductId('p1'));
      final selection = CatalogProductSelection(
          merchantId: merchant, template: buildTemplate());
      selection.select(ProductId('p1'), quantity: Quantity.whole(5));
      await selection.confirm(service);
      final all = await service.getAll(merchant);
      expect(all, hasLength(1));
      expect(all.single.quantity, Quantity.whole(5));
    });
  });
}
