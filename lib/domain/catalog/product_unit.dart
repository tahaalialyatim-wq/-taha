/// Strongly typed unit of measure for a [Product].
///
/// Supported machine values are [piece], [box], [carton], [kg], [g], [litre],
/// [millilitre], [metre] and [other]. The [other] unit may carry an optional
/// [customLabel]. There is no localization and no complex conversion.
class ProductUnit {
  const ProductUnit._(this.value, [this.customLabel]);

  /// Stable machine value.
  final String value;

  /// Optional label, only meaningful for [other].
  final String? customLabel;

  static const ProductUnit piece = ProductUnit._('piece');
  static const ProductUnit box = ProductUnit._('box');
  static const ProductUnit carton = ProductUnit._('carton');
  static const ProductUnit kg = ProductUnit._('kg');
  static const ProductUnit g = ProductUnit._('g');
  static const ProductUnit litre = ProductUnit._('L');
  static const ProductUnit millilitre = ProductUnit._('mL');
  static const ProductUnit metre = ProductUnit._('m');
  static const ProductUnit other = ProductUnit._('other');

  /// All supported built-in units, in deterministic order.
  static const List<ProductUnit> values = <ProductUnit>[
    piece,
    box,
    carton,
    kg,
    g,
    litre,
    millilitre,
    metre,
    other,
  ];

  /// Creates the [other] unit with an optional [customLabel].
  factory ProductUnit.custom(String? customLabel) {
    if (customLabel != null && customLabel.trim().isEmpty) {
      throw ArgumentError.value(
        customLabel,
        'customLabel',
        'Custom label must not be blank',
      );
    }
    return ProductUnit._('other', customLabel?.trim());
  }

  /// Parses [input] into a supported built-in [ProductUnit].
  ///
  /// The input is trimmed before matching. Throws [ArgumentError] for an
  /// unsupported value.
  static ProductUnit parse(String input) {
    final normalized = input.trim();
    for (final unit in values) {
      if (unit.value == normalized) {
        return unit;
      }
    }
    throw ArgumentError.value(input, 'input', 'Unsupported ProductUnit');
  }

  /// Whether quantities of this unit may be fractional.
  bool get allowsFractional => this != piece && this != box && this != carton;

  /// Whether quantities of this unit must be whole numbers.
  bool get requiresWhole => !allowsFractional;

  @override
  bool operator ==(Object other) =>
      other is ProductUnit &&
      other.value == value &&
      other.customLabel == customLabel;

  @override
  int get hashCode => Object.hash(value, customLabel);

  @override
  String toString() => customLabel == null
      ? 'ProductUnit($value)'
      : 'ProductUnit($value:$customLabel)';
}
