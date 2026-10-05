/// Canonical identity of a merchant inventory item.
class InventoryItemId {
  InventoryItemId(String value) : value = _validate(value);

  final String value;

  static String _validate(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) {
      throw ArgumentError.value(
        value,
        'value',
        'InventoryItemId must not be empty',
      );
    }
    return trimmed;
  }

  @override
  bool operator ==(Object other) =>
      other is InventoryItemId && other.value == value;

  @override
  int get hashCode => value.hashCode;

  @override
  String toString() => 'InventoryItemId($value)';
}
