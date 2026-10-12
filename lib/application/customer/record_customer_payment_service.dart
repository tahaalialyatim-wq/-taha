import '../../domain/customer/customer_account_entry.dart';
import '../../domain/customer/customer_account_entry_type.dart';
import '../runtime/retail_store.dart';
import 'customer_account_ledger_repository.dart';
import 'record_customer_payment_command.dart';

/// Records an explicit customer payment through
/// [CustomerAccountLedgerRepository].
///
/// Overpayment is allowed and stored as a customer credit (negative
/// balance). This service always posts [CustomerAccountEntryType.payment]
/// and never an advance type.
class RecordCustomerPaymentService {
  RecordCustomerPaymentService({required this.ledger});

  factory RecordCustomerPaymentService.forStore(RetailStore store) {
    return RecordCustomerPaymentService(ledger: store.ledger);
  }

  final CustomerAccountLedgerRepository ledger;

  Future<CustomerAccountEntry> record(
    RecordCustomerPaymentCommand command,
  ) async {
    if (command.amount.currency != command.currency) {
      throw ArgumentError.value(
        command.amount.currency,
        'amount',
        'Payment amount currency must equal command currency',
      );
    }
    final entry = CustomerAccountEntry(
      id: command.entryId,
      merchantId: command.merchantId,
      customerId: command.customerId,
      currency: command.currency,
      amount: command.amount,
      type: CustomerAccountEntryType.payment,
      occurredAt: command.occurredAt,
      reference: command.reference,
    );
    await ledger.append(entry);
    return entry;
  }
}
