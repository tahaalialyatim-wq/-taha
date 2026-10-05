import '../../domain/store/store_type.dart';

/// Thrown when no starter catalog is available for a [storeType].
class StarterCatalogNotFoundException implements Exception {
  const StarterCatalogNotFoundException(this.storeType);

  final StoreType storeType;

  @override
  String toString() => 'StarterCatalogNotFoundException(${storeType.value})';
}
