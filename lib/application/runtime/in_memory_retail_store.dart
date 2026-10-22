import '../../domain/catalog/product_id.dart';
import '../../domain/catalog/quantity.dart';
import '../../domain/customer/customer.dart';
import '../../domain/customer/customer_account_balance.dart';
import '../../domain/customer/customer_account_entry.dart';
import '../../domain/customer/customer_account_entry_id.dart';
import '../../domain/customer/customer_account_entry_type.dart';
import '../../domain/customer/customer_id.dart';
import '../../domain/inventory/inventory_item_id.dart';
import '../../domain/inventory/merchant_inventory_item.dart';
import '../../domain/merchant/merchant_id.dart';
import '../../domain/money/currency_code.dart';
import '../../domain/sale/sale.dart';
import '../../domain/sale/sale_id.dart';
import '../customer/customer_account_ledger_exceptions.dart';
import '../customer/customer_account_ledger_repository.dart';
import '../customer/customer_exceptions.dart';
import '../customer/customer_repository.dart';
import '../inventory/inventory_decrement.dart';
import '../inventory/inventory_exceptions.dart';
import '../inventory/merchant_inventory_repository.dart';
import '../sale/sale_exceptions.dart';
import '../sale/sale_repository.dart';
import 'retail_state.dart';
import 'retail_store.dart';
import 'retail_writes.dart';

/// In-memory [RetailStore].
///
/// One [_state] reference is authoritative. Views read that snapshot and do
/// not own maps. [commit] and single-aggregate writes plan a complete next
/// snapshot, then publish it with one assignment. A thrown plan leaves live
/// state unchanged.
class InMemoryRetailStore implements RetailStore {
  InMemoryRetailStore() {
    inventory = _StoreInventoryView(this);
    sales = _StoreSaleView(this);
    customers = _StoreCustomerView(this);
    ledger = _StoreLedgerView(this);
  }

  RetailState _state = RetailState();

  @override
  late final MerchantInventoryRepository inventory;

  @override
  late final SaleRepository sales;

  @override
  late final CustomerRepository customers;

  @override
  late final CustomerAccountLedgerRepository ledger;

  @override
  void commit(RetailWrites writes) {
    _state = _planCommit(_state, writes);
  }

  void _publish(RetailState Function(RetailState current) plan) {
    _state = plan(_state);
  }

  static RetailState _planCommit(RetailState current, RetailWrites writes) {
    if (writes.sale.merchantId != writes.merchantId) {
      throw MerchantMismatchException(
        expected: writes.merchantId,
        actual: writes.sale.merchantId,
      );
    }
    _rejectDuplicateSale(current, writes.sale);
    final inventoryById = _plannedDecrements(
      current.inventoryById,
      writes.merchantId,
      writes.decrements,
    );
    final salesByKey = Map<String, Sale>.from(current.salesByKey);
    final saleOrder = List<String>.from(current.saleOrder);
    final saleKey = _saleKey(writes.sale.merchantId, writes.sale.id);
    salesByKey[saleKey] = writes.sale;
    saleOrder.add(saleKey);

    var ledgerByKey = current.ledgerByKey;
    var ledgerOrder = current.ledgerOrder;
    final entry = writes.ledgerEntry;
    if (entry != null) {
      if (entry.merchantId != writes.merchantId) {
        throw MerchantMismatchException(
          expected: writes.merchantId,
          actual: entry.merchantId,
        );
      }
      if (writes.sale.customerId == null ||
          writes.sale.customerId != entry.customerId) {
        throw ArgumentError.value(
          writes.sale.customerId,
          'sale.customerId',
          'Credit-sale ledger entry requires matching Sale.customerId',
        );
      }
      if (entry.currency != writes.sale.currency) {
        throw ArgumentError.value(
          entry.currency,
          'ledgerEntry.currency',
          'Ledger entry currency must equal sale currency',
        );
      }
      if (entry.amount != writes.sale.total) {
        throw ArgumentError.value(
          entry.amount,
          'ledgerEntry.amount',
          'Ledger entry amount must equal sale total',
        );
      }
      final planned = _plannedLedgerAppend(current, entry);
      ledgerByKey = planned.byKey;
      ledgerOrder = planned.order;
    }

    return RetailState(
      inventoryById: inventoryById,
      salesByKey: salesByKey,
      saleOrder: saleOrder,
      customersByKey: current.customersByKey,
      customerOrder: current.customerOrder,
      ledgerByKey: ledgerByKey,
      ledgerOrder: ledgerOrder,
    );
  }

