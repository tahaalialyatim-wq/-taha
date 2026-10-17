import 'dart:io';

import 'package:awtad_mobile/core/database/database_init_exception.dart';
import 'package:awtad_mobile/core/database/database_service.dart';
import 'package:awtad_mobile/core/database/retail_session.dart';
import 'package:awtad_mobile/core/database/sqlite_customer_repository.dart';
import 'package:awtad_mobile/core/database/sqlite_inventory_repository.dart';
import 'package:awtad_mobile/core/database/sqlite_ledger_repository.dart';
import 'package:awtad_mobile/core/database/sqlite_sale_repository.dart';
import 'package:awtad_mobile/core/database/sqlite_sale_unit_of_work.dart';
import 'package:awtad_retail/awtad_retail.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart';

/// Writes a schema-v1 database file with representative business rows so the
/// v1 -> v2 migration can be exercised against realistic existing data.
void seedLegacyV1Database(String path, {int version = 1}) {
  final db = sqlite3.open(path);
  try {
    db.execute('CREATE TABLE schema_info (version INTEGER NOT NULL);');
    db.execute('''
CREATE TABLE inventory_items (
  merchant_id TEXT NOT NULL,
  item_id TEXT NOT NULL,
  product_id TEXT NOT NULL,
  quantity_milli INTEGER NOT NULL,
  selling_currency TEXT,
  selling_minor INTEGER,
  purchase_currency TEXT,
  purchase_minor INTEGER,
  minimum_stock_milli INTEGER,
  PRIMARY KEY (merchant_id, item_id),
  UNIQUE (merchant_id, product_id)
);
''');
    db.execute('''
CREATE TABLE customers (
  merchant_id TEXT NOT NULL,
  customer_id TEXT NOT NULL,
  name TEXT NOT NULL,
  phone TEXT,
  notes TEXT,
  PRIMARY KEY (merchant_id, customer_id)
);
''');
    db.execute('''
CREATE TABLE sales (
  merchant_id TEXT NOT NULL,
  sale_id TEXT NOT NULL,
  currency TEXT NOT NULL,
  customer_id TEXT,
  PRIMARY KEY (merchant_id, sale_id)
);
''');
    db.execute('''
CREATE TABLE sale_lines (
  merchant_id TEXT NOT NULL,
  sale_id TEXT NOT NULL,
  line_index INTEGER NOT NULL,
  product_id TEXT NOT NULL,
  quantity_milli INTEGER NOT NULL,
  unit_currency TEXT NOT NULL,
  unit_minor INTEGER NOT NULL,
  PRIMARY KEY (merchant_id, sale_id, line_index),
  FOREIGN KEY (merchant_id, sale_id) REFERENCES sales (merchant_id, sale_id)
);
''');
    db.execute('''
CREATE TABLE ledger_entries (
  merchant_id TEXT NOT NULL,
  entry_id TEXT NOT NULL,
  customer_id TEXT NOT NULL,
  currency TEXT NOT NULL,
  amount_minor INTEGER NOT NULL,
  entry_type TEXT NOT NULL,
  occurred_at TEXT NOT NULL,
  reference TEXT,
  PRIMARY KEY (merchant_id, entry_id)
);
''');
    db.execute('INSERT INTO schema_info (version) VALUES (?);', [version]);
    db.execute(
      'INSERT INTO inventory_items (merchant_id, item_id, product_id, '
      'quantity_milli, selling_currency, selling_minor, purchase_currency, '
      "purchase_minor, minimum_stock_milli) VALUES ('m1', 'i1', 'p1', 5000, "
      "'YER', 1500, 'SAR', 900, 1000);",
    );
    db.execute(
      'INSERT INTO customers (merchant_id, customer_id, name, phone, notes) '
      "VALUES ('m1', 'c1', 'عميل', '777', NULL);",
    );
    db.execute(
      'INSERT INTO sales (merchant_id, sale_id, currency, customer_id) '
      "VALUES ('m1', 's1', 'SAR', 'c1');",
    );
    db.execute(
      'INSERT INTO sale_lines (merchant_id, sale_id, line_index, product_id, '
      'quantity_milli, unit_currency, unit_minor) '
      "VALUES ('m1', 's1', 0, 'p1', 2000, 'SAR', 900);",
    );
    db.execute(
      'INSERT INTO ledger_entries (merchant_id, entry_id, customer_id, '
      'currency, amount_minor, entry_type, occurred_at, reference) '
      "VALUES ('m1', 'e1', 'c1', 'USD', 500, 'credit', "
      "'2026-10-11T00:00:00.000Z', NULL);",
    );
  } finally {
    db.dispose();
  }
}

