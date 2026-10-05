import 'currency_code.dart';

/// A monetary amount expressed in integer minor units of an explicit currency.
///
/// There is no double representation, no default currency, no conversion and no
/// formatting. Equality includes both the amount and the currency.
class Money {
  const Money({required this.currency, required this.minorUnits});

  final CurrencyCode currency;

  /// Amount in the currency's minor unit (for example fils or halala).
  final int minorUnits;

  @override
  bool operator ==(Object other) =>
      other is Money &&
      other.currency == currency &&
      other.minorUnits == minorUnits;

  @override
  int get hashCode => Object.hash(currency, minorUnits);

  @override
  String toString() => 'Money($minorUnits ${currency.value})';
}
