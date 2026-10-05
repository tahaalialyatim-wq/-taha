import '../../domain/merchant/merchant_id.dart';
import '../../domain/store/store_type.dart';
import 'catalog_product_selection.dart';
import 'loaded_starter_catalog.dart';
import 'starter_catalog_exceptions.dart';
import 'starter_catalog_source.dart';

/// Orchestrates loading a starter catalog for a [StoreType].
///
/// The engine only uses the [StarterCatalogSource] abstraction, preserves the
/// catalog's deterministic identity and version, and never mutates products,
/// categories, templates or source data.
class StarterCatalogEngine {
  StarterCatalogEngine(this.source);

  final StarterCatalogSource source;

  /// Loads the catalog associated with [storeType].
  ///
  /// Throws [StarterCatalogNotFoundException] when the source has no catalog
  /// for [storeType].
  Future<LoadedStarterCatalog> loadForStoreType(StoreType storeType) async {
    final template = await source.loadForStoreType(storeType);
    if (template == null) {
      throw StarterCatalogNotFoundException(storeType);
    }
    return LoadedStarterCatalog(template);
  }

  /// Loads a catalog for [storeType] and creates a [CatalogProductSelection]
  /// for [merchantId] over the existing catalog flow model.
  Future<CatalogProductSelection> createSelection(
    MerchantId merchantId,
    StoreType storeType,
  ) async {
    final loaded = await loadForStoreType(storeType);
    return loaded.createSelection(merchantId);
  }
}
