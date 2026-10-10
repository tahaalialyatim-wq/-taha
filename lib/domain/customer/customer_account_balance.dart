import '../money/currency_code.dart';

/// Outstanding customer account balance in integer minor units.
///
/// Positive [balanceMinorUnits] means the customer owes the merchant.
/// Zero means the account is settled. Negative means the customer has a
/// credit in their favor, including when payments exceed recorded debt.
/// There is no double representation and no currency conversion. Currency
/// is always explicit.
class CustomerAccountBalance {
  const CustomerAccountBalance({
    required this.currency,
    required this.balanceMinorUnits,
  });

  final CurrencyCode currency;
  final int balanceMinorUnits;

  @override
  bool operator ==(Object other) =>
      other is CustomerAccountBalance &&
      other.currency == currency &&
      other.balanceMinorUnits == balanceMinorUnits;

  @override
  int get hashCode => Object.hash(currency, balanceMinorUnits);

  @override
  String toString() =>
      'CustomerAccountBalance($balanceMinorUnits ${currency.value})';
}
