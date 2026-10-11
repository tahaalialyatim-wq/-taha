import 'package:awtad_retail/awtad_retail.dart';
import 'package:sqlite3/sqlite3.dart';

import 'database_service.dart';

class SqliteCustomerRepository implements CustomerRepository {
  SqliteCustomerRepository(this._database);

  final DatabaseService _database;
  Database get _db => _database.database;

  @override
  Future<void> add(Customer customer) async {
    if (await exists(customer.merchantId, customer.id)) {
      throw DuplicateCustomerException(
        merchantId: customer.merchantId,
        customerId: customer.id,
      );
    }
    _db.execute(
      '''
INSERT INTO customers (merchant_id, customer_id, name, phone, notes)
VALUES (?, ?, ?, ?, ?);
''',
      [
        customer.merchantId.value,
        customer.id.value,
        customer.name,
        customer.phone,
        customer.notes,
      ],
    );
  }

  @override
  Future<Customer?> getById(
    MerchantId merchantId,
    CustomerId customerId,
  ) async {
    final rows = _db.select(
      'SELECT * FROM customers WHERE merchant_id = ? AND customer_id = ?;',
      [merchantId.value, customerId.value],
    );
    if (rows.isEmpty) {
      return null;
    }
    return _fromRow(rows.first);
  }

  @override
  Future<List<Customer>> getAll(MerchantId merchantId) async {
    final rows = _db.select(
      'SELECT * FROM customers WHERE merchant_id = ? ORDER BY name;',
      [merchantId.value],
    );
    return List<Customer>.unmodifiable(
      rows.map(_fromRow).toList(growable: false),
    );
  }

  @override
  Future<void> update(Customer customer) async {
    await _requireOwned(customer.merchantId, customer.id);
    _db.execute(
      '''
UPDATE customers SET name = ?, phone = ?, notes = ?
WHERE merchant_id = ? AND customer_id = ?;
''',
      [
        customer.name,
        customer.phone,
        customer.notes,
        customer.merchantId.value,
        customer.id.value,
      ],
    );
  }

  @override
  Future<void> remove(MerchantId merchantId, CustomerId customerId) async {
    await _requireOwned(merchantId, customerId);
    _db.execute(
      'DELETE FROM customers WHERE merchant_id = ? AND customer_id = ?;',
      [merchantId.value, customerId.value],
    );
  }

  @override
  Future<bool> exists(MerchantId merchantId, CustomerId customerId) async {
    final rows = _db.select(
      '''
SELECT 1 FROM customers WHERE merchant_id = ? AND customer_id = ? LIMIT 1;
''',
      [merchantId.value, customerId.value],
    );
    return rows.isNotEmpty;
  }

  Future<Customer> _requireOwned(
    MerchantId merchantId,
    CustomerId customerId,
  ) async {
    final owned = await getById(merchantId, customerId);
    if (owned != null) {
      return owned;
    }
    final any = _db.select(
      'SELECT merchant_id FROM customers WHERE customer_id = ? LIMIT 1;',
      [customerId.value],
    );
    if (any.isEmpty) {
      throw CustomerNotFoundException(
        merchantId: merchantId,
        customerId: customerId,
      );
    }
    throw MerchantMismatchException(
      expected: merchantId,
      actual: MerchantId(any.first['merchant_id'] as String),
    );
  }

  static Customer _fromRow(Row row) {
    return Customer(
      id: CustomerId(row['customer_id'] as String),
      merchantId: MerchantId(row['merchant_id'] as String),
      name: row['name'] as String,
      phone: row['phone'] as String?,
      notes: row['notes'] as String?,
    );
  }
}
