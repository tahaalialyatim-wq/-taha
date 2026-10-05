import '../store/store_type.dart';
import 'category_id.dart';

/// A catalog category.
///
/// Categories are catalog owned. They carry no merchant, stock or price
/// fields. Equality and [hashCode] are based on [id] only.
class Category {
  Category({
    required this.id,
    required String name,
    this.parentId,
    Set<StoreType>? relevantStoreTypes,
    this.isActive = true,
  })  : name = _validateName(name),
        relevantStoreTypes = Set<StoreType>.unmodifiable(
          relevantStoreTypes ?? const <StoreType>{},
        );

  final CategoryId id;
  final String name;
  final CategoryId? parentId;
  final Set<StoreType> relevantStoreTypes;

  /// Whether the category is active. Defaults to `true`.
  final bool isActive;

  static String _validateName(String name) {
    final trimmed = name.trim();
    if (trimmed.isEmpty) {
      throw ArgumentError.value(
          name, 'name', 'Category name must not be empty');
    }
    return trimmed;
  }

  @override
  bool operator ==(Object other) => other is Category && other.id == id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'Category($id, $name)';
}
