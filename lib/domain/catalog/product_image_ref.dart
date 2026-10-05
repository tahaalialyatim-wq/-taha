/// A lightweight reference to a product image.
///
/// This is only a reference (for example a path or key). It intentionally does
/// not contain any image loading, network or cloud behaviour.
class ProductImageRef {
  ProductImageRef(String value) : value = _validate(value);

  final String value;

  static String _validate(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) {
      throw ArgumentError.value(
        value,
        'value',
        'ProductImageRef must not be empty',
      );
    }
    return trimmed;
  }

  @override
  bool operator ==(Object other) =>
      other is ProductImageRef && other.value == value;

  @override
  int get hashCode => value.hashCode;

  @override
  String toString() => 'ProductImageRef($value)';
}
