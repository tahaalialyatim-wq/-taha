import '../../domain/catalog/product.dart';
import '../../domain/catalog/quantity.dart';

/// An immutable snapshot of a selected catalog product and its quantity.
class CatalogSelectionItem {
  const CatalogSelectionItem({required this.product, required this.quantity});

  final Product product;
  final Quantity quantity;
}
