import '../../domain/customer/customer_account_entry.dart';
import '../../domain/customer/customer_account_entry_type.dart';
import '../runtime/retail_store.dart';
import 'customer_account_ledger_repository.dart';
import 'record_opening_balance_command.dart';

/// Records the first outstanding customer debt for one merchant, customer
/// and currency through [CustomerAccountLedgerRepository].
class RecordOpeningBalanceService {
  RecordOpeningBalanceService({required this.ledger});

  factory RecordOpeningBalanceService.forStore(RetailStore store) {
    return RecordOpeningBalanceService(ledger: store.ledger);
  }

  final CustomerAccountLedgerRepository ledger;

  Future<CustomerAccountEntry> record(
    RecordOpeningBalanceCommand command,
  ) async {
    if (command.amount.currency != command.currency) {
      throw ArgumentError.value(
        command.amount.currency,
        'amount',
        'Opening balance amount currency must equal command currency',
      );
    }
    final entry = CustomerAccountEntry(
      id: command.entryId,
      merchantId: command.merchantId,
      customerId: command.customerId,
      currency: command.currency,
      amount: command.amount,
      type: CustomerAccountEntryType.openingBalance,
      occurredAt: command.occurredAt,
      reference: command.reference,
    );
    await ledger.append(entry);
    return entry;
  }
}
