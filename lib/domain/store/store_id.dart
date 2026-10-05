/// Canonical identifier for a [Store].
class StoreId {
  StoreId(String value) : value = _validate(value);

  final String value;

  static String _validate(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) {
      throw ArgumentError.value(value, 'value', 'StoreId must not be empty');
    }
    return trimmed;
  }

  @override
  bool operator ==(Object other) => other is StoreId && other.value == value;

  @override
  int get hashCode => value.hashCode;

  @override
  String toString() => 'StoreId($value)';
}