  static void _rejectDuplicateSale(RetailState current, Sale sale) {
    final key = _saleKey(sale.merchantId, sale.id);
    if (current.salesByKey.containsKey(key)) {
      throw DuplicateSaleException(
        merchantId: sale.merchantId,
        saleId: sale.id,
      );
    }
  }

  static Map<String, MerchantInventoryItem> _plannedDecrements(
    Map<String, MerchantInventoryItem> inventoryById,
    MerchantId merchantId,
    List<InventoryDecrement> decrements,
  ) {
    if (decrements.isEmpty) {
      throw ArgumentError.value(
        decrements,
        'decrements',
        'Decrement batch must not be empty',
      );
    }
    final remainingById = <String, Quantity>{};
    for (final decrement in decrements) {
      if (decrement.amount.milliUnits <= 0) {
        throw ArgumentError.value(
          decrement.amount.milliUnits,
          'amount',
          'Decrement amount must be greater than zero',
        );
      }
      final existing = inventoryById[decrement.inventoryItemId.value];
      if (existing == null) {
        throw InventoryItemNotFoundException(
          merchantId: merchantId,
          itemId: decrement.inventoryItemId,
        );
      }
      if (existing.merchantId != merchantId) {
        throw MerchantMismatchException(
          expected: merchantId,
          actual: existing.merchantId,
        );
      }
      final previous = remainingById[existing.id.value] ?? existing.quantity;
      if (previous.milliUnits < decrement.amount.milliUnits) {
        throw InsufficientStockException(
          merchantId: merchantId,
          itemId: existing.id,
          available: previous,
          requested: decrement.amount,
        );
      }
      remainingById[existing.id.value] = Quantity.fromMilliUnits(
        previous.milliUnits - decrement.amount.milliUnits,
      );
    }
    final next = Map<String, MerchantInventoryItem>.from(inventoryById);
    for (final entry in remainingById.entries) {
      next[entry.key] = next[entry.key]!.copyWith(quantity: entry.value);
    }
    return next;
  }

  static ({
    Map<String, CustomerAccountEntry> byKey,
    List<String> order,
  }) _plannedLedgerAppend(RetailState current, CustomerAccountEntry entry) {
    _requireCustomer(current, entry.merchantId, entry.customerId);
    final key = _ledgerKey(entry.merchantId, entry.id);
    if (current.ledgerByKey.containsKey(key)) {
      throw DuplicateCustomerAccountEntryException(
        merchantId: entry.merchantId,
        entryId: entry.id,
      );
    }
    final existing = _ledgerEntriesFor(
      current,
      entry.merchantId,
      entry.customerId,
      currency: entry.currency,
    );
    if (entry.type == CustomerAccountEntryType.openingBalance) {
      if (existing.any(
        (currentEntry) =>
            currentEntry.type == CustomerAccountEntryType.openingBalance,
      )) {
        throw DuplicateOpeningBalanceException(
          merchantId: entry.merchantId,
          customerId: entry.customerId,
        );
      }
      if (existing.isNotEmpty) {
        throw OpeningBalanceNotFirstException(
          merchantId: entry.merchantId,
          customerId: entry.customerId,
          currency: entry.currency,
        );
      }
    }
    final byKey = Map<String, CustomerAccountEntry>.from(current.ledgerByKey);
    final order = List<String>.from(current.ledgerOrder);
    byKey[key] = entry;
    order.add(key);
    return (byKey: byKey, order: order);
  }

  static void _requireCustomer(
    RetailState current,
    MerchantId merchantId,
    CustomerId customerId,
  ) {
    if (!current.customersByKey
        .containsKey(_customerKey(merchantId, customerId))) {
      throw CustomerNotFoundException(
        merchantId: merchantId,
        customerId: customerId,
      );
    }
  }

