import 'package:awtad_retail/awtad_retail.dart';
import 'package:sqlite3/sqlite3.dart';

import 'database_service.dart';

class SqliteInventoryRepository implements MerchantInventoryRepository {
  SqliteInventoryRepository(this._database);

  final DatabaseService _database;

  Database get _db => _database.database;

  @override
  Future<MerchantInventoryItem?> getById(
    MerchantId merchantId,
    InventoryItemId id,
  ) async {
    final rows = _db.select(
      'SELECT * FROM inventory_items WHERE merchant_id = ? AND item_id = ?;',
      [merchantId.value, id.value],
    );
    if (rows.isEmpty) {
      return null;
    }
    return _fromRow(rows.first);
  }

  @override
  Future<MerchantInventoryItem?> getByProduct(
    MerchantId merchantId,
    ProductId productId,
  ) async {
    final rows = _db.select(
      '''
SELECT * FROM inventory_items
WHERE merchant_id = ? AND product_id = ?;
''',
      [merchantId.value, productId.value],
    );
    if (rows.isEmpty) {
      return null;
    }
    return _fromRow(rows.first);
  }

  @override
  Future<bool> exists(MerchantId merchantId, InventoryItemId id) async {
    return (await getById(merchantId, id)) != null;
  }

  @override
  Future<List<MerchantInventoryItem>> getAll(MerchantId merchantId) async {
    final rows = _db.select(
      'SELECT * FROM inventory_items WHERE merchant_id = ? ORDER BY product_id;',
      [merchantId.value],
    );
    return List<MerchantInventoryItem>.unmodifiable(
      rows.map(_fromRow).toList(growable: false),
    );
  }

  @override
  Future<MerchantInventoryItem> add(MerchantInventoryItem item) async {
    final existing = await getByProduct(item.merchantId, item.productId);
    if (existing != null || await exists(item.merchantId, item.id)) {
      throw DuplicateInventoryItemException(
        merchantId: item.merchantId,
        productId: item.productId,
      );
    }
    _insert(item);
    return item;
  }

  @override
  Future<MerchantInventoryItem> update(MerchantInventoryItem item) async {
    final existing = await _requireOwned(item.merchantId, item.id);
    if (existing.productId != item.productId) {
      final clash = await getByProduct(item.merchantId, item.productId);
      if (clash != null && clash.id != item.id) {
        throw DuplicateInventoryItemException(
          merchantId: item.merchantId,
          productId: item.productId,
        );
      }
    }
    _db.execute(
      '''
UPDATE inventory_items SET
  product_id = ?,
  quantity_milli = ?,
  selling_currency = ?,
  selling_minor = ?,
  purchase_currency = ?,
  purchase_minor = ?,
  minimum_stock_milli = ?
WHERE merchant_id = ? AND item_id = ?;
''',
      [
        item.productId.value,
        item.quantity.milliUnits,
        item.sellingPrice?.currency.value,
        item.sellingPrice?.minorUnits,
        item.purchasePrice?.currency.value,
        item.purchasePrice?.minorUnits,
        item.minimumStock?.milliUnits,
        item.merchantId.value,
        item.id.value,
      ],
    );
    return item;
  }

  @override
  Future<MerchantInventoryItem> updateQuantity(
    MerchantId merchantId,
    InventoryItemId id,
    Quantity quantity,
  ) async {
    final existing = await _requireOwned(merchantId, id);
    final updated = existing.copyWith(quantity: quantity);
    await update(updated);
    return updated;
  }

  @override
  Future<void> decrementQuantity(
    MerchantId merchantId,
    InventoryItemId inventoryItemId,
    Quantity amount,
  ) {
    return decrementQuantities(
      merchantId,
      <InventoryDecrement>[
        InventoryDecrement(
          inventoryItemId: inventoryItemId,
          amount: amount,
        ),
      ],
    );
  }

