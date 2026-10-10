import '../../domain/catalog/quantity.dart';
import '../../domain/inventory/inventory_item_id.dart';

/// One merchant-scoped inventory decrement in a batch.
class InventoryDecrement {
  const InventoryDecrement({
    required this.inventoryItemId,
    required this.amount,
  });

  final InventoryItemId inventoryItemId;
  final Quantity amount;
}
