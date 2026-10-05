import 'package:awtad_retail/awtad_retail.dart';
import 'package:test/test.dart';

Product _product(String id, {ProductUnit unit = ProductUnit.kg}) => Product(
      id: ProductId(id),
      genericName: id,
      categoryId: CategoryId('c1'),
      unit: unit,
    );

CatalogTemplate _template() => CatalogTemplate(
      id: 'demo-v1',
      version: '1',
      storeType: StoreType.grocery,
      name: 'Demo',
      categories: <Category>[
        Category(id: CategoryId('c1'), name: 'One'),
      ],
      entries: <CatalogEntry>[
        CatalogEntry(product: _product('p1'), sortOrder: 1),
        CatalogEntry(product: _product('p2'), sortOrder: 2),
      ],
    );

void main() {
  late MerchantInventoryService service;
  final merchant = MerchantId('m1');

  setUp(() {
    service = MerchantInventoryService(InMemoryMerchantInventoryRepository());
  });

  group('Quantity in selection', () {
    test('selection stores ProductId and Quantity only', () {
      final template = _template();
      final selection =
          CatalogProductSelection(merchantId: merchant, template: template);
      final quantity = Quantity.of(ProductUnit.kg, 1500);
      selection.select(ProductId('p1'), quantity: quantity);
      final selected = selection.getSelected().single;
      expect(selected.product.id, ProductId('p1'));
      expect(selected.quantity, quantity);
      expect(selected.quantity.milliUnits, 1500);
    });

    test('selection does not mutate Product, CatalogEntry, CatalogTemplate',
        () {
      final template = _template();
      final selection =
          CatalogProductSelection(merchantId: merchant, template: template);
      selection.select(ProductId('p1'), quantity: Quantity.whole(3));
      selection.setQuantity(ProductId('p1'), Quantity.of(ProductUnit.kg, 750));
      expect(template.productCount, 2);
      expect(template.entries.first.sortOrder, 1);
      expect(() => template.products.first.barcodes.add(Barcode('1')),
          throwsUnsupportedError);
      expect(() => selection.getSelected().add(selection.getSelected().first),
          throwsUnsupportedError);
    });
  });

  group('Selection to inventory confirmation', () {
    test('confirm retains MerchantId and uses ProductId, not catalog ownership',
        () async {
      final template = _template();
      final selection =
          CatalogProductSelection(merchantId: merchant, template: template);
      selection.select(ProductId('p1'),
          quantity: Quantity.of(ProductUnit.kg, 1500));
      final created = await selection.confirm(service);
      final item = created.single;
      expect(item.merchantId, merchant);
      expect(item.productId, ProductId('p1'));
      expect(item.id, isA<InventoryItemId>());
      expect(item.quantity, Quantity.of(ProductUnit.kg, 1500));
    });

    test('confirm preserves Quantity exactly', () async {
      final template = _template();
      final selection =
          CatalogProductSelection(merchantId: merchant, template: template);
      final quantity = Quantity.of(ProductUnit.kg, 750);
      selection.select(ProductId('p1'), quantity: quantity);
      final item = (await selection.confirm(service)).single;
      expect(item.quantity, quantity);
      expect(item.quantity.milliUnits, 750);
      expect(identical(item.quantity, quantity) || item.quantity == quantity,
          isTrue);
    });

    test('confirm does not invent price, barcode or extra catalog data',
        () async {
      final template = _template();
      final selection =
          CatalogProductSelection(merchantId: merchant, template: template);
      selection.select(ProductId('p1'), quantity: Quantity.whole(1));
      final item = (await selection.confirm(service)).single;
      expect(item.sellingPrice, isNull);
      expect(item.purchasePrice, isNull);
      expect(item.minimumStock, isNull);
    });

    test(
        'confirm does not create duplicate inventory for the same merchant/product',
        () async {
      final template = _template();
      await service.addProduct(merchant, ProductId('p1'),
          quantity: Quantity.whole(1));
      final selection =
          CatalogProductSelection(merchantId: merchant, template: template);
      selection.select(ProductId('p1'), quantity: Quantity.whole(4));
      await selection.confirm(service);
      final all = await service.getAll(merchant);
      expect(all, hasLength(1));
      expect(all.single.productId, ProductId('p1'));
      expect(all.single.merchantId, merchant);
      expect(all.single.quantity, Quantity.whole(4));
    });

    test('confirm does not mutate catalog or source objects', () async {
      final template = _template();
      final source = InMemoryStarterCatalogSource(
        templates: <CatalogTemplate>[template],
      );
      final selection =
          CatalogProductSelection(merchantId: merchant, template: template);
      selection.select(ProductId('p1'), quantity: Quantity.whole(2));
      final created = await selection.confirm(service);
      expect(() => created.add(created.first), throwsUnsupportedError);
      expect(template.productCount, 2);
      expect(template.storeType, StoreType.grocery);
      expect(await source.loadTemplates(), hasLength(1));
    });

    test('inventory remains merchant-owned; product remains catalog-owned',
        () async {
      final template = _template();
      final selection =
          CatalogProductSelection(merchantId: merchant, template: template);
      selection.select(ProductId('p1'), quantity: Quantity.whole(2));
      expect(await service.getAll(merchant), isEmpty);
      final item = (await selection.confirm(service)).single;
      expect(item.merchantId, merchant);
      expect(template.productById(ProductId('p1')), isNotNull);
      expect(template.productById(ProductId('p1'))!.id, ProductId('p1'));
    });

    test('InventoryItemId is inventory identity only and StoreId is not used',
        () async {
      final template = _template();
      final selection =
          CatalogProductSelection(merchantId: merchant, template: template);
      selection.select(ProductId('p1'), quantity: Quantity.whole(1));
      final item = (await selection.confirm(service)).single;
      expect(item.id, isA<InventoryItemId>());
      expect(item.merchantId, isA<MerchantId>());
      expect(item.productId, isA<ProductId>());
      expect(item.merchantId, isNot(isA<StoreId>()));
    });
  });
}
