/// Canonical identity of a [CustomerAccountEntry].
class CustomerAccountEntryId {
  CustomerAccountEntryId(String value) : value = _validate(value);

  final String value;

  static String _validate(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) {
      throw ArgumentError.value(
        value,
        'value',
        'CustomerAccountEntryId must not be empty',
      );
    }
    return trimmed;
  }

  @override
  bool operator ==(Object other) =>
      other is CustomerAccountEntryId && other.value == value;

  @override
  int get hashCode => value.hashCode;

  @override
  String toString() => 'CustomerAccountEntryId($value)';
}
