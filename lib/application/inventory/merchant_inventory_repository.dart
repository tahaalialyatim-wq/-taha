import '../../domain/catalog/product_id.dart';
import '../../domain/catalog/quantity.dart';
import '../../domain/inventory/inventory_item_id.dart';
import '../../domain/inventory/merchant_inventory_item.dart';
import '../../domain/merchant/merchant_id.dart';
import 'inventory_decrement.dart';

/// Merchant scoped, asynchronous inventory repository.
///
/// Reads for the wrong merchant return `null`/`false`. Mutations for the wrong
/// merchant throw [MerchantMismatchException]. Mutations for missing items
/// throw [InventoryItemNotFoundException]. [getAll] returns an unmodifiable
/// snapshot.
abstract class MerchantInventoryRepository {
  /// Returns the item with [id] owned by [merchantId], or `null`.
  Future<MerchantInventoryItem?> getById(
      MerchantId merchantId, InventoryItemId id);

  /// Returns the item for [productId] owned by [merchantId], or `null`.
  Future<MerchantInventoryItem?> getByProduct(
      MerchantId merchantId, ProductId productId);

  /// Whether [merchantId] owns an item with [id].
  Future<bool> exists(MerchantId merchantId, InventoryItemId id);

  /// Returns an unmodifiable snapshot of all items owned by [merchantId].
  Future<List<MerchantInventoryItem>> getAll(MerchantId merchantId);

  /// Adds [item]. Rejects duplicate [MerchantId] + [ProductId].
  Future<MerchantInventoryItem> add(MerchantInventoryItem item);

  /// Replaces [item]. Throws when missing or owned by another merchant.
  Future<MerchantInventoryItem> update(MerchantInventoryItem item);

  /// Atomically updates the quantity of an item.
  Future<MerchantInventoryItem> updateQuantity(
    MerchantId merchantId,
    InventoryItemId id,
    Quantity quantity,
  );

  /// Atomically decrements the quantity of an item by [amount].
  ///
  /// [amount] must be greater than zero. Throws
  /// [InventoryItemNotFoundException] when missing,
  /// [MerchantMismatchException] when owned by another merchant, and
  /// [InsufficientStockException] when [amount] exceeds available quantity.
  Future<void> decrementQuantity(
    MerchantId merchantId,
    InventoryItemId inventoryItemId,
    Quantity amount,
  );

  /// Atomically decrements quantities for every item in [decrements].
  ///
  /// Validates the complete batch before any write. Throws
  /// [InventoryItemNotFoundException], [MerchantMismatchException], or
  /// [InsufficientStockException] without mutating stock.
  Future<void> decrementQuantities(
    MerchantId merchantId,
    List<InventoryDecrement> decrements,
  );

  /// Removes an item. Returns `false` when it does not exist for [merchantId].
  Future<bool> remove(MerchantId merchantId, InventoryItemId id);
}
