/// Canonical identifier for a merchant.
///
/// A [MerchantId] is a value object: it trims its input, rejects empty or
/// whitespace-only values, and compares by value.
class MerchantId {
  MerchantId(String value) : value = _validate(value);

  final String value;

  static String _validate(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) {
      throw ArgumentError.value(value, 'value', 'MerchantId must not be empty');
    }
    return trimmed;
  }

  @override
  bool operator ==(Object other) => other is MerchantId && other.value == value;

  @override
  int get hashCode => value.hashCode;

  @override
  String toString() => 'MerchantId($value)';
}
