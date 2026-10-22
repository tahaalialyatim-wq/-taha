import 'package:awtad_retail/awtad_retail.dart';
import 'package:sqlite3/sqlite3.dart';

import 'database_service.dart';

class SqliteSaleRepository implements SaleRepository {
  SqliteSaleRepository(this._database);

  final DatabaseService _database;
  Database get _db => _database.database;

  @override
  Future<void> add(Sale sale) async {
    if (await getById(sale.merchantId, sale.id) != null) {
      throw DuplicateSaleException(
        merchantId: sale.merchantId,
        saleId: sale.id,
      );
    }
    _insertSale(sale);
  }

  @override
  Future<Sale?> getById(MerchantId merchantId, SaleId saleId) async {
    final rows = _db.select(
      'SELECT * FROM sales WHERE merchant_id = ? AND sale_id = ?;',
      [merchantId.value, saleId.value],
    );
    if (rows.isEmpty) {
      return null;
    }
    return _saleFrom(rows.first);
  }

  @override
  Future<List<Sale>> getAll(MerchantId merchantId) async {
    final rows = _db.select(
      'SELECT * FROM sales WHERE merchant_id = ? ORDER BY rowid;',
      [merchantId.value],
    );
    return List<Sale>.unmodifiable(
      rows.map(_saleFrom).toList(growable: false),
    );
  }

  void _insertSale(Sale sale) {
    _db.execute(
      '''
INSERT INTO sales (merchant_id, sale_id, currency, customer_id)
VALUES (?, ?, ?, ?);
''',
      [
        sale.merchantId.value,
        sale.id.value,
        sale.currency.value,
        sale.customerId?.value,
      ],
    );
    for (var i = 0; i < sale.lines.length; i++) {
      final line = sale.lines[i];
      _db.execute(
        '''
INSERT INTO sale_lines (
  merchant_id, sale_id, line_index, product_id,
  quantity_milli, unit_currency, unit_minor,
  unit_cost_currency, unit_cost_minor
) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?);
''',
        [
          sale.merchantId.value,
          sale.id.value,
          i,
          line.productId.value,
          line.quantity.milliUnits,
          line.unitSellingPrice.currency.value,
          line.unitSellingPrice.minorUnits,
          line.unitPurchaseCost?.currency.value,
          line.unitPurchaseCost?.minorUnits,
        ],
      );
    }
  }

  /// Reads a persisted historical cost snapshot.
  ///
  /// Legacy rows have `NULL` cost columns and therefore load as unknown.
  static Money? _costFrom(Row row) {
    final currency = row['unit_cost_currency'] as String?;
    final minorUnits = row['unit_cost_minor'] as int?;
    if (currency == null || minorUnits == null) {
      return null;
    }
    return Money(
      currency: CurrencyCode.parse(currency),
      minorUnits: minorUnits,
    );
  }

  Sale _saleFrom(Row row) {
    final merchantId = MerchantId(row['merchant_id'] as String);
    final saleId = SaleId(row['sale_id'] as String);
    final lineRows = _db.select(
      '''
SELECT * FROM sale_lines
WHERE merchant_id = ? AND sale_id = ?
ORDER BY line_index;
''',
      [merchantId.value, saleId.value],
    );
    final customer = row['customer_id'] as String?;
    return Sale(
      id: saleId,
      merchantId: merchantId,
      currency: CurrencyCode.parse(row['currency'] as String),
      customerId: customer == null ? null : CustomerId(customer),
      lines: lineRows
          .map(
            (line) => SaleLine(
              productId: ProductId(line['product_id'] as String),
              quantity: Quantity.fromMilliUnits(line['quantity_milli'] as int),
              unitSellingPrice: Money(
                currency: CurrencyCode.parse(line['unit_currency'] as String),
                minorUnits: line['unit_minor'] as int,
              ),
              unitPurchaseCost: _costFrom(line),
            ),
          )
          .toList(growable: false),
    );
  }
}
