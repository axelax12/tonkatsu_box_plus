import 'package:sqflite_common/sqlite_api.dart';

import 'migrations/plus_migration_v1.dart';
import 'plus_migration.dart';

/// Thrown when the file was written by a newer fork build; nothing is touched.
class PlusSchemaTooNewException implements Exception {
  const PlusSchemaTooNewException({
    required this.fileVersion,
    required this.appVersion,
  });

  final int fileVersion;

  final int appVersion;

  @override
  String toString() =>
      'Plus schema v$fileVersion is newer than this build supports '
      '(v$appVersion). Update the app — the file was left untouched.';
}

/// The fork's tables live on a second chain versioned in `plus_meta`, never in
/// `user_version`, so upstream migrations can be merged without renumbering.
class PlusSchema {
  const PlusSchema._();

  static const String metaTable = 'plus_meta';

  static const String versionKey = 'schema_version';

  static const List<PlusMigration> all = <PlusMigration>[
    PlusMigrationV1(),
  ];

  static int get latestVersion => all.last.version;

  static Future<int> currentVersion(DatabaseExecutor db) async {
    final List<Map<String, Object?>> rows = await db.query(
      metaTable,
      columns: <String>['value'],
      where: 'key = ?',
      whereArgs: <Object?>[versionKey],
    );
    if (rows.isEmpty) return 0;
    return int.tryParse(rows.first['value']?.toString() ?? '') ?? 0;
  }

  /// Idempotent; runs on every open, after upstream's chain has finished.
  static Future<void> ensure(Database db) async {
    await db.execute(
      'CREATE TABLE IF NOT EXISTS $metaTable '
      '(key TEXT PRIMARY KEY, value TEXT NOT NULL)',
    );
    final int current = await currentVersion(db);
    if (current > latestVersion) {
      throw PlusSchemaTooNewException(
        fileVersion: current,
        appVersion: latestVersion,
      );
    }
    for (final PlusMigration migration in all) {
      if (migration.version <= current) continue;
      await db.transaction((Transaction txn) async {
        await migration.migrate(txn);
        await txn.insert(
          metaTable,
          <String, Object?>{
            'key': versionKey,
            'value': migration.version.toString(),
          },
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      });
    }
  }
}
