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

/// Writes a schema-v2 database file (v1 tables plus `store_settings`) so the
/// v2 -> v3 migration can be exercised without cost columns.
void seedLegacyV2Database(String path) {
  seedLegacyV1Database(path);
  final db = sqlite3.open(path);
  try {
    db.execute('''
CREATE TABLE store_settings (
  merchant_id TEXT NOT NULL PRIMARY KEY,
  default_currency TEXT
);
''');
    db.execute('UPDATE schema_info SET version = 2;');
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

  test('initialize is idempotent and uses schema v3', () async {
    final service = DatabaseService(databasePath: path);
    await service.initialize();
    await service.initialize();
    final version = service.database.select(
      'SELECT version FROM schema_info;',
    );
    expect(version.first['version'], DatabaseService.schemaVersion);
    expect(DatabaseService.schemaVersion, 3);
    service.close();
  });

  test('fresh database initializes at schema v3 with cost columns', () async {
    final service = DatabaseService(databasePath: path);
    await service.initialize();
    addTearDown(service.close);
    expect(
      service.database
          .select('SELECT version FROM schema_info;')
          .first['version'],
      3,
    );
    final costColumns = service.database.select(
      'PRAGMA table_info(sale_lines);',
    );
    final names = costColumns.map((row) => row['name']).toSet();
    expect(names, contains('unit_cost_currency'));
    expect(names, contains('unit_cost_minor'));
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

  test('v1 database migrates to v3 preserving rows and currencies', () async {
    seedLegacyV1Database(path);
    final service = DatabaseService(databasePath: path);
    await service.initialize();
    addTearDown(service.close);
    expect(
      service.database
          .select('SELECT version FROM schema_info;')
          .first['version'],
      3,
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
    expect(lines.first['unit_cost_currency'], isNull);
    expect(lines.first['unit_cost_minor'], isNull);

    final legacySale = await SqliteSaleRepository(service)
        .getById(MerchantId('m1'), SaleId('s1'));
    expect(legacySale, isNotNull);
    expect(legacySale!.lines.single.unitPurchaseCost, isNull);
    expect(legacySale.lines.single.grossProfit, isNull);

    final ledger = service.database.select('SELECT * FROM ledger_entries;');
    expect(ledger.length, 1);
    expect(ledger.first['currency'], 'USD');
    expect(ledger.first['amount_minor'], 500);
  });

  test('v2 database migrates to v3 without rewriting existing rows', () async {
    seedLegacyV2Database(path);
    final raw = sqlite3.open(path);
    try {
      raw.execute(
        'INSERT INTO store_settings (merchant_id, default_currency) '
        "VALUES ('m1', 'YER');",
      );
    } finally {
      raw.dispose();
    }
    final service = DatabaseService(databasePath: path);
    await service.initialize();
    addTearDown(service.close);
    expect(
      service.database
          .select('SELECT version FROM schema_info;')
          .first['version'],
      3,
    );

    final settings = service.database.select('SELECT * FROM store_settings;');
    expect(settings, hasLength(1));
    expect(settings.first['default_currency'], 'YER');

    final inventory = service.database.select('SELECT * FROM inventory_items;');
    expect(inventory.length, 1);
    expect(inventory.first['selling_currency'], 'YER');
    expect(inventory.first['purchase_currency'], 'SAR');

    final lines = service.database.select('SELECT * FROM sale_lines;');
    expect(lines.length, 1);
    expect(lines.first['unit_currency'], 'SAR');
    expect(lines.first['unit_minor'], 900);
    expect(lines.first['unit_cost_currency'], isNull);
    expect(lines.first['unit_cost_minor'], isNull);

    final legacySale = await SqliteSaleRepository(service)
        .getById(MerchantId('m1'), SaleId('s1'));
    expect(legacySale!.lines.single.unitPurchaseCost, isNull);
    expect(legacySale.lines.single.grossProfit, isNull);
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
      final rolledBackColumns = check.select('PRAGMA table_info(sale_lines);');
      final names = rolledBackColumns.map((row) => row['name']).toSet();
      expect(names, isNot(contains('unit_cost_currency')));
      expect(names, isNot(contains('unit_cost_minor')));
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

  test('sale line cost snapshots survive persistence and inventory edits',
      () async {
    final service = DatabaseService(databasePath: path);
    await service.initialize();
    addTearDown(service.close);
    final inventory = SqliteInventoryRepository(service);
    final inventoryService = MerchantInventoryService(inventory);
    final merchant = MerchantId('m1');
    const cost = Money(
      currency: CurrencyCode.saudiRiyal,
      minorUnits: 60,
    );
    const selling = Money(
      currency: CurrencyCode.saudiRiyal,
      minorUnits: 100,
    );
    await inventoryService.addProduct(
      merchant,
      ProductId('p1'),
      quantity: Quantity.whole(5),
      sellingPrice: selling,
      purchasePrice: cost,
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

    final sales = SqliteSaleRepository(service);
    var sale = await sales.getById(merchant, SaleId('s1'));
    expect(sale!.lines.single.unitPurchaseCost, cost);
    expect(sale.lines.single.grossProfit!.minorUnits, 80);

    final raw = service.database.select(
      'SELECT unit_cost_currency, unit_cost_minor FROM sale_lines;',
    );
    expect(raw.first['unit_cost_currency'], 'SAR');
    expect(raw.first['unit_cost_minor'], 60);

    final item = await inventoryService.findByProduct(
      merchant,
      ProductId('p1'),
    );
    await inventory.update(
      item!.copyWith(
        purchasePrice: const Money(
          currency: CurrencyCode.saudiRiyal,
          minorUnits: 90,
        ),
      ),
    );

    sale = await sales.getById(merchant, SaleId('s1'));
    expect(sale!.lines.single.unitPurchaseCost, cost);
    expect(sale.lines.single.grossProfit!.minorUnits, 80);
  });

  test('inventory update rejects negative prices and accepts zero or omitted',
      () async {
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
    );
    final existing = (await inventoryService.findByProduct(
      merchant,
      ProductId('p1'),
    ))!;

    expect(
      () => inventory.update(
        existing.copyWith(
          sellingPrice: const Money(
            currency: CurrencyCode.yemeniRial,
            minorUnits: -1,
          ),
        ),
      ),
      throwsA(isA<ArgumentError>()),
    );
    expect(
      () => inventory.update(
        existing.copyWith(
          purchasePrice: const Money(
            currency: CurrencyCode.yemeniRial,
            minorUnits: -5,
          ),
        ),
      ),
      throwsA(isA<ArgumentError>()),
    );
    final stored = await inventoryService.findByProduct(
      merchant,
      ProductId('p1'),
    );
    expect(stored!.sellingPrice, isNull);
    expect(stored.purchasePrice, isNull);

    final zeroSelling = await inventory.update(
      existing.copyWith(
        sellingPrice: const Money(
          currency: CurrencyCode.yemeniRial,
          minorUnits: 0,
        ),
      ),
    );
    expect(zeroSelling.sellingPrice!.minorUnits, 0);
    expect(zeroSelling.purchasePrice, isNull);

    final omitted = await inventory.update(
      MerchantInventoryItem(
        id: existing.id,
        merchantId: existing.merchantId,
        productId: existing.productId,
        quantity: existing.quantity,
      ),
    );
    expect(omitted.sellingPrice, isNull);
    expect(omitted.purchasePrice, isNull);
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

  test('sqlite customer add rejects a duplicate id and writes nothing',
      () async {
    final service = DatabaseService(databasePath: path);
    await service.initialize();
    addTearDown(service.close);
    final customers = SqliteCustomerRepository(service);
    final merchant = MerchantId('m1');
    await customers.add(
      Customer(
        id: CustomerId('c1'),
        merchantId: merchant,
        name: 'Ali',
        phone: '777',
      ),
    );
    expect(
      () => customers.add(
        Customer(
          id: CustomerId('c1'),
          merchantId: merchant,
          name: 'Sara',
          phone: '888',
        ),
      ),
      throwsA(isA<DuplicateCustomerException>()),
    );
    expect(await customers.getAll(merchant), hasLength(1));
    expect(
      (await customers.getById(merchant, CustomerId('c1')))!.name,
      'Ali',
    );
    await customers.add(
      Customer(
        id: CustomerId('c2'),
        merchantId: merchant,
        name: 'Sara',
        phone: '888',
      ),
    );
    expect(await customers.getAll(merchant), hasLength(2));
  });

  test('sqlite customer add rejects a duplicate phone and writes nothing',
      () async {
    final service = DatabaseService(databasePath: path);
    await service.initialize();
    addTearDown(service.close);
    final customers = SqliteCustomerRepository(service);
    final merchant = MerchantId('m1');
    await customers.add(
      Customer(
        id: CustomerId('c1'),
        merchantId: merchant,
        name: 'Ali',
        phone: '777',
      ),
    );
    expect(
      () => customers.add(
        Customer(
          id: CustomerId('c2'),
          merchantId: merchant,
          name: 'Sara',
          phone: '777',
        ),
      ),
      throwsA(isA<DuplicateCustomerPhoneException>()),
    );
    expect(await customers.getAll(merchant), hasLength(1));
    expect(
      (await customers.getById(merchant, CustomerId('c1')))!.phone,
      '777',
    );
    await customers.add(
      Customer(
        id: CustomerId('c2'),
        merchantId: merchant,
        name: 'Sara',
        phone: '888',
      ),
    );
    expect(await customers.getAll(merchant), hasLength(2));
  });

  test('sqlite customer update rejects a duplicate phone and leaves rows',
      () async {
    final service = DatabaseService(databasePath: path);
    await service.initialize();
    addTearDown(service.close);
    final customers = SqliteCustomerRepository(service);
    final merchant = MerchantId('m1');
    await customers.add(
      Customer(
        id: CustomerId('c1'),
        merchantId: merchant,
        name: 'Ali',
        phone: '777',
      ),
    );
    await customers.add(
      Customer(
        id: CustomerId('c2'),
        merchantId: merchant,
        name: 'Sara',
        phone: '888',
      ),
    );
    expect(
      () => customers.update(
        Customer(
          id: CustomerId('c2'),
          merchantId: merchant,
          name: 'Sara',
          phone: '777',
        ),
      ),
      throwsA(isA<DuplicateCustomerPhoneException>()),
    );
    expect(
      (await customers.getById(merchant, CustomerId('c2')))!.phone,
      '888',
    );
    expect(
      (await customers.getById(merchant, CustomerId('c1')))!.phone,
      '777',
    );
    await customers.update(
      Customer(
        id: CustomerId('c2'),
        merchantId: merchant,
        name: 'Sara',
        phone: '999',
      ),
    );
    expect(
      (await customers.getById(merchant, CustomerId('c2')))!.phone,
      '999',
    );
  });

  test('sqlite customers of different merchants may share a phone', () async {
    final service = DatabaseService(databasePath: path);
    await service.initialize();
    addTearDown(service.close);
    final customers = SqliteCustomerRepository(service);
    await customers.add(
      Customer(
        id: CustomerId('c1'),
        merchantId: MerchantId('m1'),
        name: 'Ali',
        phone: '777',
      ),
    );
    await customers.add(
      Customer(
        id: CustomerId('c2'),
        merchantId: MerchantId('m2'),
        name: 'Sara',
        phone: '777',
      ),
    );
    expect(
      (await customers.getById(MerchantId('m1'), CustomerId('c1')))!.phone,
      '777',
    );
    expect(
      (await customers.getById(MerchantId('m2'), CustomerId('c2')))!.phone,
      '777',
    );
  });

  test('sqlite customer update may keep the same phone', () async {
    final service = DatabaseService(databasePath: path);
    await service.initialize();
    addTearDown(service.close);
    final customers = SqliteCustomerRepository(service);
    final merchant = MerchantId('m1');
    await customers.add(
      Customer(
        id: CustomerId('c1'),
        merchantId: merchant,
        name: 'Ali',
        phone: '777',
      ),
    );
    await customers.update(
      Customer(
        id: CustomerId('c1'),
        merchantId: merchant,
        name: 'Sara',
        phone: '777',
      ),
    );
    final found = await customers.getById(merchant, CustomerId('c1'));
    expect(found!.name, 'Sara');
    expect(found.phone, '777');
  });
}
