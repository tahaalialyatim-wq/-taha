import '../../domain/customer/customer_account_entry_id.dart';
import '../../domain/customer/customer_id.dart';
import '../../domain/merchant/merchant_id.dart';
import '../../domain/money/currency_code.dart';
import '../../domain/money/money.dart';

/// Input for recording an explicit customer payment.
class RecordCustomerPaymentCommand {
  RecordCustomerPaymentCommand({
    required this.entryId,
    required this.merchantId,
    required this.customerId,
    required this.currency,
    required this.amount,
    required this.occurredAt,
    this.reference,
  });

  final CustomerAccountEntryId entryId;
  final MerchantId merchantId;
  final CustomerId customerId;
  final CurrencyCode currency;
  final Money amount;
  final DateTime occurredAt;
  final String? reference;
}
