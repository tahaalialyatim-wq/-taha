import '../../domain/catalog/category.dart';
import '../../domain/catalog/category_id.dart';
import '../../domain/catalog/product.dart';
import '../../domain/catalog/product_id.dart';
import '../../domain/merchant/merchant_id.dart';
import '../../domain/store/store_type.dart';
import 'catalog_entry.dart';
import 'catalog_product_selection.dart';
import 'catalog_template.dart';

/// An immutable, loaded representation of a [CatalogTemplate].
///
/// The loaded catalog preserves the template identity and version and only
/// exposes immutable catalog data. It never exposes mutable internal
/// collections and cannot mutate the underlying template or source.
class LoadedStarterCatalog {
  const LoadedStarterCatalog(this._template);

  final CatalogTemplate _template;

  /// The underlying immutable template.
  CatalogTemplate get template => _template;

  String get id => _template.id;

  String get version => _template.version;

  StoreType get storeType => _template.storeType;

  String get name => _template.name;

  int get productCount => _template.productCount;

  int get categoryCount => _template.categoryCount;

  /// The template categories, already unmodifiable.
  List<Category> get categories => _template.categories;

  /// The template entries, already unmodifiable.
  List<CatalogEntry> get entries => _template.entries;

  /// The template products, already unmodifiable.
  List<Product> get products => _template.products;

  /// The template product ids, already unmodifiable.
  List<ProductId> get productIds => _template.productIds;

  /// The recommended product ids, already unmodifiable.
  List<ProductId> get recommendedProductIds => _template.recommendedProductIds;

  Category? categoryById(CategoryId id) => _template.categoryById(id);

  Product? productById(ProductId id) => _template.productById(id);

  List<Product> search(String query) => _template.search(query);

  /// Creates a new [CatalogProductSelection] for [merchantId] over this loaded
  /// catalog. The selection is the existing catalog flow model; no competing
  /// model is introduced.
  CatalogProductSelection createSelection(MerchantId merchantId) =>
      CatalogProductSelection(merchantId: merchantId, template: _template);

  @override
  bool operator ==(Object other) =>
      other is LoadedStarterCatalog &&
      other.id == id &&
      other.version == version &&
      other.storeType == storeType &&
      _listEquals(other.productIds, productIds);

  @override
  int get hashCode => Object.hash(id, version, storeType, productIds.length);

  @override
  String toString() => 'LoadedStarterCatalog($id v$version, $storeType)';

  static bool _listEquals<T>(List<T> a, List<T> b) {
    if (a.length != b.length) {
      return false;
    }
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) {
        return false;
      }
    }
    return true;
  }
}
