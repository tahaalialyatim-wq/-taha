import '../catalog/product_id.dart';
import '../catalog/quantity.dart';
import '../money/money.dart';

/// One product line on a completed [Sale].
///
/// [lineTotal] is derived from [unitSellingPrice] and [quantity] using integer
/// arithmetic only:
/// `(unitSellingPrice.minorUnits * quantity.milliUnits) ~/ Quantity.scale`.
class SaleLine {
  SaleLine({
    required this.productId,
    required Quantity quantity,
    required this.unitSellingPrice,
  })  : quantity = _requirePositive(quantity),
        lineTotal = Money(
          currency: unitSellingPrice.currency,
          minorUnits: (unitSellingPrice.minorUnits * quantity.milliUnits) ~/
              Quantity.scale,
        );

  final ProductId productId;
  final Quantity quantity;
  final Money unitSellingPrice;
  final Money lineTotal;

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
