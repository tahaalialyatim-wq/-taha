import '../catalog/product_id.dart';
import '../catalog/quantity.dart';
import '../merchant/merchant_id.dart';
import '../money/money.dart';
import 'inventory_item_id.dart';

/// A merchant owned inventory record for a catalog [ProductId].
///
/// Identity is [InventoryItemId]. Merchant ownership is [MerchantId]. The
/// product relationship is [ProductId]. [quantity] may be zero. Selling,
/// purchase and minimum-stock values may be absent.
class MerchantInventoryItem {
  const MerchantInventoryItem({
    required this.id,
    required this.merchantId,
    required this.productId,
    required this.quantity,
    this.sellingPrice,
    this.purchasePrice,
    this.minimumStock,
  });

  final InventoryItemId id;
  final MerchantId merchantId;
  final ProductId productId;
  final Quantity quantity;
  final Money? sellingPrice;
  final Money? purchasePrice;
  final Quantity? minimumStock;

  MerchantInventoryItem copyWith({
    Quantity? quantity,
    Money? sellingPrice,
    Money? purchasePrice,
    Quantity? minimumStock,
  }) {
    return MerchantInventoryItem(
      id: id,
      merchantId: merchantId,
      productId: productId,
      quantity: quantity ?? this.quantity,
      sellingPrice: sellingPrice ?? this.sellingPrice,
      purchasePrice: purchasePrice ?? this.purchasePrice,
      minimumStock: minimumStock ?? this.minimumStock,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is MerchantInventoryItem && other.id == id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'MerchantInventoryItem($id)';
}
