import '../../domain/merchant/merchant_id.dart';
import '../../domain/sale/sale_id.dart';

/// Thrown when a merchant already owns a sale with the same [SaleId].
class DuplicateSaleException implements Exception {
  const DuplicateSaleException({
    required this.merchantId,
    required this.saleId,
  });

  final MerchantId merchantId;
  final SaleId saleId;

  @override
  String toString() => 'DuplicateSaleException(merchant: ${merchantId.value}, '
      'sale: ${saleId.value})';
}
