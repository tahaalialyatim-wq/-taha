import '../../domain/catalog/category.dart';
import '../../domain/catalog/category_id.dart';
import '../../domain/catalog/product.dart';
import '../../domain/catalog/product_id.dart';
import '../../domain/store/store_type.dart';
import 'catalog_entry.dart';

/// An immutable starter catalog definition.
///
/// A template groups [categories] and [entries] for a specific [storeType].
/// It never contains mutable session state.
class CatalogTemplate {
  CatalogTemplate({
    required this.id,
    required this.version,
    required this.storeType,
    required this.name,
    required List<Category> categories,
    required List<CatalogEntry> entries,
    List<ProductId> recommendedProductIds = const <ProductId>[],
  })  : categories = List<Category>.unmodifiable(categories),
        entries = List<CatalogEntry>.unmodifiable(entries),
        recommendedProductIds =
            List<ProductId>.unmodifiable(recommendedProductIds);

  final String id;
  final String version;
  final StoreType storeType;
  final String name;
  final List<Category> categories;
  final List<CatalogEntry> entries;
  final List<ProductId> recommendedProductIds;

  int get productCount => entries.length;

  int get categoryCount => categories.length;

  /// An unmodifiable list of every product in the template.
  List<Product> get products =>
      List<Product>.unmodifiable(entries.map((entry) => entry.product));

  /// An unmodifiable list of every product id, in template order.
  List<ProductId> get productIds =>
      List<ProductId>.unmodifiable(entries.map((entry) => entry.product.id));

  CatalogEntry? entryFor(ProductId id) {
    for (final entry in entries) {
      if (entry.product.id == id) {
        return entry;
      }
    }
    return null;
  }

  Product? productById(ProductId id) => entryFor(id)?.product;

  Category? categoryById(CategoryId id) {
    for (final category in categories) {
      if (category.id == id) {
        return category;
      }
    }
    return null;
  }

  /// Entries belonging to [categoryId], in template order.
  List<CatalogEntry> entriesForCategory(CategoryId categoryId) {
    return List<CatalogEntry>.unmodifiable(
      entries.where((entry) => entry.product.categoryId == categoryId),
    );
  }

  /// Searches the template.
  ///
  /// Ranking (best first): barcodeExact, nameExact, nameStartsWith, aliasExact,
  /// nameContains, aliasContains. Ties are broken by [CatalogEntry.sortOrder].
  /// An empty query returns an empty list.
  List<Product> search(String query) {
    final normalized = query.trim().toLowerCase();
    if (normalized.isEmpty) {
      return const <Product>[];
    }
    final matches = <CatalogEntry>[];
    for (final entry in entries) {
      if (_rank(entry.product, normalized) >= 0) {
        matches.add(entry);
      }
    }
    matches.sort((a, b) {
      final byRank = _rank(a.product, normalized).compareTo(
        _rank(b.product, normalized),
      );
      if (byRank != 0) {
        return byRank;
      }
      return a.sortOrder.compareTo(b.sortOrder);
    });
    return List<Product>.unmodifiable(matches.map((entry) => entry.product));
  }

  static int _rank(Product product, String query) {
    if (product.barcodes.any((b) => b.value.toLowerCase() == query)) {
      return 0;
    }
    final name = product.genericName.toLowerCase();
    if (name == query) {
      return 1;
    }
    if (name.startsWith(query)) {
      return 2;
    }
    if (product.searchAliases.any((a) => a.toLowerCase() == query)) {
      return 3;
    }
    if (name.contains(query)) {
      return 4;
    }
    if (product.searchAliases.any((a) => a.toLowerCase().contains(query))) {
      return 5;
    }
    return -1;
  }
}
