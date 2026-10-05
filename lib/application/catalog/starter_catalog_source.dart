import '../../domain/store/store_type.dart';
import 'catalog_template.dart';

/// Abstraction for obtaining starter catalog templates.
///
/// A source only supplies immutable [CatalogTemplate] definitions. It does not
/// own merchant inventory and contains no UI, persistence, HTTP, cloud, AI or
/// pricing behaviour.
abstract class StarterCatalogSource {
  /// Returns an unmodifiable snapshot of every available template.
  ///
  /// Implementations must return the same definitions for repeated calls so
  /// that loading is deterministic.
  Future<List<CatalogTemplate>> loadTemplates();

  /// Returns the template associated with [storeType], or `null` when the
  /// source has no template for it.
  Future<CatalogTemplate?> loadForStoreType(StoreType storeType);
}
