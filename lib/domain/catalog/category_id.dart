/// Canonical identifier for a catalog [Category].
class CategoryId {
  CategoryId(String value) : value = _validate(value);

  final String value;

  static String _validate(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) {
      throw ArgumentError.value(value, 'value', 'CategoryId must not be empty');
    }
    return trimmed;
  }

  @override
  bool operator ==(Object other) => other is CategoryId && other.value == value;

  @override
  int get hashCode => value.hashCode;

  @override
  String toString() => 'CategoryId($value)';
}
