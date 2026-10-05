import '../../domain/store/store_type.dart';
import 'catalog_template.dart';
import 'starter_catalog_source.dart';

/// The smallest in-memory [StarterCatalogSource].
///
/// It wraps an immutable list of already-built [CatalogTemplate] definitions.
/// It does not build or duplicate catalog data itself.
class InMemoryStarterCatalogSource implements StarterCatalogSource {
  InMemoryStarterCatalogSource({
    List<CatalogTemplate> templates = const <CatalogTemplate>[],
  }) : _templates = List<CatalogTemplate>.unmodifiable(templates);

  final List<CatalogTemplate> _templates;

  @override
  Future<List<CatalogTemplate>> loadTemplates() async =>
      List<CatalogTemplate>.unmodifiable(_templates);

  @override
  Future<CatalogTemplate?> loadForStoreType(StoreType storeType) async {
    for (final template in _templates) {
      if (template.storeType == storeType) {
        return template;
      }
    }
    return null;
  }
}
