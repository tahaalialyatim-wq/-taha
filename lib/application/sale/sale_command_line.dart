import '../../domain/catalog/product_id.dart';
import '../../domain/catalog/quantity.dart';
import '../../domain/money/money.dart';

/// One requested line on a [CompleteSaleCommand].
class SaleCommandLine {
  SaleCommandLine({
    required this.productId,
    required Quantity quantity,
    this.unitSellingPrice,
  }) : quantity = _requirePositive(quantity);

  final ProductId productId;
  final Quantity quantity;
  final Money? unitSellingPrice;

  static Quantity _requirePositive(Quantity quantity) {
    if (quantity.milliUnits <= 0) {
      throw ArgumentError.value(
        quantity.milliUnits,
        'quantity',
        'Sale command line quantity must be greater than zero',
      );
    }
    return quantity;
  }
}
