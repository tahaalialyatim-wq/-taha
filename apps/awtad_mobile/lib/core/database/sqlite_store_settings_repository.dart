import 'package:awtad_retail/awtad_retail.dart';
import 'package:sqlite3/sqlite3.dart';

import 'database_service.dart';

/// Persists the store-wide default currency for a merchant.
///
/// The default is a pre-fill value only: it never rewrites the currency stored
/// on existing inventory items, sales, sale lines or ledger entries.
class SqliteStoreSettingsRepository {
  SqliteStoreSettingsRepository(this._database);

  final DatabaseService _database;

  Database get _db => _database.database;

  /// Returns the persisted default currency, or `null` when none is set.
  Future<CurrencyCode?> readDefaultCurrency(MerchantId merchantId) async {
    final rows = _db.select(
      'SELECT default_currency FROM store_settings WHERE merchant_id = ?;',
      [merchantId.value],
    );
    if (rows.isEmpty) {
      return null;
    }
    final value = rows.first['default_currency'] as String?;
    if (value == null) {
      return null;
    }
    return CurrencyCode.parse(value);
  }

  /// Saves [currency] as the merchant's default, replacing any previous value.
  Future<void> saveDefaultCurrency(
    MerchantId merchantId,
    CurrencyCode currency,
  ) async {
    _db.execute(
      '''
INSERT INTO store_settings (merchant_id, default_currency)
VALUES (?, ?)
ON CONFLICT (merchant_id) DO UPDATE SET default_currency = excluded.default_currency;
''',
      [merchantId.value, currency.value],
    );
  }

  /// Suggests a default currency derived from existing transactions.
  ///
  /// Returns the single distinct transaction currency when the merchant's sales
  /// and ledger entries all share exactly one, otherwise `null`. This is a
  /// read-only suggestion: it is never persisted, and the caller must obtain
  /// explicit confirmation before saving it.
  Future<CurrencyCode?> suggestDefaultCurrency(MerchantId merchantId) async {
    final rows = _db.select(
      '''
SELECT currency FROM sales WHERE merchant_id = ?
UNION
SELECT currency FROM ledger_entries WHERE merchant_id = ?;
''',
      [merchantId.value, merchantId.value],
    );
    final codes = <String>{};
    for (final row in rows) {
      final value = row['currency'] as String?;
      if (value != null) {
        codes.add(value);
      }
    }
    if (codes.length != 1) {
      return null;
    }
    return CurrencyCode.parse(codes.first);
  }
}
