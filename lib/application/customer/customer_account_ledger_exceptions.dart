import '../../domain/customer/customer_account_entry_id.dart';
import '../../domain/customer/customer_id.dart';
import '../../domain/merchant/merchant_id.dart';
import '../../domain/money/currency_code.dart';

/// Thrown when a merchant already owns a ledger entry with the same identity.
class DuplicateCustomerAccountEntryException implements Exception {
  const DuplicateCustomerAccountEntryException({
    required this.merchantId,
    required this.entryId,
  });

  final MerchantId merchantId;
  final CustomerAccountEntryId entryId;

  @override
  String toString() =>
      'DuplicateCustomerAccountEntryException(merchant: ${merchantId.value}, '
      'entry: ${entryId.value})';
}

/// Thrown when a second opening-balance entry is appended for one customer.
class DuplicateOpeningBalanceException implements Exception {
  const DuplicateOpeningBalanceException({
    required this.merchantId,
    required this.customerId,
  });

  final MerchantId merchantId;
  final CustomerId customerId;

  @override
  String toString() =>
      'DuplicateOpeningBalanceException(merchant: ${merchantId.value}, '
      'customer: ${customerId.value})';
}

/// Thrown when [CustomerAccountEntryType.openingBalance] is not the first
/// entry for a merchant, customer and currency.
class OpeningBalanceNotFirstException implements Exception {
  const OpeningBalanceNotFirstException({
    required this.merchantId,
    required this.customerId,
    required this.currency,
  });

  final MerchantId merchantId;
  final CustomerId customerId;
  final CurrencyCode currency;

  @override
  String toString() =>
      'OpeningBalanceNotFirstException(merchant: ${merchantId.value}, '
      'customer: ${customerId.value}, currency: ${currency.value})';
}

/// Thrown when a ledger operation mixes or queries inconsistent currencies.
class InconsistentCurrencyException implements Exception {
  const InconsistentCurrencyException({
    required this.merchantId,
    required this.customerId,
    required this.expected,
    required this.actual,
  });

  final MerchantId merchantId;
  final CustomerId customerId;
  final CurrencyCode expected;
  final CurrencyCode actual;

  @override
  String toString() =>
      'InconsistentCurrencyException(merchant: ${merchantId.value}, '
      'customer: ${customerId.value}, expected: ${expected.value}, '
      'actual: ${actual.value})';
}

/// Thrown when a balance calculation would exceed signed 64-bit minor units.
class LedgerBalanceOverflowException implements Exception {
  const LedgerBalanceOverflowException({
    required this.merchantId,
    required this.customerId,
    required this.currency,
  });

  final MerchantId merchantId;
  final CustomerId customerId;
  final CurrencyCode currency;

  @override
  String toString() =>
      'LedgerBalanceOverflowException(merchant: ${merchantId.value}, '
      'customer: ${customerId.value}, currency: ${currency.value})';
}
