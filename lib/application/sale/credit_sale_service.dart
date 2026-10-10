import '../../domain/customer/customer_account_entry.dart';
import '../../domain/customer/customer_account_entry_type.dart';
import '../../domain/inventory/merchant_inventory_item.dart';
import '../../domain/money/money.dart';
import '../../domain/sale/sale.dart';
import '../../domain/sale/sale_line.dart';
import '../customer/customer_exceptions.dart';
import '../customer/customer_repository.dart';
import '../inventory/inventory_decrement.dart';
import '../inventory/inventory_exceptions.dart';
import '../inventory/merchant_inventory_repository.dart';
import '../inventory/merchant_inventory_service.dart';
import '../runtime/retail_store.dart';
import 'credit_sale_command.dart';
import 'credit_sale_unit_of_work.dart';
import 'in_memory_credit_sale_unit_of_work.dart';

/// Completes a merchant credit sale after validating lines and customer
/// ownership, then commits stock deduction, sale persistence, and one ledger
/// credit through [CreditSaleUnitOfWork].
class CreditSaleService {
  CreditSaleService({
    required this.inventory,
    required this.unitOfWork,
    required this.customers,
  }) {
    final committed = unitOfWork;
    if (committed is InMemoryCreditSaleUnitOfWork) {
      if (!identical(inventory, committed.store.inventory)) {
        throw ArgumentError.value(
          inventory,
          'inventory',
          'Must be the same RetailStore.inventory used by '
              'InMemoryCreditSaleUnitOfWork',
        );
      }
      if (!identical(customers, committed.store.customers)) {
        throw ArgumentError.value(
          customers,
          'customers',
          'Must be the same RetailStore.customers used by '
              'InMemoryCreditSaleUnitOfWork',
        );
      }
    }
  }

  /// Production in-memory credit-sale path: one [RetailStore] for reads and
  /// commit.
  factory CreditSaleService.forStore(RetailStore store) {
    return CreditSaleService(
      inventory: store.inventory,
      customers: store.customers,
      unitOfWork: InMemoryCreditSaleUnitOfWork(store),
    );
  }

  final MerchantInventoryRepository inventory;
  final CreditSaleUnitOfWork unitOfWork;
  final CustomerRepository customers;

  Future<Sale> complete(CreditSaleCommand command) async {
    if (!await customers.exists(command.merchantId, command.customerId)) {
      throw CustomerNotFoundException(
        merchantId: command.merchantId,
        customerId: command.customerId,
      );
    }

    final saleLines = <SaleLine>[];
    final decrements = <InventoryDecrement>[];

    for (final line in command.lines) {
      final item = await inventory.getByProduct(
        command.merchantId,
        line.productId,
      );
      if (item == null) {
        throw InventoryItemNotFoundException(
          merchantId: command.merchantId,
          itemId: MerchantInventoryService.idFor(
            command.merchantId,
            line.productId,
          ),
        );
      }

      final resolved = _resolvePrice(item, line.unitSellingPrice);
      if (resolved.currency != command.currency) {
        throw ArgumentError.value(
          resolved.currency,
          'currency',
          'Resolved selling price currency must equal sale currency',
        );
      }
      if (item.quantity.milliUnits < line.quantity.milliUnits) {
        throw InsufficientStockException(
          merchantId: command.merchantId,
          itemId: item.id,
          available: item.quantity,
          requested: line.quantity,
        );
      }

      saleLines.add(
        SaleLine(
          productId: line.productId,
          quantity: line.quantity,
          unitSellingPrice: resolved,
        ),
      );
      decrements.add(
        InventoryDecrement(
          inventoryItemId: item.id,
          amount: line.quantity,
        ),
      );
    }

    final sale = Sale(
      id: command.saleId,
      merchantId: command.merchantId,
      currency: command.currency,
      lines: saleLines,
      customerId: command.customerId,
    );

    final total = sale.total;
    if (total.minorUnits <= 0) {
      throw ArgumentError.value(
        total.minorUnits,
        'total',
        'Credit sale total must be greater than zero',
      );
    }

    final ledgerEntry = CustomerAccountEntry(
      id: command.ledgerEntryId,
      merchantId: command.merchantId,
      customerId: command.customerId,
      currency: command.currency,
      amount: total,
      type: CustomerAccountEntryType.credit,
      occurredAt: command.occurredAt,
      reference: command.saleId.value,
    );

    return unitOfWork.executeCreditSale(
      command.merchantId,
      sale,
      List<InventoryDecrement>.unmodifiable(decrements),
      ledgerEntry,
    );
  }

  Money _resolvePrice(MerchantInventoryItem item, Money? commandPrice) {
    final resolved = item.sellingPrice ?? commandPrice;
    if (resolved == null) {
      throw ArgumentError.value(
        item.productId.value,
        'unitSellingPrice',
        'Selling price is required when inventory has no sellingPrice',
      );
    }
    return resolved;
  }
}
