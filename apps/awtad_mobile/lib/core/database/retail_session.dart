import 'package:awtad_retail/awtad_retail.dart';
import 'package:path_provider/path_provider.dart';

import 'database_service.dart';
import 'sqlite_customer_repository.dart';
import 'sqlite_inventory_repository.dart';
import 'sqlite_ledger_repository.dart';
import 'sqlite_sale_repository.dart';
import 'sqlite_sale_unit_of_work.dart';
import 'sqlite_store_settings_repository.dart';

class RetailSession {
  RetailSession(
    this.database, {
    MerchantInventoryRepository? inventory,
    SaleRepository? sales,
    CustomerRepository? customers,
    StoreSettingsRepository? settings,
  })  : inventory = inventory ?? SqliteInventoryRepository(database),
        sales = sales ?? SqliteSaleRepository(database),
        customers = customers ?? SqliteCustomerRepository(database),
        settings = settings ?? SqliteStoreSettingsRepository(database) {
    ledger = SqliteLedgerRepository(database, customers: this.customers);
    inventoryService = MerchantInventoryService(this.inventory);
    cashSales = CompleteSaleService(
      inventory: this.inventory,
      unitOfWork: SqliteCompleteSaleUnitOfWork(database),
    );
    creditSales = CreditSaleService(
      inventory: this.inventory,
      customers: this.customers,
      unitOfWork: SqliteCreditSaleUnitOfWork(database),
    );
    openingBalances = RecordOpeningBalanceService(ledger: ledger);
    payments = RecordCustomerPaymentService(ledger: ledger);
  }

  final DatabaseService database;
  final MerchantInventoryRepository inventory;
  final SaleRepository sales;
  final CustomerRepository customers;
  final StoreSettingsRepository settings;
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