  static List<CustomerAccountEntry> _ledgerEntriesFor(
    RetailState current,
    MerchantId merchantId,
    CustomerId customerId, {
    CurrencyCode? currency,
  }) {
    final entries = <CustomerAccountEntry>[];
    for (final key in current.ledgerOrder) {
      final entry = current.ledgerByKey[key];
      if (entry != null &&
          entry.merchantId == merchantId &&
          entry.customerId == customerId &&
          (currency == null || entry.currency == currency)) {
        entries.add(entry);
      }
    }
    return entries;
  }

  static Customer _requireOwnedCustomer(
    RetailState current,
    MerchantId merchantId,
    CustomerId customerId,
  ) {
    Customer? existing;
    for (final customer in current.customersByKey.values) {
      if (customer.id == customerId) {
        existing = customer;
        if (customer.merchantId == merchantId) {
          return customer;
        }
      }
    }
    if (existing == null) {
      throw CustomerNotFoundException(
        merchantId: merchantId,
        customerId: customerId,
      );
    }
    throw MerchantMismatchException(
      expected: merchantId,
      actual: existing.merchantId,
    );
  }

  static bool _hasProduct(
    Map<String, MerchantInventoryItem> inventoryById,
    MerchantId merchantId,
    ProductId productId, {
    InventoryItemId? ignoring,
  }) {
    for (final item in inventoryById.values) {
      if (item.merchantId != merchantId || item.productId != productId) {
        continue;
      }
      if (ignoring != null && item.id == ignoring) {
        continue;
      }
      return true;
    }
    return false;
  }

  static String _saleKey(MerchantId merchantId, SaleId saleId) =>
      '${merchantId.value}:${saleId.value}';

  static String _customerKey(MerchantId merchantId, CustomerId customerId) =>
      '${merchantId.value}:${customerId.value}';

  static String _ledgerKey(
    MerchantId merchantId,
    CustomerAccountEntryId entryId,
  ) =>
      '${merchantId.value}:${entryId.value}';
}

class _StoreInventoryView implements MerchantInventoryRepository {
  _StoreInventoryView(this._store);

  final InMemoryRetailStore _store;

  @override
  Future<MerchantInventoryItem?> getById(
    MerchantId merchantId,
    InventoryItemId id,
  ) async {
    final item = _store._state.inventoryById[id.value];
    if (item == null || item.merchantId != merchantId) {
      return null;
    }
    return item;
  }

  @override
  Future<MerchantInventoryItem?> getByProduct(
    MerchantId merchantId,
    ProductId productId,
  ) async {
    for (final item in _store._state.inventoryById.values) {
      if (item.merchantId == merchantId && item.productId == productId) {
        return item;
      }
    }
    return null;
  }

  @override
  Future<bool> exists(MerchantId merchantId, InventoryItemId id) async {
    final item = _store._state.inventoryById[id.value];
    return item != null && item.merchantId == merchantId;
  }

  @override
  Future<List<MerchantInventoryItem>> getAll(MerchantId merchantId) async {
    final items = _store._state.inventoryById.values
        .where((item) => item.merchantId == merchantId)
        .toList(growable: false);
    return List<MerchantInventoryItem>.unmodifiable(items);
  }

  @override
  Future<MerchantInventoryItem> add(MerchantInventoryItem item) async {
    _store._publish((current) {
      if (current.inventoryById.containsKey(item.id.value) ||
          InMemoryRetailStore._hasProduct(
            current.inventoryById,
            item.merchantId,
            item.productId,
          )) {
        throw DuplicateInventoryItemException(
          merchantId: item.merchantId,
          productId: item.productId,
        );
      }
      final inventoryById =
          Map<String, MerchantInventoryItem>.from(current.inventoryById);
      inventoryById[item.id.value] = item;
      return _withInventory(current, inventoryById);
    });
    return item;
  }