  @override
  Future<void> decrementQuantities(
    MerchantId merchantId,
    List<InventoryDecrement> decrements,
  ) async {
    if (decrements.isEmpty) {
      throw ArgumentError.value(
        decrements,
        'decrements',
        'Decrement batch must not be empty',
      );
    }
    _db.execute('SAVEPOINT decrement_batch;');
    try {
      final remainingById = <String, Quantity>{};
      for (final decrement in decrements) {
        if (decrement.amount.milliUnits <= 0) {
          throw ArgumentError.value(
            decrement.amount.milliUnits,
            'amount',
            'Decrement amount must be greater than zero',
          );
        }
        final existing = await getById(merchantId, decrement.inventoryItemId);
        if (existing == null) {
          throw InventoryItemNotFoundException(
            merchantId: merchantId,
            itemId: decrement.inventoryItemId,
          );
        }
        final previous = remainingById[existing.id.value] ?? existing.quantity;
        if (previous.milliUnits < decrement.amount.milliUnits) {
          throw InsufficientStockException(
            merchantId: merchantId,
            itemId: existing.id,
            available: previous,
            requested: decrement.amount,
          );
        }
        remainingById[existing.id.value] = Quantity.fromMilliUnits(
          previous.milliUnits - decrement.amount.milliUnits,
        );
      }
      for (final entry in remainingById.entries) {
        _db.execute(
          '''
UPDATE inventory_items SET quantity_milli = ?
WHERE merchant_id = ? AND item_id = ?;
''',
          [entry.value.milliUnits, merchantId.value, entry.key],
        );
      }
      _db.execute('RELEASE decrement_batch;');
    } catch (_) {
      _db.execute('ROLLBACK TO decrement_batch;');
      _db.execute('RELEASE decrement_batch;');
      rethrow;
    }
  }

  @override
  Future<bool> remove(MerchantId merchantId, InventoryItemId id) async {
    final existing = await getById(merchantId, id);
    if (existing == null) {
      final any = _db.select(
        'SELECT merchant_id FROM inventory_items WHERE item_id = ? LIMIT 1;',
        [id.value],
      );
      if (any.isNotEmpty) {
        throw MerchantMismatchException(
          expected: merchantId,
          actual: MerchantId(any.first['merchant_id'] as String),
        );
      }
      return false;
    }
    _db.execute(
      'DELETE FROM inventory_items WHERE merchant_id = ? AND item_id = ?;',
      [merchantId.value, id.value],
    );
    return true;
  }

  void _insert(MerchantInventoryItem item) {
    _db.execute(
      '''
INSERT INTO inventory_items (
  merchant_id, item_id, product_id, quantity_milli,
  selling_currency, selling_minor, purchase_currency, purchase_minor,
  minimum_stock_milli
) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?);
''',
      [
        item.merchantId.value,
        item.id.value,
        item.productId.value,
        item.quantity.milliUnits,
        item.sellingPrice?.currency.value,
        item.sellingPrice?.minorUnits,
        item.purchasePrice?.currency.value,
        item.purchasePrice?.minorUnits,
        item.minimumStock?.milliUnits,
      ],
    );
  }

  Future<MerchantInventoryItem> _requireOwned(
    MerchantId merchantId,
    InventoryItemId id,
  ) async {
    final item = await getById(merchantId, id);
    if (item != null) {
      return item;
    }
    final any = _db.select(
      'SELECT merchant_id FROM inventory_items WHERE item_id = ? LIMIT 1;',
      [id.value],
    );
    if (any.isEmpty) {
      throw InventoryItemNotFoundException(
        merchantId: merchantId,
        itemId: id,
      );
    }
    throw MerchantMismatchException(
      expected: merchantId,
      actual: MerchantId(any.first['merchant_id'] as String),
    );
  }

  static MerchantInventoryItem _fromRow(Row row) {
    Money? money(String currencyKey, String minorKey) {
      final currency = row[currencyKey] as String?;
      final minor = row[minorKey] as int?;
      if (currency == null || minor == null) {
        return null;
      }
      return Money(
        currency: CurrencyCode.parse(currency),
        minorUnits: minor,
      );
    }

    final minStock = row['minimum_stock_milli'] as int?;
    return MerchantInventoryItem(
      id: InventoryItemId(row['item_id'] as String),
      merchantId: MerchantId(row['merchant_id'] as String),
      productId: ProductId(row['product_id'] as String),
      quantity: Quantity.fromMilliUnits(row['quantity_milli'] as int),
      sellingPrice: money('selling_currency', 'selling_minor'),
      purchasePrice: money('purchase_currency', 'purchase_minor'),
      minimumStock: minStock == null ? null : Quantity.fromMilliUnits(minStock),
    );
  }
}
