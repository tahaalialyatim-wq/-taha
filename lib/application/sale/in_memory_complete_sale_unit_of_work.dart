import '../../domain/merchant/merchant_id.dart';
import '../../domain/sale/sale.dart';
import '../inventory/inventory_decrement.dart';
import '../runtime/retail_store.dart';
import '../runtime/retail_writes.dart';
import 'complete_sale_unit_of_work.dart';

/// In-memory [CompleteSaleUnitOfWork].
///
/// Cash sale is one [RetailStore.commit]: inventory decrements and [Sale]
/// persist together, with no ledger entry. The store plans the next snapshot
/// without mutating live state, then publishes it with one assignment.
class InMemoryCompleteSaleUnitOfWork implements CompleteSaleUnitOfWork {
  InMemoryCompleteSaleUnitOfWork(this.store);

  final RetailStore store;

  @override
  Future<Sale> executeCompleteSale(
    MerchantId merchantId,
    Sale sale,
    List<InventoryDecrement> decrements,
  ) async {
    store.commit(
      RetailWrites(
        merchantId: merchantId,
        sale: sale,
        decrements: decrements,
      ),
    );
    return sale;
  }
}