void main() {
  late Directory dir;
  late String path;

  setUp(() {
    dir = Directory.systemTemp.createTempSync('awtad-db-');
    path = DatabaseService.pathIn(dir.path);
  });

  tearDown(() {
    if (dir.existsSync()) {
      dir.deleteSync(recursive: true);
    }
  });

  test('initialize is idempotent and uses schema v2', () async {
    final service = DatabaseService(databasePath: path);
    await service.initialize();
    await service.initialize();
    final version = service.database.select(
      'SELECT version FROM schema_info;',
    );
    expect(version.first['version'], DatabaseService.schemaVersion);
    expect(DatabaseService.schemaVersion, 2);
    service.close();
  });

  test('fresh database initializes at schema v2 with store_settings', () async {
    final service = DatabaseService(databasePath: path);
    await service.initialize();
    addTearDown(service.close);
    expect(
      service.database
          .select('SELECT version FROM schema_info;')
          .first['version'],
      2,
    );
    final tables = service.database.select(
      "SELECT name FROM sqlite_master WHERE type = 'table' "
      "AND name = 'store_settings';",
    );
    expect(tables.length, 1);
    expect(
      service.database
          .select(
            "SELECT name FROM sqlite_master WHERE type = 'table' "
            "AND name = 'inventory_items';",
          )
          .length,
      1,
    );
  });

  test('v1 database migrates to v2 preserving rows and currencies', () async {
    seedLegacyV1Database(path);
    final service = DatabaseService(databasePath: path);
    await service.initialize();
    addTearDown(service.close);
    expect(
      service.database
          .select('SELECT version FROM schema_info;')
          .first['version'],
      2,
    );

    final inventory = service.database.select('SELECT * FROM inventory_items;');
    expect(inventory.length, 1);
    expect(inventory.first['selling_currency'], 'YER');
    expect(inventory.first['selling_minor'], 1500);
    expect(inventory.first['purchase_currency'], 'SAR');
    expect(inventory.first['purchase_minor'], 900);
    expect(inventory.first['quantity_milli'], 5000);

    final customers = service.database.select('SELECT * FROM customers;');
    expect(customers.length, 1);
    expect(customers.first['name'], 'عميل');

    final sales = service.database.select('SELECT * FROM sales;');
    expect(sales.length, 1);
    expect(sales.first['currency'], 'SAR');
    expect(sales.first['customer_id'], 'c1');

    final lines = service.database.select('SELECT * FROM sale_lines;');
    expect(lines.length, 1);
    expect(lines.first['unit_currency'], 'SAR');
    expect(lines.first['unit_minor'], 900);

    final ledger = service.database.select('SELECT * FROM ledger_entries;');
    expect(ledger.length, 1);
    expect(ledger.first['currency'], 'USD');
    expect(ledger.first['amount_minor'], 500);
  });

  test('store settings save, read, and persist across reopen', () async {
    final service = DatabaseService(databasePath: path);
    await service.initialize();
    final session = RetailSession(service);
    final merchant = RetailSession.defaultMerchant;
    expect(await session.settings.readDefaultCurrency(merchant), isNull);

    await session.settings.saveDefaultCurrency(
      merchant,
      CurrencyCode.yemeniRial,
    );
    expect(
      await session.settings.readDefaultCurrency(merchant),
      CurrencyCode.yemeniRial,
    );
    service.close();

    final reopened = DatabaseService(databasePath: path);
    await reopened.initialize();
    addTearDown(reopened.close);
    final reopenedSession = RetailSession(reopened);
    expect(
      await reopenedSession.settings.readDefaultCurrency(merchant),
      CurrencyCode.yemeniRial,
    );
  });

  test('unambiguous transaction currency is suggested but not persisted',
      () async {
    final service = DatabaseService(databasePath: path);
    await service.initialize();
    addTearDown(service.close);
    service.database.execute(
      'INSERT INTO sales (merchant_id, sale_id, currency, customer_id) '
      "VALUES ('m1', 's1', 'YER', NULL);",
    );
    final session = RetailSession(service);
    expect(
      await session.settings.suggestDefaultCurrency(MerchantId('m1')),
      CurrencyCode.yemeniRial,
    );
    expect(
      await session.settings.readDefaultCurrency(MerchantId('m1')),
      isNull,
    );
  });

  test('mixed transaction currencies yield no suggestion', () async {
    seedLegacyV1Database(path);
    final service = DatabaseService(databasePath: path);
    await service.initialize();
    addTearDown(service.close);
    final session = RetailSession(service);
    expect(
      await session.settings.suggestDefaultCurrency(MerchantId('m1')),
      isNull,
    );
    expect(
      await session.settings.readDefaultCurrency(MerchantId('m1')),
      isNull,
    );
  });

  test('failed migration rolls back safely', () async {
    seedLegacyV1Database(path);
    final raw = sqlite3.open(path);
    try {
      raw.execute(
        'CREATE TRIGGER block_version BEFORE UPDATE ON schema_info '
        "BEGIN SELECT RAISE(ABORT, 'blocked'); END;",
      );
    } finally {
      raw.dispose();
    }

    final service = DatabaseService(databasePath: path);
    await expectLater(
      service.initialize(),
      throwsA(isA<DatabaseInitException>()),
    );
    expect(service.isOpen, isFalse);

    final check = sqlite3.open(path);
    try {
      expect(
        check.select('SELECT version FROM schema_info;').first['version'],
        1,
      );
      expect(
        check
            .select(
              "SELECT name FROM sqlite_master WHERE type = 'table' "
              "AND name = 'store_settings';",
            )
            .length,
        0,
      );
    } finally {
      check.dispose();
    }
  });

  test('unknown schema version fails closed', () async {
    seedLegacyV1Database(path, version: 99);
    final service = DatabaseService(databasePath: path);
    await expectLater(
      service.initialize(),
      throwsA(isA<DatabaseInitException>()),
    );
    expect(service.isOpen, isFalse);
  });

  test('initialize does not fall back to in-memory on failure', () async {
    final service = DatabaseService(
      databasePath: path,
      opener: (_) => throw StateError('open failed'),
    );
    await expectLater(
      service.initialize(),
      throwsA(isA<DatabaseInitException>()),
    );
    expect(service.isOpen, isFalse);
  });

  test('cash sale commits stock and sale in one transaction', () async {
    final service = DatabaseService(databasePath: path);
    await service.initialize();
    addTearDown(service.close);
    final inventory = SqliteInventoryRepository(service);
    final inventoryService = MerchantInventoryService(inventory);
    final merchant = MerchantId('m1');
    await inventoryService.addProduct(
      merchant,
      ProductId('p1'),
      quantity: Quantity.whole(5),
      sellingPrice: const Money(
        currency: CurrencyCode.saudiRiyal,
        minorUnits: 100,
      ),
    );
    final cash = CompleteSaleService(
      inventory: inventory,
      unitOfWork: SqliteCompleteSaleUnitOfWork(service),
    );
    await cash.complete(
      CompleteSaleCommand(
        saleId: SaleId('s1'),
        merchantId: merchant,
        currency: CurrencyCode.saudiRiyal,
        lines: <SaleCommandLine>[
          SaleCommandLine(
            productId: ProductId('p1'),
            quantity: Quantity.whole(2),
          ),
        ],
      ),
    );
    final remaining = await inventoryService.findByProduct(
      merchant,
      ProductId('p1'),
    );
    expect(remaining!.quantity, Quantity.whole(3));
    final sales = SqliteSaleRepository(service);
    final sale = await sales.getById(merchant, SaleId('s1'));
    expect(sale, isNotNull);
    expect(sale!.customerId, isNull);
    expect(sale.total.minorUnits, 200);
  });

  test('failed cash sale rolls back stock and sale together', () async {
    final service = DatabaseService(databasePath: path);
    await service.initialize();
    addTearDown(service.close);
    final inventory = SqliteInventoryRepository(service);
    final inventoryService = MerchantInventoryService(inventory);
    final merchant = MerchantId('m1');
    await inventoryService.addProduct(
      merchant,
      ProductId('p1'),
      quantity: Quantity.whole(1),
      sellingPrice: const Money(
        currency: CurrencyCode.saudiRiyal,
        minorUnits: 100,
      ),
    );
    final cash = CompleteSaleService(
      inventory: inventory,
      unitOfWork: SqliteCompleteSaleUnitOfWork(service),
    );
    await expectLater(
      cash.complete(
        CompleteSaleCommand(
          saleId: SaleId('s-fail'),
          merchantId: merchant,
          currency: CurrencyCode.saudiRiyal,
          lines: <SaleCommandLine>[
            SaleCommandLine(
              productId: ProductId('p1'),
              quantity: Quantity.whole(4),
            ),
          ],
        ),
      ),
      throwsA(isA<InsufficientStockException>()),
    );
    final remaining = await inventoryService.findByProduct(
      merchant,
      ProductId('p1'),
    );
    expect(remaining!.quantity, Quantity.whole(1));
    final sales = SqliteSaleRepository(service);
    expect(await sales.getById(merchant, SaleId('s-fail')), isNull);
  });

  test('credit sale commits stock, sale, and ledger together', () async {
    final service = DatabaseService(databasePath: path);
    await service.initialize();
    addTearDown(service.close);
    final inventory = SqliteInventoryRepository(service);
    final customers = SqliteCustomerRepository(service);
    final ledger = SqliteLedgerRepository(service, customers: customers);
    final inventoryService = MerchantInventoryService(inventory);
    final merchant = MerchantId('m1');
    final customerId = CustomerId('c1');
    await inventoryService.addProduct(
      merchant,
      ProductId('p1'),
      quantity: Quantity.whole(5),
      sellingPrice: const Money(
        currency: CurrencyCode.saudiRiyal,
        minorUnits: 100,
      ),
    );
    await customers.add(
      Customer(
        id: customerId,
        merchantId: merchant,
        name: 'عميل',
      ),
    );
    final credit = CreditSaleService(
      inventory: inventory,
      customers: customers,
      unitOfWork: SqliteCreditSaleUnitOfWork(service),
    );
    await credit.complete(
      CreditSaleCommand(
        saleId: SaleId('s2'),
        merchantId: merchant,
        customerId: customerId,
        ledgerEntryId: CustomerAccountEntryId('e1'),
        currency: CurrencyCode.saudiRiyal,
        occurredAt: DateTime.utc(2026, 10, 11),
        lines: <SaleCommandLine>[
          SaleCommandLine(
            productId: ProductId('p1'),
            quantity: Quantity.whole(2),
          ),
        ],
      ),
    );
    final remaining = await inventoryService.findByProduct(
      merchant,
      ProductId('p1'),
    );
    expect(remaining!.quantity, Quantity.whole(3));
    final sale = await SqliteSaleRepository(service).getById(
      merchant,
      SaleId('s2'),
    );
    expect(sale!.customerId, customerId);
    final balance = await ledger.getBalance(
      merchant,
      customerId,
      CurrencyCode.saudiRiyal,
    );
    expect(balance.balanceMinorUnits, 200);
  });

  test('opening balance is first and payment can overpay on sqlite', () async {
    final service = DatabaseService(databasePath: path);
    await service.initialize();
    addTearDown(service.close);
    final session = RetailSession(service);
    final merchant = RetailSession.defaultMerchant;
    final customerId = CustomerId('c1');
    await session.customers.add(
      Customer(id: customerId, merchantId: merchant, name: 'عميل'),
    );
    await session.openingBalances.record(
      RecordOpeningBalanceCommand(
        entryId: CustomerAccountEntryId('ob1'),
        merchantId: merchant,
        customerId: customerId,
        currency: CurrencyCode.yemeniRial,
        amount: const Money(
          currency: CurrencyCode.yemeniRial,
          minorUnits: 1000,
        ),
        occurredAt: DateTime.utc(2026, 10, 12),
      ),
    );
    expect(
      (await session.ledger.getBalance(
        merchant,
        customerId,
        CurrencyCode.yemeniRial,
      ))
          .balanceMinorUnits,
      1000,
    );
    await session.payments.record(
      RecordCustomerPaymentCommand(
        entryId: CustomerAccountEntryId('p1'),
        merchantId: merchant,
        customerId: customerId,
        currency: CurrencyCode.yemeniRial,
        amount: const Money(
          currency: CurrencyCode.yemeniRial,
          minorUnits: 400,
        ),
        occurredAt: DateTime.utc(2026, 10, 12),
      ),
    );
    expect(
      (await session.ledger.getBalance(
        merchant,
        customerId,
        CurrencyCode.yemeniRial,
      ))
          .balanceMinorUnits,
      600,
    );
    await session.payments.record(
      RecordCustomerPaymentCommand(
        entryId: CustomerAccountEntryId('p2'),
        merchantId: merchant,
        customerId: customerId,
        currency: CurrencyCode.yemeniRial,
        amount: const Money(
          currency: CurrencyCode.yemeniRial,
          minorUnits: 900,
        ),
        occurredAt: DateTime.utc(2026, 10, 12),
      ),
    );
    final overpaid = await session.ledger.getBalance(
      merchant,
      customerId,
      CurrencyCode.yemeniRial,
    );
    expect(overpaid.balanceMinorUnits, -300);
    final entries = await session.ledger.getEntries(merchant, customerId);
    expect(entries.map((e) => e.type), <CustomerAccountEntryType>[
      CustomerAccountEntryType.openingBalance,
      CustomerAccountEntryType.payment,
      CustomerAccountEntryType.payment,
    ]);
  });

  test('duplicate ledger entry id is rejected without extra sqlite rows',
      () async {
    final service = DatabaseService(databasePath: path);
    await service.initialize();
    addTearDown(service.close);
    final session = RetailSession(service);
    final merchant = RetailSession.defaultMerchant;
    final customerId = CustomerId('c1');
    await session.customers.add(
      Customer(id: customerId, merchantId: merchant, name: 'عميل'),
    );
    final command = RecordCustomerPaymentCommand(
      entryId: CustomerAccountEntryId('dup'),
      merchantId: merchant,
      customerId: customerId,
      currency: CurrencyCode.saudiRiyal,
      amount: const Money(
        currency: CurrencyCode.saudiRiyal,
        minorUnits: 250,
      ),
      occurredAt: DateTime.utc(2026, 10, 12),
    );
    await session.payments.record(command);
    await expectLater(
      session.payments.record(command),
      throwsA(isA<DuplicateCustomerAccountEntryException>()),
    );
    expect(
      await session.ledger.getEntries(merchant, customerId),
      hasLength(1),
    );
  });

  test('rejected sqlite opening balance leaves prior entries unchanged',
      () async {
    final service = DatabaseService(databasePath: path);
    await service.initialize();
    addTearDown(service.close);
    final session = RetailSession(service);
    final merchant = RetailSession.defaultMerchant;
    final customerId = CustomerId('c1');
    await session.customers.add(
      Customer(id: customerId, merchantId: merchant, name: 'عميل'),
    );
    await session.payments.record(
      RecordCustomerPaymentCommand(
        entryId: CustomerAccountEntryId('p1'),
        merchantId: merchant,
        customerId: customerId,
        currency: CurrencyCode.yemeniRial,
        amount: const Money(
          currency: CurrencyCode.yemeniRial,
          minorUnits: 400,
        ),
        occurredAt: DateTime.utc(2026, 10, 12),
      ),
    );
    await expectLater(
      session.openingBalances.record(
        RecordOpeningBalanceCommand(
          entryId: CustomerAccountEntryId('ob1'),
          merchantId: merchant,
          customerId: customerId,
          currency: CurrencyCode.yemeniRial,
          amount: const Money(
            currency: CurrencyCode.yemeniRial,
            minorUnits: 100,
          ),
          occurredAt: DateTime.utc(2026, 10, 12),
        ),
      ),
      throwsA(isA<OpeningBalanceNotFirstException>()),
    );
    final entries = await session.ledger.getEntries(merchant, customerId);
    expect(entries, hasLength(1));
    expect(entries.single.type, CustomerAccountEntryType.payment);
    expect(
      (await session.ledger.getBalance(
        merchant,
        customerId,
        CurrencyCode.yemeniRial,
      ))
          .balanceMinorUnits,
      -400,
    );
  });
}
