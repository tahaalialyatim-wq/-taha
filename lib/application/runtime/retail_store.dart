import '../customer/customer_account_ledger_repository.dart';
import '../customer/customer_repository.dart';
import '../inventory/merchant_inventory_repository.dart';
import '../sale/sale_repository.dart';
import 'retail_writes.dart';

/// Owns one [RetailState] and the repository views that read it.
///
/// [commit] is synchronous: it validates every requested change, builds the
/// next snapshot without mutating live maps, then publishes it with one
/// state-reference assignment.
abstract class RetailStore {
  MerchantInventoryRepository get inventory;
  SaleRepository get sales;
  CustomerRepository get customers;
  CustomerAccountLedgerRepository get ledger;

  /// Validates [writes] and publishes the next snapshot, or throws with live
  /// state unchanged.
  void commit(RetailWrites writes);
}
