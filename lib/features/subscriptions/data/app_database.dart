import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

class AppDatabase extends GeneratedDatabase {
  AppDatabase({QueryExecutor? queryExecutor})
    : super(
        queryExecutor ??
            driftDatabase(
              name: 'subglass',
              web: DriftWebOptions(
                sqlite3Wasm: Uri.parse('sqlite3.wasm'),
                driftWorker: Uri.parse('drift_worker.js'),
              ),
            ),
      );

  Future<void>? _ready;

  @override
  int get schemaVersion => 1;

  @override
  Iterable<TableInfo<Table, Object?>> get allTables => const [];

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (_) async {
      await customStatement('''
      CREATE TABLE IF NOT EXISTS subscriptions (
        id TEXT PRIMARY KEY, name TEXT NOT NULL, amount REAL NOT NULL,
        currency_code TEXT NOT NULL DEFAULT 'PHP', frequency TEXT NOT NULL,
        custom_interval_days INTEGER, category TEXT NOT NULL,
        custom_image_path TEXT, fallback_color_hex INTEGER NOT NULL,
        fallback_icon_code INTEGER NOT NULL DEFAULT 0,
        next_billing_date TEXT NOT NULL, is_auto_renew INTEGER NOT NULL,
        reminder_days_before INTEGER NOT NULL DEFAULT 1,
        payment_method_id TEXT, created_at TEXT NOT NULL
      )
    ''');
      await customStatement('''
      CREATE TABLE IF NOT EXISTS payment_methods (
        id TEXT PRIMARY KEY, name TEXT NOT NULL, last_four TEXT,
        color_hex INTEGER NOT NULL
      )
    ''');
      await customStatement('''
      CREATE TABLE IF NOT EXISTS app_settings (
        key TEXT PRIMARY KEY, value TEXT NOT NULL
      )
    ''');
      await customStatement('''
      CREATE TABLE IF NOT EXISTS exchange_rates (
        currency_code TEXT PRIMARY KEY, rate REAL NOT NULL, updated_at TEXT NOT NULL
      )
    ''');
    },
    beforeOpen: (_) async {
      await _ensureColumn('reminder_days_before', 'INTEGER NOT NULL DEFAULT 1');
      await _ensureColumn('fallback_icon_code', 'INTEGER NOT NULL DEFAULT 0');
      await customStatement(
        "INSERT OR IGNORE INTO app_settings(key, value) VALUES ('base_currency', 'PHP')",
      );
    },
  );

  Future<void> ensureReady() =>
      _ready ??= customSelect('SELECT 1').get().then((_) {});

  Future<void> _ensureColumn(String name, String declaration) async {
    final rows = await customSelect('PRAGMA table_info(subscriptions)').get();
    if (!rows.any((row) => row.data['name'] == name)) {
      await customStatement(
        'ALTER TABLE subscriptions ADD COLUMN $name $declaration',
      );
    }
  }

  Future<List<Map<String, Object?>>> selectSql(
    String sql, [
    List<Object?> variables = const [],
  ]) async {
    await ensureReady();
    final results = await customSelect(
      sql,
      variables: variables.map((value) => Variable<Object>(value)).toList(),
    ).get();
    return results.map((row) => Map<String, Object?>.from(row.data)).toList();
  }

  Future<int> insert(String sql, [List<Object?> variables = const []]) async {
    await ensureReady();
    return customInsert(
      sql,
      variables: variables.map((value) => Variable<Object>(value)).toList(),
    );
  }

  Future<int> executeUpdate(
    String sql, [
    List<Object?> variables = const [],
  ]) async {
    await ensureReady();
    return customUpdate(
      sql,
      variables: variables.map((value) => Variable<Object>(value)).toList(),
    );
  }

  Future<void> execute(String sql, [List<Object?> variables = const []]) async {
    await ensureReady();
    await customStatement(sql, variables);
  }
}
