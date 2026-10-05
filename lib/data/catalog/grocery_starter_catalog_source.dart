import '../../application/catalog/catalog_template.dart';
import '../../application/catalog/in_memory_starter_catalog_source.dart';
import '../../application/catalog/starter_catalog_source.dart';
import 'grocery_starter_catalog.dart';

/// Builds a [StarterCatalogSource] backed by the existing reconstructed
/// `grocery-v1` fixture.
///
/// This does not create a second grocery catalog; it only wraps
/// [buildGroceryStarterCatalog] in the in-memory source abstraction.
StarterCatalogSource buildGroceryStarterCatalogSource() =>
    InMemoryStarterCatalogSource(
      templates: <CatalogTemplate>[buildGroceryStarterCatalog()],
    );
