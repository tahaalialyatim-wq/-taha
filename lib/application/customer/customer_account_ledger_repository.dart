import '../../domain/customer/customer_account_balance.dart';
import '../../domain/customer/customer_account_entry.dart';
import '../../domain/customer/customer_account_entry_id.dart';
import '../../domain/customer/customer_id.dart';
import '../../domain/merchant/merchant_id.dart';
import '../../domain/money/currency_code.dart';

/// Merchant-scoped append-only customer account ledger.
///
/// Entry identity is [MerchantId] + [CustomerAccountEntryId]. Duplicate
/// identities for one merchant are rejected; the same entry id may exist for
/// different merchants. There is no update or remove.
///
/// All operations require the customer to exist for the merchant. A missing
/// customer throws [CustomerNotFoundException]; a zero balance is never
/// invented for a customer that does not exist. An existing customer with no
/// entries has an empty snapshot and a zero balance in the requested currency.
///
/// Payments that exceed recorded debt are accepted. The resulting negative
/// balance is a customer credit; there is no payment allocation or refund
/// workflow. At most one [CustomerAccountEntryType.openingBalance] may exist
/// per merchant, customer and currency, and it must be the first entry in
/// that scope. An account may start with a credit or payment instead.
/// Further debt uses [CustomerAccountEntryType.credit]. Entries in another
/// currency are independent and do not affect this rule.
abstract class CustomerAccountLedgerRepository {
  /// Appends [entry]. Rejects duplicate merchant-scoped identity, a second
  /// [CustomerAccountEntryType.openingBalance] for the same merchant,
  /// customer and currency, and an opening balance that is not the first
  /// entry in that scope.
  Future<void> append(CustomerAccountEntry entry);

  /// Returns the entry with [entryId] owned by [merchantId], or `null`.
  Future<CustomerAccountEntry?> getById(
    MerchantId merchantId,
    CustomerAccountEntryId entryId,
  );

  /// Returns an unmodifiable snapshot of entries for [merchantId] and
  /// [customerId] in append order.
  Future<List<CustomerAccountEntry>> getEntries(
    MerchantId merchantId,
    CustomerId customerId,
  );

  /// Returns the integer minor-unit balance for [currency].
  ///
  /// Positive means the customer owes the merchant. Only entries in
  /// [currency] are included; other currencies are independent.
  Future<CustomerAccountBalance> getBalance(
    MerchantId merchantId,
    CustomerId customerId,
    CurrencyCode currency,
  );
}
