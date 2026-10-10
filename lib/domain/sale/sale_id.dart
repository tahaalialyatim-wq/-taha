/// Canonical identity of a completed [Sale].
class SaleId {
  SaleId(String value) : value = _validate(value);

  final String value;

  static String _validate(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) {
      throw ArgumentError.value(value, 'value', 'SaleId must not be empty');
    }
    return trimmed;
  }

  @override
  bool operator ==(Object other) => other is SaleId && other.value == value;

  @override
  int get hashCode => value.hashCode;

  @override
  String toString() => 'SaleId($value)';
}
