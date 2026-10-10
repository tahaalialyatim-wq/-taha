import '../../domain/customer/customer.dart';
import '../../domain/customer/customer_account_entry.dart';
import '../../domain/inventory/merchant_inventory_item.dart';
import '../../domain/sale/sale.dart';

/// Immutable in-memory snapshot of merchant retail aggregates.
///
/// [InMemoryRetailStore] publishes a replacement [RetailState] through one
/// reference assignment. Callers must not mutate the maps or order lists.
class RetailState {
  RetailState({
    Map<String, MerchantInventoryItem> inventoryById =
        const <String, MerchantInventoryItem>{},
    Map<String, Sale> salesByKey = const <String, Sale>{},
    List<String> saleOrder = const <String>[],
    Map<String, Customer> customersByKey = const <String, Customer>{},
    List<String> customerOrder = const <String>[],
    Map<String, CustomerAccountEntry> ledgerByKey =
        const <String, CustomerAccountEntry>{},
    List<String> ledgerOrder = const <String>[],
  })  : inventoryById =
            Map<String, MerchantInventoryItem>.unmodifiable(inventoryById),
        salesByKey = Map<String, Sale>.unmodifiable(salesByKey),
        saleOrder = List<String>.unmodifiable(saleOrder),
        customersByKey = Map<String, Customer>.unmodifiable(customersByKey),
        customerOrder = List<String>.unmodifiable(customerOrder),
        ledgerByKey =
            Map<String, CustomerAccountEntry>.unmodifiable(ledgerByKey),
        ledgerOrder = List<String>.unmodifiable(ledgerOrder);

  final Map<String, MerchantInventoryItem> inventoryById;
  final Map<String, Sale> salesByKey;
  final List<String> saleOrder;
  final Map<String, Customer> customersByKey;
  final List<String> customerOrder;
  final Map<String, CustomerAccountEntry> ledgerByKey;
  final List<String> ledgerOrder;
}
