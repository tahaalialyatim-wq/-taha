import '../../domain/catalog/category_id.dart';
import '../../domain/catalog/product_id.dart';
import '../../domain/catalog/quantity.dart';
import '../../domain/inventory/merchant_inventory_item.dart';
import '../../domain/merchant/merchant_id.dart';
import '../inventory/merchant_inventory_service.dart';
import 'catalog_entry.dart';
import 'catalog_selection_item.dart';
import 'catalog_template.dart';

/// Mutable session state for a starter catalog flow.
///
/// The selection reads from an immutable [CatalogTemplate] and never mutates
/// the template, its entries or its products. Externally exposed collections
/// are unmodifiable.
class CatalogProductSelection {
  CatalogProductSelection({required this.merchantId, CatalogTemplate? template})
      : _template = template;

  final MerchantId merchantId;

  CatalogTemplate? _template;
  final Map<String, CatalogSelectionItem> _selected =
      <String, CatalogSelectionItem>{};

  CatalogTemplate? get template => _template;

  bool get isLoaded => _template != null;

  int get selectedCount => _selected.length;

  /// Loads [template] and clears any current selection.
  void load(CatalogTemplate template) {
    _template = template;
    _selected.clear();
  }

  /// Selects the recommended products of the loaded template at zero quantity.
  void loadRecommended() {
    final template = _requireTemplate();
    _selected.clear();
    for (final productId in template.recommendedProductIds) {
      final product = template.productById(productId);
      if (product != null) {
        _selected[productId.value] =
            CatalogSelectionItem(product: product, quantity: Quantity.zero);
      }
    }
  }

  /// Browses the loaded template, optionally filtered by [categoryId] and
  /// [query]. Results are returned in search ranking order where applicable.
  List<CatalogEntry> browse({CategoryId? categoryId, String? query}) {
    final template = _requireTemplate();
    Iterable<CatalogEntry> candidates = template.entries;
    if (categoryId != null) {
      candidates = candidates.where(
        (entry) => entry.product.categoryId == categoryId,
      );
    }
    final normalized = query?.trim() ?? '';
    if (normalized.isEmpty) {
      return List<CatalogEntry>.unmodifiable(candidates);
    }
    final ranked = template.search(normalized);
    final order = <String, int>{
      for (var i = 0; i < ranked.length; i++) ranked[i].id.value: i,
    };
    final filtered = candidates
        .where((entry) => order.containsKey(entry.product.id.value))
        .toList()
      ..sort(
        (a, b) =>
            order[a.product.id.value]!.compareTo(order[b.product.id.value]!),
      );
    return List<CatalogEntry>.unmodifiable(filtered);
  }

  bool isSelected(ProductId productId) =>
      _selected.containsKey(productId.value);

  /// Selects [productId] with an optional [quantity].
  void select(ProductId productId, {Quantity quantity = Quantity.zero}) {
    final template = _requireTemplate();
    final product = template.productById(productId);
    if (product == null) {
      throw ArgumentError.value(
        productId.value,
        'productId',
        'Product is not part of the loaded catalog template',
      );
    }
    _selected[productId.value] =
        CatalogSelectionItem(product: product, quantity: quantity);
  }

  /// Removes [productId] from the selection.
  void deselect(ProductId productId) {
    _selected.remove(productId.value);
  }

  /// Updates the quantity of an already selected [productId].
  void setQuantity(ProductId productId, Quantity quantity) {
    final current = _selected[productId.value];
    if (current == null) {
      throw ArgumentError.value(
        productId.value,
        'productId',
        'Product is not selected',
      );
    }
    _selected[productId.value] =
        CatalogSelectionItem(product: current.product, quantity: quantity);
  }

  /// An unmodifiable snapshot of the current selection.
  List<CatalogSelectionItem> getSelected() =>
      List<CatalogSelectionItem>.unmodifiable(_selected.values);

  /// Creates merchant-owned inventory for every selected product.
  ///
  /// Uses [MerchantId] and [ProductId] only. Existing items are updated to the
  /// selected quantity; new items are added.
  Future<List<MerchantInventoryItem>> confirm(
    MerchantInventoryService service,
  ) async {
    final created = <MerchantInventoryItem>[];
    for (final selection in _selected.values) {
      final productId = selection.product.id;
      final existing = await service.findByProduct(merchantId, productId);
      if (existing == null) {
        created.add(
          await service.addProduct(
            merchantId,
            productId,
            quantity: selection.quantity,
          ),
        );
      } else {
        created.add(
          await service.setQuantity(merchantId, productId, selection.quantity),
        );
      }
    }
    return List<MerchantInventoryItem>.unmodifiable(created);
  }

  CatalogTemplate _requireTemplate() {
    final template = _template;
    if (template == null) {
      throw StateError('No catalog template has been loaded');
    }
    return template;
  }
}
