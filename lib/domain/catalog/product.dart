import 'barcode.dart';
import 'category_id.dart';
import 'product_id.dart';
import 'product_image_ref.dart';
import 'product_unit.dart';

/// A globally catalog owned product.
///
/// Products contain no merchant inventory fields. Equality and [hashCode] are
/// based on [id] only. Public collections are unmodifiable.
class Product {
  Product({
    required this.id,
    required String genericName,
    required this.categoryId,
    required this.unit,
    List<Barcode> barcodes = const <Barcode>[],
    String? brand,
    List<String> searchAliases = const <String>[],
    this.image,
  })  : genericName = _validateName(genericName),
        brand = _validateOptional(brand),
        barcodes = List<Barcode>.unmodifiable(barcodes),
        searchAliases = List<String>.unmodifiable(searchAliases);

  final ProductId id;
  final String genericName;
  final CategoryId categoryId;
  final ProductUnit unit;
  final List<Barcode> barcodes;
  final String? brand;
  final List<String> searchAliases;
  final ProductImageRef? image;

  static String _validateName(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) {
      throw ArgumentError.value(
        value,
        'genericName',
        'Product generic name must not be empty',
      );
    }
    return trimmed;
  }

  static String? _validateOptional(String? value) {
    if (value == null) {
      return null;
    }
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  @override
  bool operator ==(Object other) => other is Product && other.id == id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'Product($id, $genericName)';
}
