import '../customer/customer_id.dart';
import '../merchant/merchant_id.dart';
import '../money/currency_code.dart';
import '../money/money.dart';
import 'sale_id.dart';
import 'sale_line.dart';

/// A completed merchant-owned sale.
///
/// Equality and [hashCode] are based on [id] only. Lines are catalog-free:
/// they reference [ProductId] and transactional money/quantity only.
/// [customerId] is optional: cash sales omit it; credit sales require it.
class Sale {
  Sale({
    required this.id,
    required this.merchantId,
    required this.currency,
    required List<SaleLine> lines,
    this.customerId,
  }) : lines = List<SaleLine>.unmodifiable(_validate(currency, lines));

  final SaleId id;
  final MerchantId merchantId;
  final CurrencyCode currency;
  final List<SaleLine> lines;
  final CustomerId? customerId;

  /// Sum of [SaleLine.lineTotal] in integer minor units.
  ///
  /// There is no stored total. Throws [ArgumentError] if the sum overflows
  /// signed 64-bit minor units.
  Money get total {
    var minorUnits = 0;
    for (final line in lines) {
      final addend = line.lineTotal.minorUnits;
      if (addend > 0 && minorUnits > 9223372036854775807 - addend) {
        throw ArgumentError.value(
          lines,
          'lines',
          'Sale total overflows signed 64-bit minor units',
        );
      }
      if (addend < 0 && minorUnits < -9223372036854775808 - addend) {
        throw ArgumentError.value(
          lines,
          'lines',
          'Sale total overflows signed 64-bit minor units',
        );
      }
      minorUnits += addend;
    }
    return Money(currency: currency, minorUnits: minorUnits);
  }

  @override
  bool operator ==(Object other) => other is Sale && other.id == id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'Sale($id)';

  static List<SaleLine> _validate(CurrencyCode currency, List<SaleLine> lines) {
    if (lines.isEmpty) {
      throw ArgumentError.value(
        lines,
        'lines',
        'Sale must have at least one line',
      );
    }
    for (final line in lines) {
      if (line.unitSellingPrice.currency != currency) {
        throw ArgumentError.value(
          line.unitSellingPrice.currency,
          'lines',
          'Sale line currency must equal Sale.currency',
        );
      }
    }
    return List<SaleLine>.from(lines);
  }
}
