import 'package:awtad_retail/awtad_retail.dart' as awtad;
import 'package:awtad_retail/application/application.dart' as application;
import 'package:awtad_retail/data/data.dart' as data;
import 'package:awtad_retail/domain/domain.dart' as domain;
import 'package:test/test.dart';

void main() {
  group('public API barrels', () {
    test('package barrel exposes the canonical types', () {
      expect(awtad.StoreId('s'), isA<domain.StoreId>());
      expect(awtad.MerchantId('m'), isA<domain.MerchantId>());
      expect(awtad.ProductId('p'), isA<domain.ProductId>());
      expect(awtad.CategoryId('c'), isA<domain.CategoryId>());
      expect(awtad.InventoryItemId('i'), isA<domain.InventoryItemId>());
      expect(awtad.StoreType.grocery, isA<domain.StoreType>());
      expect(awtad.CurrencyCode.yemeniRial, isA<domain.CurrencyCode>());
      expect(awtad.LanguageCode.arabic, isA<domain.LanguageCode>());
      expect(awtad.ProductUnit.kg, isA<domain.ProductUnit>());
      expect(awtad.Quantity.zero, isA<domain.Quantity>());
    });

    test('package barrel exposes the application and data layers', () {
      expect(
        awtad.InMemoryMerchantInventoryRepository(),
        isA<application.MerchantInventoryRepository>(),
      );
      expect(awtad.buildGroceryStarterCatalog(),
          isA<application.CatalogTemplate>());
      expect(data.buildGroceryStarterCatalog(), isA<awtad.CatalogTemplate>());
    });

    test('canonical StoreType is shared and not duplicated', () {
      expect(awtad.StoreType.grocery, awtad.StoreType.parse('grocery'));
      expect(awtad.buildGroceryStarterCatalog().storeType,
          awtad.StoreType.grocery);
    });
  });

  group('root package:awtad_retail/awtad_retail.dart consumer API', () {
    test('exposes remaining canonical domain types', () {
      expect(
        awtad.Store(
          id: awtad.StoreId('s1'),
          merchantId: awtad.MerchantId('m1'),
          name: awtad.StoreName('Main'),
          type: awtad.StoreType.grocery,
          defaultCurrency: awtad.CurrencyCode.yemeniRial,
          defaultLanguage: awtad.LanguageCode.arabic,
        ),
        isA<awtad.Store>(),
      );
      expect(awtad.StoreName('Main'), isA<awtad.StoreName>());
      expect(awtad.Barcode('123'), isA<awtad.Barcode>());
      expect(awtad.BarcodeType.ean13, isA<awtad.BarcodeType>());
      expect(
        awtad.Category(id: awtad.CategoryId('c1'), name: 'C'),
        isA<awtad.Category>(),
      );
      expect(
        awtad.Product(
          id: awtad.ProductId('p1'),
          genericName: 'Milk',
          categoryId: awtad.CategoryId('c1'),
          unit: awtad.ProductUnit.litre,
        ),
        isA<awtad.Product>(),
      );
      expect(awtad.ProductImageRef('a.png'), isA<awtad.ProductImageRef>());
      expect(awtad.SupplierId('s1'), isA<awtad.SupplierId>());
      expect(
        awtad.MerchantInventoryItem(
          id: awtad.InventoryItemId('i1'),
          merchantId: awtad.MerchantId('m1'),
          productId: awtad.ProductId('p1'),
          quantity: awtad.Quantity.zero,
        ),
        isA<awtad.MerchantInventoryItem>(),
      );
      expect(
        const awtad.Money(
          currency: awtad.CurrencyCode.usDollar,
          minorUnits: 100,
        ),
        isA<awtad.Money>(),
      );
    });

    test('exposes catalog application contracts', () {
      expect(awtad.InMemoryStarterCatalogSource(),
          isA<awtad.StarterCatalogSource>());
      expect(
        awtad.CatalogTemplate(
          id: 't',
          version: '1',
          storeType: awtad.StoreType.grocery,
          name: 'T',
          categories: const <awtad.Category>[],
          entries: const <awtad.CatalogEntry>[],
        ),
        isA<awtad.CatalogTemplate>(),
      );
      expect(
        awtad.CatalogEntry(
          product: awtad.Product(
            id: awtad.ProductId('p1'),
            genericName: 'P',
            categoryId: awtad.CategoryId('c1'),
            unit: awtad.ProductUnit.piece,
          ),
          sortOrder: 1,
        ),
        isA<awtad.CatalogEntry>(),
      );
      expect(
        awtad.CatalogProductSelection(merchantId: awtad.MerchantId('m1')),
        isA<awtad.CatalogProductSelection>(),
      );
      expect(
        awtad.CatalogSelectionItem(
          product: awtad.Product(
            id: awtad.ProductId('p1'),
            genericName: 'P',
            categoryId: awtad.CategoryId('c1'),
            unit: awtad.ProductUnit.piece,
          ),
          quantity: awtad.Quantity.zero,
        ),
        isA<awtad.CatalogSelectionItem>(),
      );
      expect(
        awtad.StarterCatalogEngine(awtad.InMemoryStarterCatalogSource()),
        isA<awtad.StarterCatalogEngine>(),
      );
      expect(
        awtad.LoadedStarterCatalog(
          awtad.CatalogTemplate(
            id: 't',
            version: '1',
            storeType: awtad.StoreType.grocery,
            name: 'T',
            categories: const <awtad.Category>[],
            entries: const <awtad.CatalogEntry>[],
          ),
        ),
        isA<awtad.LoadedStarterCatalog>(),
      );
    });

    test('exposes inventory application contracts', () {
      final repository = awtad.InMemoryMerchantInventoryRepository();
      expect(repository, isA<awtad.MerchantInventoryRepository>());
      expect(awtad.MerchantInventoryService(repository),
          isA<awtad.MerchantInventoryService>());
    });

    test('exposes public application exceptions', () {
      expect(
        awtad.StarterCatalogNotFoundException(awtad.StoreType.pharmacy),
        isA<Exception>(),
      );
      expect(
        awtad.MerchantMismatchException(
          expected: awtad.MerchantId('a'),
          actual: awtad.MerchantId('b'),
        ),
        isA<Exception>(),
      );
      expect(
        awtad.InventoryItemNotFoundException(
          merchantId: awtad.MerchantId('m'),
          itemId: awtad.InventoryItemId('i'),
        ),
        isA<Exception>(),
      );
      expect(
        awtad.DuplicateInventoryItemException(
          merchantId: awtad.MerchantId('m'),
          productId: awtad.ProductId('p'),
        ),
        isA<Exception>(),
      );
    });

    test('exposes grocery-v1 builder and source without a second catalog', () {
      final template = awtad.buildGroceryStarterCatalog();
      final source = awtad.buildGroceryStarterCatalogSource();
      expect(template, isA<awtad.CatalogTemplate>());
      expect(source, isA<awtad.StarterCatalogSource>());
      expect(template.id, 'grocery-v1');
      expect(template.version, '1');
    });
  });

  group('layer barrels', () {
    test('domain barrel exposes the same canonical types as the root API', () {
      expect(domain.StoreId('s'), isA<awtad.StoreId>());
      expect(domain.StoreName('N'), isA<awtad.StoreName>());
      expect(domain.StoreType.grocery, isA<awtad.StoreType>());
      expect(domain.MerchantId('m'), isA<awtad.MerchantId>());
      expect(domain.ProductId('p'), isA<awtad.ProductId>());
      expect(domain.ProductUnit.kg, isA<awtad.ProductUnit>());
      expect(domain.Barcode('1'), isA<awtad.Barcode>());
      expect(domain.CategoryId('c'), isA<awtad.CategoryId>());
      expect(domain.Quantity.zero, isA<awtad.Quantity>());
      expect(domain.InventoryItemId('i'), isA<awtad.InventoryItemId>());
      expect(domain.SupplierId('s'), isA<awtad.SupplierId>());
      expect(domain.CurrencyCode.yemeniRial, isA<awtad.CurrencyCode>());
      expect(domain.LanguageCode.arabic, isA<awtad.LanguageCode>());
    });

    test('application barrel exposes catalog and inventory contracts', () {
      expect(application.InMemoryStarterCatalogSource(),
          isA<awtad.StarterCatalogSource>());
      expect(
        application.StarterCatalogEngine(
          application.InMemoryStarterCatalogSource(),
        ),
        isA<awtad.StarterCatalogEngine>(),
      );
      expect(
        application.InMemoryMerchantInventoryRepository(),
        isA<awtad.MerchantInventoryRepository>(),
      );
      expect(
        application.StarterCatalogNotFoundException(awtad.StoreType.cafe),
        isA<awtad.StarterCatalogNotFoundException>(),
      );
    });

    test('data barrel exposes grocery-v1 builder and source only', () {
      expect(data.buildGroceryStarterCatalog(), isA<awtad.CatalogTemplate>());
      expect(data.buildGroceryStarterCatalogSource(),
          isA<awtad.StarterCatalogSource>());
    });
  });
}
