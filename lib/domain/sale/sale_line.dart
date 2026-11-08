import '../catalog/product_id.dart';
import '../catalog/quantity.dart';
import '../money/money.dart';

/// One product line on a completed [Sale].
///
/// [lineTotal] is derived from [unitSellingPrice] and [quantity] using integer
/// arithmetic only:
/// `(unitSellingPrice.minorUnits * quantity.milliUnits) ~/ Quantity.scale`.
///
/// [unitPurchaseCost] is an optional historical snapshot of the merchant's
/// purchase cost at sale time. It is stored without conversion. When it is
/// absent, or when its currency differs from [unitSellingPrice], the line's
/// cost and gross profit are unknown rather than zero.
class SaleLine {
  SaleLine({
    required this.productId,
    required Quantity quantity,
    required this.unitSellingPrice,
    this.unitPurchaseCost,
  })  : quantity = _requirePositive(quantity),
        lineTotal = Money(
          currency: unitSellingPrice.currency,
          minorUnits: (unitSellingPrice.minorUnits * quantity.milliUnits) ~/
              Quantity.scale,
        );

  final ProductId productId;
  final Quantity quantity;
  final Money unitSellingPrice;

  /// Historical purchase cost per unit at sale time, or `null` when unknown.
  final Money? unitPurchaseCost;

  final Money lineTotal;

  /// Integer purchase-cost total for this line.
  ///
  /// Returns `null` when the cost is missing or its currency differs from the
  /// selling price. No conversion is ever performed.
  Money? get lineCost {
    final cost = unitPurchaseCost;
    if (cost == null || cost.currency != unitSellingPrice.currency) {
      return null;
    }
    return Money(
      currency: cost.currency,
      minorUnits: (cost.minorUnits * quantity.milliUnits) ~/ Quantity.scale,
    );
  }

  /// Gross profit for this line: selling total minus purchase-cost total.
  ///
  /// Returns `null` when [lineCost] is unavailable (unknown or foreign-cost
  /// currency). Negative values represent a loss.
  Money? get grossProfit {
    final cost = lineCost;
    if (cost == null) {
      return null;
    }
    return Money(
      currency: lineTotal.currency,
      minorUnits: lineTotal.minorUnits - cost.minorUnits,
    );
  }

  static Quantity _requirePositive(Quantity quantity) {
    if (quantity.milliUnits <= 0) {
      throw ArgumentError.value(
        quantity.milliUnits,
        'quantity',
        'SaleLine quantity must be greater than zero',
      );
    }
    return quantity;
  }
}

/// Gross-profit margin for one currency, expressed as integer tenths of a
/// percent.
///
/// The margin is `gross profit / sales revenue * 100`. Internal arithmetic uses
/// [BigInt] and integer division only; no `double` is involved. A margin is
/// unavailable when revenue is not positive, because the percentage would not
/// be meaningful.
class GrossProfitMargin {
  const GrossProfitMargin._(this._tenthsOfPercent);

  final int? _tenthsOfPercent;

  /// A margin that cannot be meaningfully computed.
  static const GrossProfitMargin unavailable = GrossProfitMargin._(null);

  /// Computes the margin from integer minor-unit totals of one currency.
  ///
  /// Returns [unavailable] when [revenueMinorUnits] is zero or negative.
  /// Rounds to the nearest tenth of a percent, away from zero.
  factory GrossProfitMargin.fromMinorUnits({
    required int revenueMinorUnits,
    required int grossProfitMinorUnits,
  }) {
    if (revenueMinorUnits <= 0) {
      return unavailable;
    }
    final numerator = BigInt.from(grossProfitMinorUnits) * BigInt.from(1000);
    final denominator = BigInt.from(revenueMinorUnits);
    return GrossProfitMargin._(_roundedQuotient(numerator, denominator));
  }

  bool get isAvailable => _tenthsOfPercent != null;

  /// Signed tenths of a percent, or `null` when unavailable.
  int? get tenthsOfPercent => _tenthsOfPercent;

  /// Display text such as `33.3%`, `-5.0%` or an em dash when unavailable.
  String get label {
    final tenths = _tenthsOfPercent;
    if (tenths == null) {
      return '—';
    }
    final sign = tenths < 0 ? '-' : '';
    final magnitude = tenths.abs();
    return '$sign${magnitude ~/ 10}.${magnitude % 10}%';
  }

  static int _roundedQuotient(BigInt numerator, BigInt denominator) {
    final negative = numerator.isNegative != denominator.isNegative;
    final a = numerator.abs();
    final b = denominator.abs();
    final rounded = (a * BigInt.two + b) ~/ (b * BigInt.two);
    return negative ? -rounded.toInt() : rounded.toInt();
  }

  @override
  bool operator ==(Object other) =>
      other is GrossProfitMargin && other._tenthsOfPercent == _tenthsOfPercent;

  @override
  int get hashCode => _tenthsOfPercent.hashCode;

  @override
  String toString() => 'GrossProfitMargin($label)';
}
