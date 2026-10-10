import '../../domain/customer/customer_account_entry.dart';
import '../../domain/merchant/merchant_id.dart';
import '../../domain/sale/sale.dart';
import '../inventory/inventory_decrement.dart';

/// One all-or-nothing retail write set for [RetailStore.commit].
///
/// Cash sales omit [ledgerEntry]. Inventory decrements and [sale] are always
/// required. There is no compensating rollback: the store either publishes a
/// complete next snapshot or leaves live state unchanged.
class RetailWrites {
  RetailWrites({
    required this.merchantId,
    required this.sale,
    required List<InventoryDecrement> decrements,
    this.ledgerEntry,
  }) : decrements = List<InventoryDecrement>.unmodifiable(
          List<InventoryDecrement>.from(decrements),
        );

  final MerchantId merchantId;
  final Sale sale;
  final List<InventoryDecrement> decrements;
  final CustomerAccountEntry? ledgerEntry;
}
