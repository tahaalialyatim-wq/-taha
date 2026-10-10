import '../../domain/customer/customer_account_balance.dart';
import '../../domain/customer/customer_account_entry.dart';
import '../../domain/customer/customer_account_entry_id.dart';
import '../../domain/customer/customer_account_entry_type.dart';
import '../../domain/customer/customer_id.dart';
import '../../domain/merchant/merchant_id.dart';
import '../../domain/money/currency_code.dart';
import 'customer_account_ledger_exceptions.dart';
import 'customer_account_ledger_repository.dart';
import 'customer_exceptions.dart';
import 'customer_repository.dart';

/// In-memory [CustomerAccountLedgerRepository].
///
/// There is no persistence. Storage is append-only and merchant-scoped.
/// Customer ownership is checked through [CustomerRepository]. Payments that
/// exceed recorded debt are stored as-is; the balance may become negative.
/// [CustomerAccountEntryType.openingBalance] must be the first entry for
/// the merchant, customer and currency, and at most one is allowed.
class InMemoryCustomerAccountLedgerRepository
    implements CustomerAccountLedgerRepository {
  InMemoryCustomerAccountLedgerRepository({required this.customers});

  final CustomerRepository customers;

  static const int _maxMinorUnits = 9223372036854775807;
  static const int _minMinorUnits = -9223372036854775808;

  final Map<String, CustomerAccountEntry> _byKey =
      <String, CustomerAccountEntry>{};
  final List<String> _order = <String>[];

  @override
  Future<void> append(CustomerAccountEntry entry) async {
    await _requireCustomer(entry.merchantId, entry.customerId);
    final key = _key(entry.merchantId, entry.id);
    if (_byKey.containsKey(key)) {
      throw DuplicateCustomerAccountEntryException(
        merchantId: entry.merchantId,
        entryId: entry.id,
      );
    }
    final existing = _entriesFor(
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
    _byKey[key] = entry;
    _order.add(key);
  }

  @override
  Future<CustomerAccountEntry?> getById(
    MerchantId merchantId,
    CustomerAccountEntryId entryId,
  ) async {
    return _byKey[_key(merchantId, entryId)];
  }

  @override
  Future<List<CustomerAccountEntry>> getEntries(
    MerchantId merchantId,
    CustomerId customerId,
  ) async {
    await _requireCustomer(merchantId, customerId);
    return List<CustomerAccountEntry>.unmodifiable(
      _entriesFor(merchantId, customerId),
    );
  }

  @override
  Future<CustomerAccountBalance> getBalance(
    MerchantId merchantId,
    CustomerId customerId,
    CurrencyCode currency,
  ) async {
    await _requireCustomer(merchantId, customerId);
    final entries = _entriesFor(merchantId, customerId, currency: currency);
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

  List<CustomerAccountEntry> _entriesFor(
    MerchantId merchantId,
    CustomerId customerId, {
    CurrencyCode? currency,
  }) {
    final entries = <CustomerAccountEntry>[];
    for (final key in _order) {
      final entry = _byKey[key];
      if (entry != null &&
          entry.merchantId == merchantId &&
          entry.customerId == customerId &&
          (currency == null || entry.currency == currency)) {
        entries.add(entry);
      }
    }
    return entries;
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

  static String _key(MerchantId merchantId, CustomerAccountEntryId entryId) =>
      '${merchantId.value}:${entryId.value}';
}