  @override
  Future<MerchantInventoryItem> update(MerchantInventoryItem item) async {
    MerchantInventoryRepository.requireNonNegativePrices(item);
    _store._publish((current) {
      final existing = current.inventoryById[item.id.value];
      if (existing == null) {
        throw InventoryItemNotFoundException(
          merchantId: item.merchantId,
          itemId: item.id,
        );
      }
      if (existing.merchantId != item.merchantId) {
        throw MerchantMismatchException(
          expected: item.merchantId,
          actual: existing.merchantId,
        );
      }
      if (InMemoryRetailStore._hasProduct(
        current.inventoryById,
        item.merchantId,
        item.productId,
        ignoring: item.id,
      )) {
        throw DuplicateInventoryItemException(
          merchantId: item.merchantId,
          productId: item.productId,
        );
      }
      final inventoryById =
          Map<String, MerchantInventoryItem>.from(current.inventoryById);
      inventoryById[item.id.value] = item;
      return _withInventory(current, inventoryById);
    });
    return item;
  }

  @override
  Future<MerchantInventoryItem> updateQuantity(
    MerchantId merchantId,
    InventoryItemId id,
    Quantity quantity,
  ) async {
    late MerchantInventoryItem updated;
    _store._publish((current) {
      final existing = current.inventoryById[id.value];
      if (existing == null) {
        throw InventoryItemNotFoundException(
            merchantId: merchantId, itemId: id);
      }
      if (existing.merchantId != merchantId) {
        throw MerchantMismatchException(
          expected: merchantId,
          actual: existing.merchantId,
        );
      }
      updated = existing.copyWith(quantity: quantity);
      final inventoryById =
          Map<String, MerchantInventoryItem>.from(current.inventoryById);
      inventoryById[id.value] = updated;
      return _withInventory(current, inventoryById);
    });
    return updated;
  }

  @override
  Future<void> decrementQuantity(
    MerchantId merchantId,
    InventoryItemId inventoryItemId,
    Quantity amount,
  ) async {
    _store._publish((current) {
      if (amount.milliUnits <= 0) {
        throw ArgumentError.value(
          amount.milliUnits,
          'amount',
          'Decrement amount must be greater than zero',
        );
      }
      final existing = current.inventoryById[inventoryItemId.value];
      if (existing == null) {
        throw InventoryItemNotFoundException(
          merchantId: merchantId,
          itemId: inventoryItemId,
        );
      }
      if (existing.merchantId != merchantId) {
        throw MerchantMismatchException(
          expected: merchantId,
          actual: existing.merchantId,
        );
      }
      if (existing.quantity.milliUnits < amount.milliUnits) {
        throw InsufficientStockException(
          merchantId: merchantId,
          itemId: inventoryItemId,
          available: existing.quantity,
          requested: amount,
        );
      }
      final remaining = Quantity.fromMilliUnits(
        existing.quantity.milliUnits - amount.milliUnits,
      );
      final inventoryById =
          Map<String, MerchantInventoryItem>.from(current.inventoryById);
      inventoryById[inventoryItemId.value] =
          existing.copyWith(quantity: remaining);
      return _withInventory(current, inventoryById);
    });
  }

  @override
  Future<void> decrementQuantities(
    MerchantId merchantId,
    List<InventoryDecrement> decrements,
  ) async {
    _store._publish((current) {
      return _withInventory(
        current,
        InMemoryRetailStore._plannedDecrements(
          current.inventoryById,
          merchantId,
          decrements,
        ),
      );
    });
  }

  @override
  Future<bool> remove(MerchantId merchantId, InventoryItemId id) async {
    var removed = false;
    _store._publish((current) {
      final existing = current.inventoryById[id.value];
      if (existing == null) {
        return current;
      }
      if (existing.merchantId != merchantId) {
        throw MerchantMismatchException(
          expected: merchantId,
          actual: existing.merchantId,
        );
      }
      final inventoryById =
          Map<String, MerchantInventoryItem>.from(current.inventoryById);
      inventoryById.remove(id.value);
      removed = true;
      return _withInventory(current, inventoryById);
    });
    return removed;
  }

