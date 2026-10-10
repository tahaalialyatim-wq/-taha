import '../../domain/customer/customer_account_entry.dart';
import '../../domain/merchant/merchant_id.dart';
import '../../domain/sale/sale.dart';
import '../inventory/inventory_decrement.dart';
import '../runtime/retail_store.dart';
import '../runtime/retail_writes.dart';
import 'credit_sale_unit_of_work.dart';

/// In-memory [CreditSaleUnitOfWork].
///
/// Credit sale is one [RetailStore.commit]: inventory decrements, [Sale], and
/// one ledger credit persist together. The store plans the next snapshot
/// without mutating live state, then publishes it with one assignment.
class InMemoryCreditSaleUnitOfWork implements CreditSaleUnitOfWork {
  InMemoryCreditSaleUnitOfWork(this.store);

  final RetailStore store;

  @override
  Future<Sale> executeCreditSale(
    MerchantId merchantId,
    Sale sale,
    List<InventoryDecrement> decrements,
    CustomerAccountEntry ledgerEntry,
  ) async {
    store.commit(
      RetailWrites(
        merchantId: merchantId,
        sale: sale,
        decrements: decrements,
        ledgerEntry: ledgerEntry,
      ),
    );
    return sale;
  }
}
