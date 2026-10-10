import '../../domain/catalog/product_id.dart';
import '../../domain/catalog/quantity.dart';
import '../../domain/inventory/inventory_item_id.dart';
import '../../domain/merchant/merchant_id.dart';

/// Thrown when a mutation is attempted through the wrong merchant scope.
class MerchantMismatchException implements Exception {
  const MerchantMismatchException(
      {required this.expected, required this.actual});

  /// The merchant scope the caller used.
  final MerchantId expected;

  /// The merchant that actually owns the item.
  final MerchantId actual;

  @override
  String toString() => 'MerchantMismatchException(expected: ${expected.value}, '
      'actual: ${actual.value})';
}

/// Thrown when a mutation targets an inventory item that does not exist.
class InventoryItemNotFoundException implements Exception {
  const InventoryItemNotFoundException(
      {required this.merchantId, required this.itemId});

  final MerchantId merchantId;
  final InventoryItemId itemId;

  @override
  String toString() =>
      'InventoryItemNotFoundException(merchant: ${merchantId.value}, '
      'item: ${itemId.value})';
}

/// Thrown when a merchant already owns an item for the same product.
class DuplicateInventoryItemException implements Exception {
  const DuplicateInventoryItemException({
    required this.merchantId,
    required this.productId,
  });

  final MerchantId merchantId;
  final ProductId productId;

  @override
  String toString() =>
      'DuplicateInventoryItemException(merchant: ${merchantId.value}, '
      'product: ${productId.value})';
}

/// Thrown when a decrement requests more quantity than is available.
class InsufficientStockException implements Exception {
  const InsufficientStockException({
    required this.merchantId,
    required this.itemId,
    required this.available,
    required this.requested,
  });

  final MerchantId merchantId;
  final InventoryItemId itemId;
  final Quantity available;
  final Quantity requested;

  @override
  String toString() =>
      'InsufficientStockException(merchant: ${merchantId.value}, '
      'item: ${itemId.value}, available: ${available.milliUnits}, '
      'requested: ${requested.milliUnits})';
}
