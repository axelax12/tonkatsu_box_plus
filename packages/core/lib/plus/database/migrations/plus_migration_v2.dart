import 'package:sqflite_common/sqlite_api.dart';

import '../plus_migration.dart';

// IGDB completion times are cached locally: the backlog estimate needs them
// for every waiting game, and IGDB only serves them on request.
class PlusMigrationV2 extends PlusMigration {
  const PlusMigrationV2();

  @override
  int get version => 2;

  @override
  String get description => 'Yearly goals and IGDB time-to-beat cache';

  @override
  Future<void> migrate(DatabaseExecutor db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS plus_goals (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        year INTEGER NOT NULL,
        metric TEXT NOT NULL,
        media_type TEXT,
        target INTEGER NOT NULL,
        created_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL
      )
    ''');
    await db.execute(
      'CREATE UNIQUE INDEX IF NOT EXISTS idx_plus_goals_unique '
      "ON plus_goals(year, metric, COALESCE(media_type, ''))",
    );

    await db.execute('''
      CREATE TABLE IF NOT EXISTS plus_time_to_beat (
        igdb_game_id INTEGER PRIMARY KEY,
        hastily_seconds INTEGER,
        normally_seconds INTEGER,
        completely_seconds INTEGER,
        fetched_at INTEGER NOT NULL
      )
    ''');
  }
}
