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

  test('initialize is idempotent and uses schema v1', () async {
    final service = DatabaseService(databasePath: path);
    await service.initialize();
    await service.initialize();
    final version = service.database.select(
      'SELECT version FROM schema_info;',
    );
    expect(version.first['version'], DatabaseService.schemaVersion);
    service.close();
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
