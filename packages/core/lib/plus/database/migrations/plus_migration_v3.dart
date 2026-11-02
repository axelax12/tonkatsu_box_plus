import 'package:sqflite_common/sqlite_api.dart';

import '../plus_migration.dart';

// Rules are stored as JSON: they are only ever evaluated in Dart over the
// loaded library, never queried column by column.
class PlusMigrationV3 extends PlusMigration {
  const PlusMigrationV3();

  @override
  int get version => 3;

  @override
  String get description => 'Smart lists';

  @override
  Future<void> migrate(DatabaseExecutor db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS plus_smart_lists (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        rules TEXT NOT NULL,
        sort_order INTEGER NOT NULL DEFAULT 0,
        created_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL
      )
    ''');
  }
}
