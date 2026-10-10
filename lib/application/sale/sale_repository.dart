import '../../domain/merchant/merchant_id.dart';
import '../../domain/sale/sale.dart';
import '../../domain/sale/sale_id.dart';

/// Merchant-scoped repository for completed [Sale] records.
///
/// Identity is [MerchantId] + [SaleId]. [getAll] returns an unmodifiable
/// snapshot. There is no update or delete in this MVP.
abstract class SaleRepository {
  /// Stores [sale]. Rejects duplicate [MerchantId] + [SaleId].
  Future<void> add(Sale sale);

  /// Returns the sale with [saleId] owned by [merchantId], or `null`.
  Future<Sale?> getById(MerchantId merchantId, SaleId saleId);

  /// Returns an unmodifiable snapshot of all sales owned by [merchantId].
  Future<List<Sale>> getAll(MerchantId merchantId);
}
