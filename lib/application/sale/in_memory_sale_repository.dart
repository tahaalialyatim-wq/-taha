import '../../domain/merchant/merchant_id.dart';
import '../../domain/sale/sale.dart';
import '../../domain/sale/sale_id.dart';
import 'sale_exceptions.dart';
import 'sale_repository.dart';

/// In-memory [SaleRepository].
///
/// There is no persistence. Storage is merchant-scoped: identity is
/// [MerchantId] + [SaleId].
class InMemorySaleRepository implements SaleRepository {
  final Map<String, Sale> _byKey = <String, Sale>{};
  final List<String> _order = <String>[];

  @override
  Future<void> add(Sale sale) async {
    final key = _key(sale.merchantId, sale.id);
    if (_byKey.containsKey(key)) {
      throw DuplicateSaleException(
        merchantId: sale.merchantId,
        saleId: sale.id,
      );
    }
    _byKey[key] = sale;
    _order.add(key);
  }

  @override
  Future<Sale?> getById(MerchantId merchantId, SaleId saleId) async {
    return _byKey[_key(merchantId, saleId)];
  }

  @override
  Future<List<Sale>> getAll(MerchantId merchantId) async {
    final sales = <Sale>[];
    for (final key in _order) {
      final sale = _byKey[key];
      if (sale != null && sale.merchantId == merchantId) {
        sales.add(sale);
      }
    }
    return List<Sale>.unmodifiable(sales);
  }

  static String _key(MerchantId merchantId, SaleId saleId) =>
      '${merchantId.value}:${saleId.value}';
}
