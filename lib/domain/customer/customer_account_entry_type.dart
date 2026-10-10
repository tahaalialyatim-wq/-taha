/// Kind of a [CustomerAccountEntry] on a customer account ledger.
///
/// [openingBalance] is the single initial outstanding customer debt for one
/// merchant, customer and currency, and must be the first entry in that
/// scope when present. An account may start with [credit] instead.
/// Additional amounts owed use [credit]. [payment] reduces outstanding
/// debt and may overpay, leaving a customer credit (negative balance).
/// There is no adjustment, refund or allocation type.
class CustomerAccountEntryType {
  const CustomerAccountEntryType._(this.value);

  final String value;

  static const CustomerAccountEntryType openingBalance =
      CustomerAccountEntryType._('openingBalance');
  static const CustomerAccountEntryType credit =
      CustomerAccountEntryType._('credit');
  static const CustomerAccountEntryType payment =
      CustomerAccountEntryType._('payment');

  /// Supported values, in deterministic order.
  static const List<CustomerAccountEntryType> values =
      <CustomerAccountEntryType>[
    openingBalance,
    credit,
    payment,
  ];

  /// Whether this type increases the amount the customer owes.
  bool get increasesDebt => this == openingBalance || this == credit;

  /// Whether this type decreases the amount the customer owes.
  bool get decreasesDebt => this == payment;

  @override
  bool operator ==(Object other) =>
      other is CustomerAccountEntryType && other.value == value;

  @override
  int get hashCode => value.hashCode;

  @override
  String toString() => 'CustomerAccountEntryType($value)';
}
