import 'package:awtad_retail/awtad_retail.dart';
import 'package:sqlite3/sqlite3.dart';

import 'database_service.dart';

class SqliteLedgerRepository implements CustomerAccountLedgerRepository {
  SqliteLedgerRepository(this._database, {required this.customers});

  final DatabaseService _database;
  final CustomerRepository customers;
  Database get _db => _database.database;

  static const int _maxMinorUnits = 9223372036854775807;
  static const int _minMinorUnits = -9223372036854775808;

  @override
  Future<void> append(CustomerAccountEntry entry) async {
    await _requireCustomer(entry.merchantId, entry.customerId);
    if (await getById(entry.merchantId, entry.id) != null) {
      throw DuplicateCustomerAccountEntryException(
        merchantId: entry.merchantId,
        entryId: entry.id,
      );
    }
    final existing = await _entriesFor(
      entry.merchantId,
      entry.customerId,
      currency: entry.currency,
    );
    if (entry.type == CustomerAccountEntryType.openingBalance) {
      if (existing.any(
        (current) => current.type == CustomerAccountEntryType.openingBalance,
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
    _db.execute(
      '''
INSERT INTO ledger_entries (
  merchant_id, entry_id, customer_id, currency, amount_minor,
  entry_type, occurred_at, reference
) VALUES (?, ?, ?, ?, ?, ?, ?, ?);
''',
      [
        entry.merchantId.value,
        entry.id.value,
        entry.customerId.value,
        entry.currency.value,
        entry.amount.minorUnits,
        entry.type.value,
        entry.occurredAt.toIso8601String(),
        entry.reference,
      ],
    );
  }

  @override
  Future<CustomerAccountEntry?> getById(
    MerchantId merchantId,
    CustomerAccountEntryId entryId,
  ) async {
    final rows = _db.select(
      'SELECT * FROM ledger_entries WHERE merchant_id = ? AND entry_id = ?;',
      [merchantId.value, entryId.value],
    );
    if (rows.isEmpty) {
      return null;
    }
    return _fromRow(rows.first);
  }

  @override
  Future<List<CustomerAccountEntry>> getEntries(
    MerchantId merchantId,
    CustomerId customerId,
  ) async {
    await _requireCustomer(merchantId, customerId);
    return List<CustomerAccountEntry>.unmodifiable(
      await _entriesFor(merchantId, customerId),
    );
  }

  @override
  Future<CustomerAccountBalance> getBalance(
    MerchantId merchantId,
    CustomerId customerId,
    CurrencyCode currency,
  ) async {
    await _requireCustomer(merchantId, customerId);
    final entries = await _entriesFor(
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

  Future<void> _requireCustomer(
    MerchantId merchantId,
    CustomerId customerId,
  ) async {
    if (!await customers.exists(merchantId, customerId)) {
      throw CustomerNotFoundException(
        merchantId: merchantId,
        customerId: customerId,
      );
    }
  }

  Future<List<CustomerAccountEntry>> _entriesFor(
    MerchantId merchantId,
    CustomerId customerId, {
    CurrencyCode? currency,
  }) async {
    final rows = currency == null
        ? _db.select(
            '''
SELECT * FROM ledger_entries
WHERE merchant_id = ? AND customer_id = ?
ORDER BY rowid;
''',
            [merchantId.value, customerId.value],
          )
        : _db.select(
            '''
SELECT * FROM ledger_entries
WHERE merchant_id = ? AND customer_id = ? AND currency = ?
ORDER BY rowid;
''',
            [merchantId.value, customerId.value, currency.value],
          );
    return rows.map(_fromRow).toList(growable: false);
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

  static CustomerAccountEntry _fromRow(Row row) {
    return CustomerAccountEntry(
      id: CustomerAccountEntryId(row['entry_id'] as String),
      merchantId: MerchantId(row['merchant_id'] as String),
      customerId: CustomerId(row['customer_id'] as String),
      currency: CurrencyCode.parse(row['currency'] as String),
      amount: Money(
        currency: CurrencyCode.parse(row['currency'] as String),
        minorUnits: row['amount_minor'] as int,
      ),
      type: _type(row['entry_type'] as String),
      occurredAt: DateTime.parse(row['occurred_at'] as String),
      reference: row['reference'] as String?,
    );
  }

  static CustomerAccountEntryType _type(String value) {
    for (final type in CustomerAccountEntryType.values) {
      if (type.value == value) {
        return type;
      }
    }
    throw ArgumentError.value(value, 'entry_type');
  }
}
