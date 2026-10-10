import '../merchant/merchant_id.dart';
import '../money/currency_code.dart';
import '../money/money.dart';
import 'customer_account_entry_id.dart';
import 'customer_account_entry_type.dart';
import 'customer_id.dart';

/// One immutable append-only customer account ledger entry.
///
/// Equality and [hashCode] are based on [id] only. There is no running
/// balance, and no embedded Customer, Sale, Invoice or Payment object.
class CustomerAccountEntry {
  CustomerAccountEntry({
    required this.id,
    required this.merchantId,
    required this.customerId,
    required this.currency,
    required Money amount,
    required this.type,
    required this.occurredAt,
    String? reference,
  })  : amount = _validateAmount(currency, amount),
        reference = _optional(reference);

  final CustomerAccountEntryId id;
  final MerchantId merchantId;
  final CustomerId customerId;
  final CurrencyCode currency;
  final Money amount;
  final CustomerAccountEntryType type;
  final DateTime occurredAt;
  final String? reference;

  static Money _validateAmount(CurrencyCode currency, Money amount) {
    if (amount.minorUnits <= 0) {
      throw ArgumentError.value(
        amount.minorUnits,
        'amount',
        'CustomerAccountEntry amount must be greater than zero',
      );
    }
    if (amount.currency != currency) {
      throw ArgumentError.value(
        amount.currency,
        'amount',
        'CustomerAccountEntry amount currency must equal entry currency',
      );
    }
    return amount;
  }

  static String? _optional(String? value) {
    if (value == null) {
      return null;
    }
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  @override
  bool operator ==(Object other) =>
      other is CustomerAccountEntry && other.id == id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'CustomerAccountEntry($id)';
}
