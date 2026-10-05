import '../../domain/catalog/product.dart';

/// An immutable catalog entry binding a [product] to its deterministic
/// [sortOrder] inside a catalog template.
class CatalogEntry {
  const CatalogEntry({required this.product, required this.sortOrder});

  final Product product;
  final int sortOrder;
}
