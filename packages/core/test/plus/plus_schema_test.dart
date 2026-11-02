import 'package:core/plus/database/plus_schema.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:test/test.dart';

import 'plus_test_db.dart';

void main() {
  late PlusTestDb t;

  setUp(() async => t = await PlusTestDb.open());
  tearDown(() async => t.close());

  Future<Set<String>> tableNames() async {
    final List<Map<String, Object?>> rows = await t.db.rawQuery(
      "SELECT name FROM sqlite_master WHERE type = 'table'",
    );
    return rows.map((Map<String, Object?> r) => r['name'] as String).toSet();
  }

  group('PlusSchema', () {
    group('ensure', () {
      test('creates every plus table on a fresh database', () async {
        expect(
          await tableNames(),
          containsAll(<String>[
            'plus_meta',
            'plus_playthroughs',
            'plus_sessions',
            'plus_journal_entries',
            'plus_bookmarks',
          ]),
        );
      });

      test('stamps the latest version', () async {
        expect(await PlusSchema.currentVersion(t.db), PlusSchema.latestVersion);
      });

      test('is a no-op when run again', () async {
        await PlusSchema.ensure(t.db);
        await PlusSchema.ensure(t.db);
        expect(await PlusSchema.currentVersion(t.db), PlusSchema.latestVersion);
      });

      test('refuses a file written by a newer build', () async {
        await t.db.update(
          PlusSchema.metaTable,
          <String, Object?>{'value': '${PlusSchema.latestVersion + 1}'},
          where: 'key = ?',
          whereArgs: <Object?>[PlusSchema.versionKey],
        );
        expect(
          () => PlusSchema.ensure(t.db),
          throwsA(isA<PlusSchemaTooNewException>()),
        );
      });

      test('does not change the upstream user_version', () async {
        final int before = await t.db.getVersion();
        await PlusSchema.ensure(t.db);
        expect(await t.db.getVersion(), before);
      });
    });

    group('registry', () {
      test('has no gaps and starts at 1', () {
        for (int i = 0; i < PlusSchema.all.length; i++) {
          expect(PlusSchema.all[i].version, i + 1);
        }
      });
    });

    group('foreign keys', () {
      test('deleting an item cascades through every journal table', () async {
        final int itemId = await t.newItem();
        final int playthroughId = await t.db.insert(
          'plus_playthroughs',
          <String, Object?>{
            'item_id': itemId,
            'created_at': 1,
            'updated_at': 1,
          },
        );
        await t.db.insert('plus_sessions', <String, Object?>{
          'item_id': itemId,
          'playthrough_id': playthroughId,
          'started_at': 1,
          'created_at': 1,
        });
        await t.db.insert('plus_journal_entries', <String, Object?>{
          'item_id': itemId,
          'kind': 'note',
          'occurred_at': 1,
          'created_at': 1,
          'updated_at': 1,
        });
        await t.db.insert('plus_bookmarks', <String, Object?>{
          'item_id': itemId,
          'position': 'Chapter 3',
          'updated_at': 1,
        });

        await t.db.delete(
          'collection_items',
          where: 'id = ?',
          whereArgs: <Object?>[itemId],
        );

        for (final String table in <String>[
          'plus_playthroughs',
          'plus_sessions',
          'plus_journal_entries',
          'plus_bookmarks',
        ]) {
          expect(await t.db.query(table), isEmpty, reason: table);
        }
      });

      test('deleting a playthrough detaches its sessions', () async {
        final int itemId = await t.newItem();
        final int playthroughId = await t.db.insert(
          'plus_playthroughs',
          <String, Object?>{
            'item_id': itemId,
            'created_at': 1,
            'updated_at': 1,
          },
        );
        await t.db.insert('plus_sessions', <String, Object?>{
          'item_id': itemId,
          'playthrough_id': playthroughId,
          'started_at': 1,
          'created_at': 1,
        });

        await t.db.delete(
          'plus_playthroughs',
          where: 'id = ?',
          whereArgs: <Object?>[playthroughId],
        );

        final List<Map<String, Object?>> sessions = await t.db.query(
          'plus_sessions',
        );
        expect(sessions, hasLength(1));
        expect(sessions.single['playthrough_id'], isNull);
      });
    });
  });
}
