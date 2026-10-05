import '../../domain/catalog/product_id.dart';
import '../../domain/catalog/quantity.dart';
import '../../domain/inventory/inventory_item_id.dart';
import '../../domain/inventory/merchant_inventory_item.dart';
import '../../domain/merchant/merchant_id.dart';
import '../../domain/money/money.dart';
import 'inventory_exceptions.dart';
import 'merchant_inventory_repository.dart';

/// Asynchronous, product-scoped merchant inventory service.
///
/// The public business API addresses items by [ProductId] within a
/// [MerchantId] scope. Inventory identities are derived deterministically from
/// the merchant and product so no separate id factory is required.
class MerchantInventoryService {
  MerchantInventoryService(this.repository);

  final MerchantInventoryRepository repository;

  /// Deterministic inventory identity for [merchantId] + [productId].
  static InventoryItemId idFor(MerchantId merchantId, ProductId productId) =>
      InventoryItemId('${merchantId.value}:${productId.value}');

  /// Returns an unmodifiable snapshot of all items for [merchantId].
  Future<List<MerchantInventoryItem>> getAll(MerchantId merchantId) {
    return repository.getAll(merchantId);
  }

  /// Returns the item for [productId], or `null`.
  Future<MerchantInventoryItem?> findByProduct(
    MerchantId merchantId,
    ProductId productId,
  ) {
    return repository.getByProduct(merchantId, productId);
  }

  /// Adds merchant-owned inventory for [productId].
  ///
  /// Throws [DuplicateInventoryItemException] when the merchant already owns an
  /// item for the product.
  Future<MerchantInventoryItem> addProduct(
    MerchantId merchantId,
    ProductId productId, {
    Quantity quantity = Quantity.zero,
    Money? sellingPrice,
    Money? purchasePrice,
    Quantity? minimumStock,
  }) async {
    final existing = await repository.getByProduct(merchantId, productId);
    if (existing != null) {
      throw DuplicateInventoryItemException(
        merchantId: merchantId,
        productId: productId,
      );
    }
    final item = MerchantInventoryItem(
      id: idFor(merchantId, productId),
      merchantId: merchantId,
      productId: productId,
      quantity: quantity,
      sellingPrice: sellingPrice,
      purchasePrice: purchasePrice,
      minimumStock: minimumStock,
    );
    return repository.add(item);
  }

  /// Sets the quantity of the item for [productId].
  ///
  /// Throws [InventoryItemNotFoundException] when the merchant does not own the
  /// product.
  Future<MerchantInventoryItem> setQuantity(
    MerchantId merchantId,
    ProductId productId,
    Quantity quantity,
  ) async {
    final item = await _requireItem(merchantId, productId);
    return repository.updateQuantity(merchantId, item.id, quantity);
  }

  /// Removes the item for [productId]. Returns `false` when absent.
  Future<bool> removeProduct(MerchantId merchantId, ProductId productId) async {
    final item = await repository.getByProduct(merchantId, productId);
    if (item == null) {
      return false;
    }
    return repository.remove(merchantId, item.id);
  }

  Future<MerchantInventoryItem> _requireItem(
    MerchantId merchantId,
    ProductId productId,
  ) async {
    final item = await repository.getByProduct(merchantId, productId);
    if (item == null) {
      throw InventoryItemNotFoundException(
        merchantId: merchantId,
        itemId: idFor(merchantId, productId),
      );
    }
    return item;
  }
}
