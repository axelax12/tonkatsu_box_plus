import 'package:sqflite_common/sqlite_api.dart';

import '../plus_migration.dart';

// Every table hangs off collection_items with ON DELETE CASCADE, so removing
// an item (or wiping user data) never leaves journal orphans behind.
class PlusMigrationV1 extends PlusMigration {
  const PlusMigrationV1();

  @override
  int get version => 1;

  @override
  String get description =>
      'Journal: playthroughs, sessions, entries, bookmarks';

  @override
  Future<void> migrate(DatabaseExecutor db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS plus_playthroughs (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        item_id INTEGER NOT NULL
          REFERENCES collection_items(id) ON DELETE CASCADE,
        label TEXT,
        platform_id INTEGER,
        status TEXT NOT NULL DEFAULT 'in_progress',
        started_at INTEGER,
        finished_at INTEGER,
        rating REAL,
        review TEXT,
        created_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL
      )
    ''');
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_plus_playthroughs_item '
      'ON plus_playthroughs(item_id)',
    );

    await db.execute('''
      CREATE TABLE IF NOT EXISTS plus_sessions (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        item_id INTEGER NOT NULL
          REFERENCES collection_items(id) ON DELETE CASCADE,
        playthrough_id INTEGER
          REFERENCES plus_playthroughs(id) ON DELETE SET NULL,
        started_at INTEGER NOT NULL,
        ended_at INTEGER,
        duration_seconds INTEGER NOT NULL DEFAULT 0,
        note TEXT,
        progress_label TEXT,
        created_at INTEGER NOT NULL
      )
    ''');
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_plus_sessions_item_started '
      'ON plus_sessions(item_id, started_at)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_plus_sessions_started '
      'ON plus_sessions(started_at)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_plus_sessions_running '
      'ON plus_sessions(item_id) WHERE ended_at IS NULL',
    );

    await db.execute('''
      CREATE TABLE IF NOT EXISTS plus_journal_entries (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        item_id INTEGER NOT NULL
          REFERENCES collection_items(id) ON DELETE CASCADE,
        playthrough_id INTEGER
          REFERENCES plus_playthroughs(id) ON DELETE SET NULL,
        session_id INTEGER
          REFERENCES plus_sessions(id) ON DELETE SET NULL,
        kind TEXT NOT NULL,
        body TEXT,
        image_path TEXT,
        progress_label TEXT,
        is_spoiler INTEGER NOT NULL DEFAULT 0,
        occurred_at INTEGER NOT NULL,
        created_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL
      )
    ''');
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_plus_journal_item_occurred '
      'ON plus_journal_entries(item_id, occurred_at)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_plus_journal_occurred '
      'ON plus_journal_entries(occurred_at)',
    );

    await db.execute('''
      CREATE TABLE IF NOT EXISTS plus_bookmarks (
        item_id INTEGER PRIMARY KEY
          REFERENCES collection_items(id) ON DELETE CASCADE,
        position TEXT,
        objective TEXT,
        reminders TEXT,
        characters TEXT,
        notes TEXT,
        updated_at INTEGER NOT NULL
      )
    ''');
  }
}
