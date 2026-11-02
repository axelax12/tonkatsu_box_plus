import 'package:sqflite_common/sqlite_api.dart';

import '../plus_migration.dart';

// Copies hang off the collection item, so deleting the item deletes them;
// a loan lives on the copy because the same game can be lent twice.
class PlusMigrationV4 extends PlusMigration {
  const PlusMigrationV4();

  @override
  int get version => 4;

  @override
  String get description => 'Owned copies and loans';

  @override
  Future<void> migrate(DatabaseExecutor db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS plus_copies (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        item_id INTEGER NOT NULL
          REFERENCES collection_items(id) ON DELETE CASCADE,
        format TEXT NOT NULL DEFAULT 'physical',
        edition TEXT,
        condition TEXT,
        price_paid REAL,
        currency TEXT,
        purchased_at INTEGER,
        store TEXT,
        notes TEXT,
        loaned_to TEXT,
        loaned_at INTEGER,
        loan_due_at INTEGER,
        created_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL
      )
    ''');
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_plus_copies_item '
      'ON plus_copies(item_id)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_plus_copies_loaned '
      'ON plus_copies(loan_due_at) WHERE loaned_to IS NOT NULL',
    );
  }
}
