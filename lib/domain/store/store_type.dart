/// Strongly typed value object describing the kind of a store.
///
/// This is the single canonical [StoreType] for the whole package. It replaces
/// the historical enum and is shared by both the store domain and the starter
/// catalog.
class StoreType {
  const StoreType._(this.value);

  /// The stable machine value.
  final String value;

  static const StoreType grocery = StoreType._('grocery');
  static const StoreType miniMarket = StoreType._('mini-market');
  static const StoreType pharmacy = StoreType._('pharmacy');
  static const StoreType clothing = StoreType._('clothing');
  static const StoreType electronics = StoreType._('electronics');
  static const StoreType cafe = StoreType._('cafe');
  static const StoreType restaurant = StoreType._('restaurant');
  static const StoreType fruitVegetable = StoreType._('fruit-vegetable');
  static const StoreType other = StoreType._('other');

  /// All supported store types, in a deterministic order.
  static const List<StoreType> values = <StoreType>[
    grocery,
    miniMarket,
    pharmacy,
    clothing,
    electronics,
    cafe,
    restaurant,
    fruitVegetable,
    other,
  ];

  /// Parses [input] into a supported [StoreType].
  ///
  /// The input is trimmed and lowercased before matching. Throws
  /// [ArgumentError] for any unsupported value.
  static StoreType parse(String input) {
    final normalized = input.trim().toLowerCase();
    for (final type in values) {
      if (type.value == normalized) {
        return type;
      }
    }
    throw ArgumentError.value(input, 'input', 'Unsupported StoreType');
  }

  /// Alias for [parse], emphasising that [value] is the machine value.
  static StoreType fromMachineValue(String value) => parse(value);

  bool get isOther => this == other;

  @override
  bool operator ==(Object other) => other is StoreType && other.value == value;

  @override
  int get hashCode => value.hashCode;

  @override
  String toString() => 'StoreType($value)';
}
