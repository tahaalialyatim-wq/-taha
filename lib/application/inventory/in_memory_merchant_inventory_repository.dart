import '../../domain/catalog/product_id.dart';
import '../../domain/catalog/quantity.dart';
import '../../domain/inventory/inventory_item_id.dart';
import '../../domain/inventory/merchant_inventory_item.dart';
import '../../domain/merchant/merchant_id.dart';
import 'inventory_exceptions.dart';
import 'merchant_inventory_repository.dart';

/// In-memory [MerchantInventoryRepository].
///
/// There is no persistence. [updateQuantity] is atomic at the repository
/// boundary because replace is a single synchronous map assignment.
class InMemoryMerchantInventoryRepository
    implements MerchantInventoryRepository {
  final Map<String, MerchantInventoryItem> _byId =
      <String, MerchantInventoryItem>{};

  @override
  Future<MerchantInventoryItem?> getById(
    MerchantId merchantId,
    InventoryItemId id,
  ) async {
    final item = _byId[id.value];
    if (item == null || item.merchantId != merchantId) {
      return null;
    }
    return item;
  }

  @override
  Future<MerchantInventoryItem?> getByProduct(
    MerchantId merchantId,
    ProductId productId,
  ) async {
    for (final item in _byId.values) {
      if (item.merchantId == merchantId && item.productId == productId) {
        return item;
      }
    }
    return null;
  }

  @override
  Future<bool> exists(MerchantId merchantId, InventoryItemId id) async {
    final item = _byId[id.value];
    return item != null && item.merchantId == merchantId;
  }

  @override
  Future<List<MerchantInventoryItem>> getAll(MerchantId merchantId) async {
    final items = _byId.values
        .where((item) => item.merchantId == merchantId)
        .toList(growable: false);
    return List<MerchantInventoryItem>.unmodifiable(items);
  }

  @override
  Future<MerchantInventoryItem> add(MerchantInventoryItem item) async {
    if (_byId.containsKey(item.id.value)) {
      throw DuplicateInventoryItemException(
        merchantId: item.merchantId,
        productId: item.productId,
      );
    }
    if (_hasProduct(item.merchantId, item.productId)) {
      throw DuplicateInventoryItemException(
        merchantId: item.merchantId,
        productId: item.productId,
      );
    }
    _byId[item.id.value] = item;
    return item;
  }

  @override
  Future<MerchantInventoryItem> update(MerchantInventoryItem item) async {
    final existing = _byId[item.id.value];
    if (existing == null) {
      throw InventoryItemNotFoundException(
        merchantId: item.merchantId,
        itemId: item.id,
      );
    }
    if (existing.merchantId != item.merchantId) {
      throw MerchantMismatchException(
        expected: item.merchantId,
        actual: existing.merchantId,
      );
    }
    if (_hasProduct(item.merchantId, item.productId, ignoring: item.id)) {
      throw DuplicateInventoryItemException(
        merchantId: item.merchantId,
        productId: item.productId,
      );
    }
    _byId[item.id.value] = item;
    return item;
  }

  @override
  Future<MerchantInventoryItem> updateQuantity(
    MerchantId merchantId,
    InventoryItemId id,
    Quantity quantity,
  ) async {
    final existing = _byId[id.value];
    if (existing == null) {
      throw InventoryItemNotFoundException(merchantId: merchantId, itemId: id);
    }
    if (existing.merchantId != merchantId) {
      throw MerchantMismatchException(
        expected: merchantId,
        actual: existing.merchantId,
      );
    }
    final updated = existing.copyWith(quantity: quantity);
    _byId[id.value] = updated;
    return updated;
  }

  @override
  Future<bool> remove(MerchantId merchantId, InventoryItemId id) async {
    final existing = _byId[id.value];
    if (existing == null) {
      return false;
    }
    if (existing.merchantId != merchantId) {
      throw MerchantMismatchException(
        expected: merchantId,
        actual: existing.merchantId,
      );
    }
    _byId.remove(id.value);
    return true;
  }

  bool _hasProduct(
    MerchantId merchantId,
    ProductId productId, {
    InventoryItemId? ignoring,
  }) {
    for (final item in _byId.values) {
      if (item.merchantId != merchantId || item.productId != productId) {
        continue;
      }
      if (ignoring != null && item.id == ignoring) {
        continue;
      }
      return true;
    }
    return false;
  }
}
