import '../../domain/merchant/merchant_id.dart';
import '../../domain/sale/sale.dart';
import '../inventory/inventory_decrement.dart';

/// Coordinates inventory decrement and sale persistence as one operation.
abstract class CompleteSaleUnitOfWork {
  /// Commits [sale] and [decrements] for [merchantId] as one operation.
  ///
  /// The in-memory implementation publishes both through one
  /// [RetailStore.commit]. There is no sequential inventory-then-sale write.
  Future<Sale> executeCompleteSale(
    MerchantId merchantId,
    Sale sale,
    List<InventoryDecrement> decrements,
  );
}
