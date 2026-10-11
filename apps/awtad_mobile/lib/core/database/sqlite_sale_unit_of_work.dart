import 'package:awtad_retail/awtad_retail.dart';

import 'database_service.dart';
import 'sqlite_customer_repository.dart';
import 'sqlite_inventory_repository.dart';
import 'sqlite_ledger_repository.dart';
import 'sqlite_sale_repository.dart';

class SqliteCompleteSaleUnitOfWork implements CompleteSaleUnitOfWork {
  SqliteCompleteSaleUnitOfWork(this.database);

  final DatabaseService database;

  @override
  Future<Sale> executeCompleteSale(
    MerchantId merchantId,
    Sale sale,
    List<InventoryDecrement> decrements,
  ) {
    return commitSqliteSale(
      database: database,
      merchantId: merchantId,
      sale: sale,
      decrements: decrements,
    );
  }
}

class SqliteCreditSaleUnitOfWork implements CreditSaleUnitOfWork {
  SqliteCreditSaleUnitOfWork(this.database);

  final DatabaseService database;

  @override
  Future<Sale> executeCreditSale(
    MerchantId merchantId,
    Sale sale,
    List<InventoryDecrement> decrements,
    CustomerAccountEntry ledgerEntry,
  ) {
    return commitSqliteSale(
      database: database,
      merchantId: merchantId,
      sale: sale,
      decrements: decrements,
      ledgerEntry: ledgerEntry,
    );
  }
}

Future<Sale> commitSqliteSale({
  required DatabaseService database,
  required MerchantId merchantId,
  required Sale sale,
  required List<InventoryDecrement> decrements,
  CustomerAccountEntry? ledgerEntry,
}) async {
  final db = database.database;
  db.execute('BEGIN IMMEDIATE;');
  try {
    final inventory = SqliteInventoryRepository(database);
    final sales = SqliteSaleRepository(database);
    await inventory.decrementQuantities(merchantId, decrements);
    await sales.add(sale);
    if (ledgerEntry != null) {
      if (sale.customerId == null ||
          sale.customerId != ledgerEntry.customerId) {
        throw ArgumentError.value(
          sale.customerId,
          'sale.customerId',
          'Credit-sale ledger entry requires matching Sale.customerId',
        );
      }
      if (ledgerEntry.amount != sale.total) {
        throw ArgumentError.value(
          ledgerEntry.amount,
          'ledgerEntry.amount',
          'Ledger entry amount must equal sale total',
        );
      }
      final customers = SqliteCustomerRepository(database);
      final ledger = SqliteLedgerRepository(
        database,
        customers: customers,
      );
      await ledger.append(ledgerEntry);
    }
    db.execute('COMMIT;');
    return sale;
  } catch (_) {
    db.execute('ROLLBACK;');
    rethrow;
  }
}
