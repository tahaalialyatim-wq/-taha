import 'package:path/path.dart' as p;
import 'package:sqlite3/sqlite3.dart';

import 'database_init_exception.dart';

typedef SqliteOpener = Database Function(String path);

class DatabaseService {
  DatabaseService({
    required this.databasePath,
    SqliteOpener? opener,
  }) : _opener = opener ?? sqlite3.open;

  static const int schemaVersion = 2;
  static const String fileName = 'awtad_retail.sqlite';

  final String databasePath;
  final SqliteOpener _opener;

  Database? _db;
  bool get isOpen => _db != null;
  Database get database {
    final db = _db;
    if (db == null) {
      throw DatabaseInitException('قاعدة البيانات غير مهيأة.');
    }
    return db;
  }

  static String pathIn(String documentsDirectory) =>
      p.join(documentsDirectory, fileName);

  Future<void> initialize() async {
    if (_db != null) {
      return;
    }
    Database? db;
    try {
      db = _opener(databasePath);
      db.execute('PRAGMA foreign_keys = ON;');
      db.execute('PRAGMA journal_mode = WAL;');
      _migrate(db);
      final check = db.select('PRAGMA integrity_check;');
      final result = check.first.values.first?.toString() ?? '';
      if (result != 'ok') {
        throw DatabaseInitException('فشل التحقق من سلامة قاعدة البيانات.');
      }
      _db = db;
    } catch (error) {
      db?.dispose();
      _db = null;
      if (error is DatabaseInitException) {
        rethrow;
      }
      throw DatabaseInitException(
        'تعذر تهيئة قاعدة البيانات المحلية.',
        error,
      );
    }
  }

  void close() {
    _db?.dispose();
    _db = null;
  }

  static void _migrate(Database db) {
    db.execute('BEGIN IMMEDIATE;');
    try {
      db.execute('''
CREATE TABLE IF NOT EXISTS schema_info (
  version INTEGER NOT NULL
);
''');
      final rows = db.select('SELECT version FROM schema_info LIMIT 1;');
      final current = rows.isEmpty ? 0 : (rows.first['version'] as int? ?? 0);
      if (current < 0 || current > schemaVersion) {
        throw DatabaseInitException('إصدار مخطط غير مدعوم: $current');
      }
      if (current < 1) {
        _createV1(db);
      }
      if (current < 2) {
        _createV2(db);
      }
      if (current == 0) {
        db.execute('INSERT INTO schema_info (version) VALUES (?);', [
          schemaVersion,
        ]);
      } else if (current < schemaVersion) {
        db.execute('UPDATE schema_info SET version = ?;', [schemaVersion]);
      }
      db.execute('COMMIT;');
    } catch (_) {
      db.execute('ROLLBACK;');
      rethrow;
    }
  }

  static void _createV1(Database db) {
    db.execute('''
CREATE TABLE inventory_items (
  merchant_id TEXT NOT NULL,
  item_id TEXT NOT NULL,
  product_id TEXT NOT NULL,
  quantity_milli INTEGER NOT NULL,
  selling_currency TEXT,
  selling_minor INTEGER,
  purchase_currency TEXT,
  purchase_minor INTEGER,
  minimum_stock_milli INTEGER,
  PRIMARY KEY (merchant_id, item_id),
  UNIQUE (merchant_id, product_id)
);
''');
    db.execute('''
CREATE TABLE customers (
  merchant_id TEXT NOT NULL,
  customer_id TEXT NOT NULL,
  name TEXT NOT NULL,
  phone TEXT,
  notes TEXT,
  PRIMARY KEY (merchant_id, customer_id)
);
''');
    db.execute('''
CREATE TABLE sales (
  merchant_id TEXT NOT NULL,
  sale_id TEXT NOT NULL,
  currency TEXT NOT NULL,
  customer_id TEXT,
  PRIMARY KEY (merchant_id, sale_id)
);
''');
    db.execute('''
CREATE TABLE sale_lines (
  merchant_id TEXT NOT NULL,
  sale_id TEXT NOT NULL,
  line_index INTEGER NOT NULL,
  product_id TEXT NOT NULL,
  quantity_milli INTEGER NOT NULL,
  unit_currency TEXT NOT NULL,
  unit_minor INTEGER NOT NULL,
  PRIMARY KEY (merchant_id, sale_id, line_index),
  FOREIGN KEY (merchant_id, sale_id) REFERENCES sales (merchant_id, sale_id)
);
''');
    db.execute('''
CREATE TABLE ledger_entries (
  merchant_id TEXT NOT NULL,
  entry_id TEXT NOT NULL,
  customer_id TEXT NOT NULL,
  currency TEXT NOT NULL,
  amount_minor INTEGER NOT NULL,
  entry_type TEXT NOT NULL,
  occurred_at TEXT NOT NULL,
  reference TEXT,
  PRIMARY KEY (merchant_id, entry_id)
);
''');
  }

  static void _createV2(Database db) {
    db.execute('''
CREATE TABLE IF NOT EXISTS store_settings (
  merchant_id TEXT NOT NULL PRIMARY KEY,
  default_currency TEXT
);
''');
  }
}
