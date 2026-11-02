import 'package:sqflite_common/sqlite_api.dart';

import '../plus_migration.dart';

// Lookups against outside services are cached, misses included, so a game
// with no Steam page or no store listing is not asked about on every open.
class PlusMigrationV5 extends PlusMigration {
  const PlusMigrationV5();

  @override
  int get version => 5;

  @override
  String get description => 'Steam app links, achievement sync and prices';

  @override
  Future<void> migrate(DatabaseExecutor db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS plus_steam_apps (
        igdb_game_id INTEGER PRIMARY KEY,
        app_id TEXT,
        checked_at INTEGER NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS plus_steam_sync (
        app_id TEXT PRIMARY KEY,
        earned INTEGER NOT NULL,
        total INTEGER NOT NULL,
        synced_at INTEGER NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS plus_prices (
        item_id INTEGER PRIMARY KEY
          REFERENCES collection_items(id) ON DELETE CASCADE,
        itad_id TEXT,
        price REAL,
        regular REAL,
        cut INTEGER,
        currency TEXT,
        shop TEXT,
        url TEXT,
        low_price REAL,
        alerted_low REAL,
        checked_at INTEGER NOT NULL
      )
    ''');
  }
}
