import 'package:sqflite_common/sqlite_api.dart';

import '../plus_migration.dart';

// Universes and theme paths share one shape; entries point at library items,
// so a work removed from the library leaves every path and tag it was on.
class PlusMigrationV6 extends PlusMigration {
  const PlusMigrationV6();

  @override
  int get version => 6;

  @override
  String get description => 'Universes, theme paths and aspect tags';

  @override
  Future<void> migrate(DatabaseExecutor db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS plus_paths (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        kind TEXT NOT NULL DEFAULT 'universe',
        description TEXT,
        default_order TEXT NOT NULL DEFAULT 'recommended',
        created_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS plus_path_entries (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        path_id INTEGER NOT NULL
          REFERENCES plus_paths(id) ON DELETE CASCADE,
        item_id INTEGER NOT NULL
          REFERENCES collection_items(id) ON DELETE CASCADE,
        release_pos INTEGER NOT NULL DEFAULT 0,
        chrono_pos INTEGER NOT NULL DEFAULT 0,
        recommended_pos INTEGER NOT NULL DEFAULT 0,
        optional INTEGER NOT NULL DEFAULT 0,
        spoiler INTEGER NOT NULL DEFAULT 0,
        note TEXT,
        aspect TEXT
      )
    ''');
    await db.execute(
      'CREATE UNIQUE INDEX IF NOT EXISTS idx_plus_path_entries_unique '
      'ON plus_path_entries(path_id, item_id)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_plus_path_entries_item '
      'ON plus_path_entries(item_id)',
    );
    await db.execute('''
      CREATE TABLE IF NOT EXISTS plus_item_aspects (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        item_id INTEGER NOT NULL
          REFERENCES collection_items(id) ON DELETE CASCADE,
        aspect TEXT NOT NULL,
        label TEXT NOT NULL COLLATE NOCASE,
        created_at INTEGER NOT NULL
      )
    ''');
    await db.execute(
      'CREATE UNIQUE INDEX IF NOT EXISTS idx_plus_item_aspects_unique '
      'ON plus_item_aspects(item_id, aspect, label)',
    );
  }
}
