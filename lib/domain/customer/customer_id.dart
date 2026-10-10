/// Canonical identity of a merchant-owned [Customer].
class CustomerId {
  CustomerId(String value) : value = _validate(value);

  final String value;

  static String _validate(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) {
      throw ArgumentError.value(
        value,
        'value',
        'CustomerId must not be empty',
      );
    }
    return trimmed;
  }

  @override
  bool operator ==(Object other) => other is CustomerId && other.value == value;

  @override
  int get hashCode => value.hashCode;

  @override
  String toString() => 'CustomerId($value)';
}
