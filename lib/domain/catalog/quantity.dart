import 'product_unit.dart';

/// A quantity expressed in integer milli-units.
///
/// The scale is [scale] (1000), so `1.5 kg` is `1500` milli-units and
/// `0.75 L` is `750` milli-units. Doubles are never used. Units that
/// [ProductUnit.requiresWhole] must use whole quantities.
class Quantity {
  const Quantity._(this.milliUnits);

  /// Number of milli-units in one whole unit.
  static const int scale = 1000;

  /// The amount in milli-units.
  final int milliUnits;

  static const Quantity zero = Quantity._(0);

  /// Creates a quantity of [milliUnits] milli-units.
  ///
  /// Throws [ArgumentError] when [milliUnits] is negative. Validation is
  /// enforced at runtime, not only via assert.
  factory Quantity.fromMilliUnits(int milliUnits) {
    if (milliUnits < 0) {
      throw ArgumentError.value(
        milliUnits,
        'milliUnits',
        'Quantity must not be negative',
      );
    }
    return Quantity._(milliUnits);
  }

  /// Creates a whole quantity of [units].
  factory Quantity.whole(int units) {
    if (units < 0) {
      throw ArgumentError.value(
          units, 'units', 'Quantity must not be negative');
    }
    return Quantity._(units * scale);
  }

  /// Creates a quantity of [milliUnits] milli-units that is valid for [unit].
  factory Quantity.of(ProductUnit unit, int milliUnits) {
    if (milliUnits < 0) {
      throw ArgumentError.value(
        milliUnits,
        'milliUnits',
        'Quantity must not be negative',
      );
    }
    if (unit.requiresWhole && milliUnits % scale != 0) {
      throw ArgumentError.value(
        milliUnits,
        'milliUnits',
        '${unit.value} requires whole quantities',
      );
    }
    return Quantity._(milliUnits);
  }

  bool get isWhole => milliUnits % scale == 0;

  int get wholeUnits => milliUnits ~/ scale;

  @override
  bool operator ==(Object other) =>
      other is Quantity && other.milliUnits == milliUnits;

  @override
  int get hashCode => milliUnits.hashCode;

  @override
  String toString() => 'Quantity($milliUnits mU)';
}
