import 'package:awtad_mobile/core/database/database_service.dart';
import 'package:awtad_mobile/core/database/retail_session.dart';
import 'package:awtad_mobile/core/database/sqlite_store_settings_repository.dart';
import 'package:awtad_retail/awtad_retail.dart';

class MemoryStoreSettingsRepository implements StoreSettingsRepository {
  CurrencyCode? value;

  @override
  Future<CurrencyCode?> readDefaultCurrency(MerchantId merchantId) async {
    return value;
  }

  @override
  Future<void> saveDefaultCurrency(
    MerchantId merchantId,
    CurrencyCode currency,
  ) async {
    value = currency;
  }
}

class FakeCustomerRepository implements CustomerRepository {
  FakeCustomerRepository({this.addError, List<Customer>? items})
      : items = items ?? <Customer>[];

  Object? addError;
  final List<Customer> items;

  @override
  Future<void> add(Customer customer) async {
    final error = addError;
    if (error != null) {
      throw error;
    }
    items.add(customer);
  }

  @override
  Future<List<Customer>> getAll(MerchantId merchantId) async {
    return List<Customer>.unmodifiable(items);
  }

  @override
  Future<Customer?> getById(MerchantId merchantId, CustomerId customerId) async {
    for (final customer in items) {
      if (customer.id == customerId) {
        return customer;
      }
    }
    return null;
  }

  @override
  Future<void> update(Customer customer) async {}

  @override
  Future<void> remove(MerchantId merchantId, CustomerId customerId) async {}

  @override
  Future<bool> exists(MerchantId merchantId, CustomerId customerId) async {
    return false;
  }
}

class FakeInventoryRepository implements MerchantInventoryRepository {
  FakeInventoryRepository({this.addError, List<MerchantInventoryItem>? items})
      : items = items ?? <MerchantInventoryItem>[];

  Object? addError;
  final List<MerchantInventoryItem> items;

  @override
  Future<MerchantInventoryItem> add(MerchantInventoryItem item) async {
    final error = addError;
    if (error != null) {
      throw error;
    }
    items.add(item);
    return item;
  }

  @override
  Future<List<MerchantInventoryItem>> getAll(MerchantId merchantId) async {
    return List<MerchantInventoryItem>.unmodifiable(items);
  }

  @override
  Future<MerchantInventoryItem?> getById(
    MerchantId merchantId,
    InventoryItemId id,
  ) async {
    return null;
  }

  @override
  Future<MerchantInventoryItem?> getByProduct(
    MerchantId merchantId,
    ProductId productId,
  ) async {
    for (final item in items) {
      if (item.productId == productId) {
        return item;
      }
    }
    return null;
  }

  @override
  Future<bool> exists(MerchantId merchantId, InventoryItemId id) async {
    return false;
  }

  @override
  Future<MerchantInventoryItem> update(MerchantInventoryItem item) async {
    return item;
  }

  @override
  Future<MerchantInventoryItem> updateQuantity(
    MerchantId merchantId,
    InventoryItemId id,
    Quantity quantity,
  ) async {
    throw UnsupportedError('updateQuantity');
  }

  @override
  Future<void> decrementQuantity(
    MerchantId merchantId,
    InventoryItemId inventoryItemId,
    Quantity amount,
  ) async {}

  @override
  Future<void> decrementQuantities(
    MerchantId merchantId,
    List<InventoryDecrement> decrements,
  ) async {}

  @override
  Future<bool> remove(MerchantId merchantId, InventoryItemId id) async {
    return false;
  }
}

RetailSession sessionWithoutSqlite({
  CustomerRepository? customers,
  MerchantInventoryRepository? inventory,
  StoreSettingsRepository? settings,
}) {
  return RetailSession(
    DatabaseService(databasePath: 'phase1-unused.sqlite'),
    customers: customers ?? FakeCustomerRepository(),
    inventory: inventory ?? FakeInventoryRepository(),
    sales: InMemorySaleRepository(),
    settings: settings ?? MemoryStoreSettingsRepository(),
  );
}