  static RetailState _withInventory(
    RetailState current,
    Map<String, MerchantInventoryItem> inventoryById,
  ) {
    return RetailState(
      inventoryById: inventoryById,
      salesByKey: current.salesByKey,
      saleOrder: current.saleOrder,
      customersByKey: current.customersByKey,
      customerOrder: current.customerOrder,
      ledgerByKey: current.ledgerByKey,
      ledgerOrder: current.ledgerOrder,
    );
  }
}

class _StoreSaleView implements SaleRepository {
  _StoreSaleView(this._store);

  final InMemoryRetailStore _store;

  @override
  Future<void> add(Sale sale) async {
    _store._publish((current) {
      InMemoryRetailStore._rejectDuplicateSale(current, sale);
      final key = InMemoryRetailStore._saleKey(sale.merchantId, sale.id);
      final salesByKey = Map<String, Sale>.from(current.salesByKey);
      final saleOrder = List<String>.from(current.saleOrder);
      salesByKey[key] = sale;
      saleOrder.add(key);
      return RetailState(
        inventoryById: current.inventoryById,
        salesByKey: salesByKey,
        saleOrder: saleOrder,
        customersByKey: current.customersByKey,
        customerOrder: current.customerOrder,
        ledgerByKey: current.ledgerByKey,
        ledgerOrder: current.ledgerOrder,
      );
    });
  }

  @override
  Future<Sale?> getById(MerchantId merchantId, SaleId saleId) async {
    return _store
        ._state.salesByKey[InMemoryRetailStore._saleKey(merchantId, saleId)];
  }

  @override
  Future<List<Sale>> getAll(MerchantId merchantId) async {
    final sales = <Sale>[];
    for (final key in _store._state.saleOrder) {
      final sale = _store._state.salesByKey[key];
      if (sale != null && sale.merchantId == merchantId) {
        sales.add(sale);
      }
    }
    return List<Sale>.unmodifiable(sales);
  }
}

class _StoreCustomerView implements CustomerRepository {
  _StoreCustomerView(this._store);

  final InMemoryRetailStore _store;

  @override
  Future<void> add(Customer customer) async {
    _store._publish((current) {
      final key =
          InMemoryRetailStore._customerKey(customer.merchantId, customer.id);
      if (current.customersByKey.containsKey(key)) {
        throw DuplicateCustomerException(
          merchantId: customer.merchantId,
          customerId: customer.id,
        );
      }
      CustomerRepository.requireUniquePhone(
        customer,
        current.customersByKey.values,
      );
      final customersByKey = Map<String, Customer>.from(current.customersByKey);
      final customerOrder = List<String>.from(current.customerOrder);
      customersByKey[key] = customer;
      customerOrder.add(key);
      return RetailState(
        inventoryById: current.inventoryById,
        salesByKey: current.salesByKey,
        saleOrder: current.saleOrder,
        customersByKey: customersByKey,
        customerOrder: customerOrder,
        ledgerByKey: current.ledgerByKey,
        ledgerOrder: current.ledgerOrder,
      );
    });
  }

  @override
  Future<Customer?> getById(
    MerchantId merchantId,
    CustomerId customerId,
  ) async {
    return _store._state.customersByKey[
        InMemoryRetailStore._customerKey(merchantId, customerId)];
  }

  @override
  Future<List<Customer>> getAll(MerchantId merchantId) async {
    final customers = <Customer>[];
    for (final key in _store._state.customerOrder) {
      final customer = _store._state.customersByKey[key];
      if (customer != null && customer.merchantId == merchantId) {
        customers.add(customer);
      }
    }
    return List<Customer>.unmodifiable(customers);
  }

  @override
  Future<void> update(Customer customer) async {
    _store._publish((current) {
      final existing = InMemoryRetailStore._requireOwnedCustomer(
        current,
        customer.merchantId,
        customer.id,
      );
      CustomerRepository.requireUniquePhone(
        customer,
        current.customersByKey.values,
      );
      final key =
          InMemoryRetailStore._customerKey(existing.merchantId, existing.id);
      final customersByKey = Map<String, Customer>.from(current.customersByKey);
      customersByKey[key] = customer;
      return RetailState(
        inventoryById: current.inventoryById,
        salesByKey: current.salesByKey,
        saleOrder: current.saleOrder,
        customersByKey: customersByKey,
        customerOrder: current.customerOrder,
        ledgerByKey: current.ledgerByKey,
        ledgerOrder: current.ledgerOrder,
      );
    });
  }

