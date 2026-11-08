import '../../domain/inventory/merchant_inventory_item.dart';
import '../../domain/money/money.dart';
import '../../domain/sale/sale.dart';
import '../../domain/sale/sale_line.dart';
import '../inventory/inventory_decrement.dart';
import '../inventory/inventory_exceptions.dart';
import '../inventory/merchant_inventory_repository.dart';
import '../inventory/merchant_inventory_service.dart';
import '../runtime/retail_store.dart';
import 'complete_sale_command.dart';
import 'complete_sale_unit_of_work.dart';
import 'in_memory_complete_sale_unit_of_work.dart';

/// Completes a merchant sale after validating all lines, then commits stock
/// deduction and sale persistence through [CompleteSaleUnitOfWork].
class CompleteSaleService {
  CompleteSaleService({
    required this.inventory,
    required this.unitOfWork,
  }) {
    final committed = unitOfWork;
    if (committed is InMemoryCompleteSaleUnitOfWork &&
        !identical(inventory, committed.store.inventory)) {
      throw ArgumentError.value(
        inventory,
        'inventory',
        'Must be the same RetailStore.inventory used by '
            'InMemoryCompleteSaleUnitOfWork',
      );
    }
  }

  /// Production in-memory cash-sale path: one [RetailStore] for reads and
  /// commit.
  factory CompleteSaleService.forStore(RetailStore store) {
    return CompleteSaleService(
      inventory: store.inventory,
      unitOfWork: InMemoryCompleteSaleUnitOfWork(store),
    );
  }

  final MerchantInventoryRepository inventory;
  final CompleteSaleUnitOfWork unitOfWork;

  Future<Sale> complete(CompleteSaleCommand command) async {
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
          unitPurchaseCost: item.purchasePrice,
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
    );

    return unitOfWork.executeCompleteSale(
      command.merchantId,
      sale,
      List<InventoryDecrement>.unmodifiable(decrements),
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
