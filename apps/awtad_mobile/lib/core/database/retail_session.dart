import 'package:awtad_retail/awtad_retail.dart';
import 'package:path_provider/path_provider.dart';

import 'database_service.dart';
import 'sqlite_customer_repository.dart';
import 'sqlite_inventory_repository.dart';
import 'sqlite_ledger_repository.dart';
import 'sqlite_sale_repository.dart';
import 'sqlite_sale_unit_of_work.dart';

class RetailSession {
  RetailSession(this.database)
      : inventory = SqliteInventoryRepository(database),
        sales = SqliteSaleRepository(database),
        customers = SqliteCustomerRepository(database) {
    ledger = SqliteLedgerRepository(database, customers: customers);
    inventoryService = MerchantInventoryService(inventory);
    cashSales = CompleteSaleService(
      inventory: inventory,
      unitOfWork: SqliteCompleteSaleUnitOfWork(database),
    );
    creditSales = CreditSaleService(
      inventory: inventory,
      customers: customers,
      unitOfWork: SqliteCreditSaleUnitOfWork(database),
    );
    openingBalances = RecordOpeningBalanceService(ledger: ledger);
    payments = RecordCustomerPaymentService(ledger: ledger);
  }

  final DatabaseService database;
  final MerchantInventoryRepository inventory;
  final SaleRepository sales;
  final CustomerRepository customers;
  late final CustomerAccountLedgerRepository ledger;
  late final MerchantInventoryService inventoryService;
  late final CompleteSaleService cashSales;
  late final CreditSaleService creditSales;
  late final RecordOpeningBalanceService openingBalances;
  late final RecordCustomerPaymentService payments;

  static final MerchantId defaultMerchant = MerchantId('merchant-1');

  static Future<RetailSession> openDocuments() async {
    final dir = await getApplicationDocumentsDirectory();
    final database = DatabaseService(
      databasePath: DatabaseService.pathIn(dir.path),
    );
    await database.initialize();
    return RetailSession(database);
  }

  void close() => database.close();
}
