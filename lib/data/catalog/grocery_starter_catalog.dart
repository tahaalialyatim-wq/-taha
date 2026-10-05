import '../../application/catalog/catalog_entry.dart';
import '../../application/catalog/catalog_template.dart';
import '../../domain/catalog/category.dart';
import '../../domain/catalog/category_id.dart';
import '../../domain/catalog/product.dart';
import '../../domain/catalog/product_id.dart';
import '../../domain/catalog/product_unit.dart';
import '../../domain/store/store_type.dart';

/// Builds the deterministic `grocery-v1` starter catalog template.
///
/// The template has exactly 9 categories and 45 products, is associated with
/// [StoreType.grocery], keeps deterministic ordering and its products have no
/// barcodes and no prices.
///
/// NOTE: the historical implementation's exact category/product identities were
/// not available in this environment, so the identities and names below are a
/// reconstructed structural fixture (see the completion report).
CatalogTemplate buildGroceryStarterCatalog() {
  final categories = <Category>[
    _category('cat-fruits-vegetables', 'Fruits & Vegetables'),
    _category('cat-dairy-eggs', 'Dairy & Eggs'),
    _category('cat-bakery', 'Bread & Bakery'),
    _category('cat-grains', 'Rice, Grains & Pulses'),
    _category('cat-oils-ghee', 'Oils & Ghee'),
    _category('cat-beverages', 'Beverages'),
    _category('cat-canned-packaged', 'Canned & Packaged Foods'),
    _category('cat-spices-condiments', 'Spices & Condiments'),
    _category('cat-cleaning-household', 'Cleaning & Household'),
  ];

  final definitions = <_ProductDefinition>[
    _p('prod-apple', 'Apple', 'cat-fruits-vegetables', ProductUnit.piece,
        const ['تفاح']),
    _p('prod-banana', 'Banana', 'cat-fruits-vegetables', ProductUnit.piece,
        const ['موز']),
    _p('prod-tomato', 'Tomato', 'cat-fruits-vegetables', ProductUnit.kg,
        const ['طماطم']),
    _p('prod-potato', 'Potato', 'cat-fruits-vegetables', ProductUnit.kg,
        const ['بطاطس', 'بطاطا']),
    _p('prod-onion', 'Onion', 'cat-fruits-vegetables', ProductUnit.kg,
        const ['بصل']),
    _p('prod-milk', 'Milk', 'cat-dairy-eggs', ProductUnit.litre,
        const ['حليب']),
    _p('prod-yogurt', 'Yogurt', 'cat-dairy-eggs', ProductUnit.g,
        const ['زبادي', 'روب']),
    _p('prod-labneh', 'Labneh', 'cat-dairy-eggs', ProductUnit.g,
        const ['لبنة']),
    _p('prod-white-cheese', 'White Cheese', 'cat-dairy-eggs', ProductUnit.g,
        const ['جبن أبيض']),
    _p('prod-eggs', 'Eggs', 'cat-dairy-eggs', ProductUnit.carton,
        const ['بيض']),
    _p('prod-flatbread', 'Flatbread', 'cat-bakery', ProductUnit.piece,
        const ['خبز']),
    _p('prod-brown-bread', 'Brown Bread', 'cat-bakery', ProductUnit.piece,
        const ['خبز أسمر']),
    _p('prod-baguette', 'Baguette', 'cat-bakery', ProductUnit.piece,
        const ['باغيت']),
    _p('prod-burger-buns', 'Burger Buns', 'cat-bakery', ProductUnit.piece,
        const ['خبز برجر']),
    _p('prod-samoon', 'Samoon', 'cat-bakery', ProductUnit.piece,
        const ['صمون']),
    _p('prod-basmati-rice', 'Basmati Rice', 'cat-grains', ProductUnit.kg,
        const ['أرز بسمتي']),
    _p('prod-lentils', 'Lentils', 'cat-grains', ProductUnit.kg, const ['عدس']),
    _p('prod-chickpeas', 'Chickpeas', 'cat-grains', ProductUnit.kg,
        const ['حمص']),
    _p('prod-wheat-flour', 'Wheat Flour', 'cat-grains', ProductUnit.kg,
        const ['طحين', 'دقيق']),
    _p('prod-sugar', 'Sugar', 'cat-grains', ProductUnit.kg, const ['سكر']),
    _p('prod-sunflower-oil', 'Sunflower Oil', 'cat-oils-ghee',
        ProductUnit.litre, const ['زيت عباد الشمس']),
    _p('prod-olive-oil', 'Olive Oil', 'cat-oils-ghee', ProductUnit.litre,
        const ['زيت زيتون']),
    _p('prod-ghee', 'Ghee', 'cat-oils-ghee', ProductUnit.g, const ['سمن']),
    _p('prod-vegetable-shortening', 'Vegetable Shortening', 'cat-oils-ghee',
        ProductUnit.g, const ['سمن نباتي']),
    _p('prod-sesame-oil', 'Sesame Oil', 'cat-oils-ghee', ProductUnit.litre,
        const ['زيت سمسم']),
    _p('prod-drinking-water', 'Drinking Water', 'cat-beverages',
        ProductUnit.litre, const ['ماء']),
    _p('prod-orange-juice', 'Orange Juice', 'cat-beverages', ProductUnit.litre,
        const ['عصير برتقال']),
    _p('prod-cola', 'Cola', 'cat-beverages', ProductUnit.millilitre,
        const ['كولا']),
    _p('prod-tea', 'Tea', 'cat-beverages', ProductUnit.kg, const ['شاي']),
    _p('prod-coffee', 'Coffee', 'cat-beverages', ProductUnit.kg,
        const ['قهوة']),
    _p('prod-canned-tuna', 'Canned Tuna', 'cat-canned-packaged', ProductUnit.g,
        const ['تونة معلبة']),
    _p('prod-canned-beans', 'Canned Beans', 'cat-canned-packaged',
        ProductUnit.g, const ['فاصوليا معلبة']),
    _p('prod-tomato-paste', 'Tomato Paste', 'cat-canned-packaged',
        ProductUnit.g, const ['معجون طماطم']),
    _p('prod-pasta', 'Pasta', 'cat-canned-packaged', ProductUnit.g,
        const ['معكرونة', 'مكرونة']),
    _p('prod-biscuits', 'Biscuits', 'cat-canned-packaged', ProductUnit.g,
        const ['بسكويت']),
    _p('prod-salt', 'Salt', 'cat-spices-condiments', ProductUnit.kg,
        const ['ملح']),
    _p('prod-black-pepper', 'Black Pepper', 'cat-spices-condiments',
        ProductUnit.g, const ['فلفل أسود']),
    _p('prod-cumin', 'Cumin', 'cat-spices-condiments', ProductUnit.g,
        const ['كمون']),
    _p('prod-turmeric', 'Turmeric', 'cat-spices-condiments', ProductUnit.g,
        const ['كركم']),
    _p('prod-vinegar', 'Vinegar', 'cat-spices-condiments', ProductUnit.litre,
        const ['خل']),
    _p('prod-dish-soap', 'Dish Soap', 'cat-cleaning-household',
        ProductUnit.millilitre, const ['صابون غسيل الأطباق']),
    _p('prod-laundry-detergent', 'Laundry Detergent', 'cat-cleaning-household',
        ProductUnit.kg, const ['مسحوق غسيل']),
    _p('prod-bleach', 'Bleach', 'cat-cleaning-household', ProductUnit.litre,
        const ['كلور', 'مبيض']),
    _p('prod-paper-towels', 'Paper Towels', 'cat-cleaning-household',
        ProductUnit.piece, const ['مناديل ورقية']),
    _p('prod-facial-tissues', 'Facial Tissues', 'cat-cleaning-household',
        ProductUnit.box, const ['مناديل']),
  ];

  final entries = <CatalogEntry>[
    for (var i = 0; i < definitions.length; i++)
      CatalogEntry(
        product: definitions[i].toProduct(),
        sortOrder: i + 1,
      ),
  ];

  return CatalogTemplate(
    id: 'grocery-v1',
    version: '1',
    storeType: StoreType.grocery,
    name: 'Grocery Starter Catalog',
    categories: categories,
    entries: entries,
    recommendedProductIds: <ProductId>[
      ProductId('prod-apple'),
      ProductId('prod-milk'),
      ProductId('prod-flatbread'),
      ProductId('prod-basmati-rice'),
      ProductId('prod-sunflower-oil'),
      ProductId('prod-drinking-water'),
      ProductId('prod-pasta'),
      ProductId('prod-salt'),
      ProductId('prod-dish-soap'),
    ],
  );
}

Category _category(String id, String name) => Category(
      id: CategoryId(id),
      name: name,
      relevantStoreTypes: <StoreType>{StoreType.grocery},
    );

_ProductDefinition _p(
  String id,
  String name,
  String categoryId,
  ProductUnit unit,
  List<String> aliases,
) =>
    _ProductDefinition(id, name, categoryId, unit, aliases);

class _ProductDefinition {
  const _ProductDefinition(
    this.id,
    this.name,
    this.categoryId,
    this.unit,
    this.aliases,
  );

  final String id;
  final String name;
  final String categoryId;
  final ProductUnit unit;
  final List<String> aliases;

  Product toProduct() => Product(
        id: ProductId(id),
        genericName: name,
        categoryId: CategoryId(categoryId),
        unit: unit,
        searchAliases: aliases,
      );
}