  @override
  Future<void> remove(MerchantId merchantId, CustomerId customerId) async {
    _store._publish((current) {
      InMemoryRetailStore._requireOwnedCustomer(
        current,
        merchantId,
        customerId,
      );
      final key = InMemoryRetailStore._customerKey(merchantId, customerId);
      final customersByKey = Map<String, Customer>.from(current.customersByKey);
      final customerOrder = List<String>.from(current.customerOrder);
      customersByKey.remove(key);
      customerOrder.remove(key);
      return RetailState(
        inventoryById: current.inventoryById,
        salesByKey: current.salesByKey,
        saleOrder: current.saleOrder,
        customersByKey: customersByKey,
        customerOrder: customerOrder,
        ledgerByKey: current.ledgerByKey,
        ledgerOrder: current.ledgerOrder,
      );
    });
  }

  @override
  Future<bool> exists(MerchantId merchantId, CustomerId customerId) async {
    return _store._state.customersByKey.containsKey(
      InMemoryRetailStore._customerKey(merchantId, customerId),
    );
  }
}

class _StoreLedgerView implements CustomerAccountLedgerRepository {
  _StoreLedgerView(this._store);

  final InMemoryRetailStore _store;

  static const int _maxMinorUnits = 9223372036854775807;
  static const int _minMinorUnits = -9223372036854775808;

  @override
  Future<void> append(CustomerAccountEntry entry) async {
    _store._publish((current) {
      final planned = InMemoryRetailStore._plannedLedgerAppend(current, entry);
      return RetailState(
        inventoryById: current.inventoryById,
        salesByKey: current.salesByKey,
        saleOrder: current.saleOrder,
        customersByKey: current.customersByKey,
        customerOrder: current.customerOrder,
        ledgerByKey: planned.byKey,
        ledgerOrder: planned.order,
      );
    });
  }

  @override
  Future<CustomerAccountEntry?> getById(
    MerchantId merchantId,
    CustomerAccountEntryId entryId,
  ) async {
    return _store._state
        .ledgerByKey[InMemoryRetailStore._ledgerKey(merchantId, entryId)];
  }

  @override
  Future<List<CustomerAccountEntry>> getEntries(
    MerchantId merchantId,
    CustomerId customerId,
  ) async {
    InMemoryRetailStore._requireCustomer(
      _store._state,
      merchantId,
      customerId,
    );
    return List<CustomerAccountEntry>.unmodifiable(
      InMemoryRetailStore._ledgerEntriesFor(
        _store._state,
        merchantId,
        customerId,
      ),
    );
  }

  @override
  Future<CustomerAccountBalance> getBalance(
    MerchantId merchantId,
    CustomerId customerId,
    CurrencyCode currency,
  ) async {
    InMemoryRetailStore._requireCustomer(
      _store._state,
      merchantId,
      customerId,
    );
    final entries = InMemoryRetailStore._ledgerEntriesFor(
      _store._state,
      merchantId,
      customerId,
      currency: currency,
    );
    var balance = 0;
    for (final entry in entries) {
      final delta = entry.type.decreasesDebt
          ? -entry.amount.minorUnits
          : entry.amount.minorUnits;
      if (_wouldOverflow(balance, delta)) {
        throw LedgerBalanceOverflowException(
          merchantId: merchantId,
          customerId: customerId,
          currency: currency,
        );
      }
      balance += delta;
    }
    return CustomerAccountBalance(
      currency: currency,
      balanceMinorUnits: balance,
    );
  }

  static bool _wouldOverflow(int balance, int delta) {
    if (delta > 0) {
      return balance > _maxMinorUnits - delta;
    }
    if (delta < 0) {
      return balance < _minMinorUnits - delta;
    }
    return false;
  }
}
