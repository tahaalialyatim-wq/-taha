import '../../domain/merchant/merchant_id.dart';
import '../../domain/money/currency_code.dart';
import '../../domain/sale/sale_id.dart';
import 'sale_command_line.dart';

/// Input for completing a merchant sale.
class CompleteSaleCommand {
  CompleteSaleCommand({
    required this.saleId,
    required this.merchantId,
    required this.currency,
    required List<SaleCommandLine> lines,
  }) : lines = List<SaleCommandLine>.unmodifiable(_validate(lines));

  final SaleId saleId;
  final MerchantId merchantId;
  final CurrencyCode currency;
  final List<SaleCommandLine> lines;

  static List<SaleCommandLine> _validate(List<SaleCommandLine> lines) {
    if (lines.isEmpty) {
      throw ArgumentError.value(
        lines,
        'lines',
        'Sale command must have at least one line',
      );
    }
    final seen = <String>{};
    for (final line in lines) {
      if (!seen.add(line.productId.value)) {
        throw ArgumentError.value(
          line.productId.value,
          'lines',
          'Duplicate ProductId is not allowed',
        );
      }
    }
    return List<SaleCommandLine>.from(lines);
  }
}
