import '../../domain/customer/customer_account_entry.dart';
import '../../domain/merchant/merchant_id.dart';
import '../../domain/sale/sale.dart';
import '../inventory/inventory_decrement.dart';

/// Coordinates inventory decrement, sale persistence, and one ledger credit
/// as a single operation.
abstract class CreditSaleUnitOfWork {
  /// Commits [sale], [decrements], and [ledgerEntry] for [merchantId] as one
  /// operation.
  ///
  /// The in-memory implementation publishes all three through one
  /// [RetailStore.commit]. There is no sequential write.
  Future<Sale> executeCreditSale(
    MerchantId merchantId,
    Sale sale,
    List<InventoryDecrement> decrements,
    CustomerAccountEntry ledgerEntry,
  );
}
