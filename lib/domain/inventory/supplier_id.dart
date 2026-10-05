/// Identifier for a supplier.
class SupplierId {
  SupplierId(String value) : value = _validate(value);

  final String value;

  static String _validate(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) {
      throw ArgumentError.value(value, 'value', 'SupplierId must not be empty');
    }
    return trimmed;
  }

  @override
  bool operator ==(Object other) => other is SupplierId && other.value == value;

  @override
  int get hashCode => value.hashCode;

  @override
  String toString() => 'SupplierId($value)';
}
