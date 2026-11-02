import 'package:sqflite_common/sqlite_api.dart';

import '../models/media_path.dart';

class PathsDao {
  const PathsDao(this._getDatabase);

  final Future<Database> Function() _getDatabase;

  static const String _paths = 'plus_paths';
  static const String _entries = 'plus_path_entries';

  Future<List<MediaPath>> getPaths({PathKind? kind}) async {
    final Database db = await _getDatabase();
    final List<Map<String, dynamic>> rows = await db.query(
      _paths,
      where: kind == null ? null : 'kind = ?',
      whereArgs: kind == null ? null : <Object?>[kind.value],
      orderBy: 'name COLLATE NOCASE ASC',
    );
    return rows.map(MediaPath.fromDb).toList();
  }

  Future<List<MediaPath>> getPathsForItem(int itemId) async {
    final Database db = await _getDatabase();
    final List<Map<String, dynamic>> rows = await db.rawQuery(
      'SELECT p.* FROM $_paths p '
      'JOIN $_entries e ON e.path_id = p.id '
      'WHERE e.item_id = ? ORDER BY p.name COLLATE NOCASE ASC',
      <Object?>[itemId],
    );
    return rows.map(MediaPath.fromDb).toList();
  }

  Future<MediaPath> savePath(MediaPath path) async {
    final Database db = await _getDatabase();
    if (path.id != 0) {
      await db.update(
        _paths,
        path.toDb(),
        where: 'id = ?',
        whereArgs: <Object?>[path.id],
      );
      return path;
    }
    final int id = await db.insert(_paths, path.toDb());
    return path.copyWith(id: id);
  }

  Future<void> deletePath(int id) async {
    final Database db = await _getDatabase();
    await db.delete(_paths, where: 'id = ?', whereArgs: <Object?>[id]);
  }

  Future<List<PathEntry>> getEntries(int pathId) async {
    final Database db = await _getDatabase();
    final List<Map<String, dynamic>> rows = await db.query(
      _entries,
      where: 'path_id = ?',
      whereArgs: <Object?>[pathId],
      orderBy: 'recommended_pos ASC, id ASC',
    );
    return rows.map(PathEntry.fromDb).toList();
  }

  Future<List<PathEntry>> getAllEntries() async {
    final Database db = await _getDatabase();
    final List<Map<String, dynamic>> rows = await db.query(_entries);
    return rows.map(PathEntry.fromDb).toList();
  }

  /// Adds library items at the end of every order; ones already on the path
  /// are skipped, never duplicated.
  Future<void> addItems(int pathId, List<int> itemIds) async {
    if (itemIds.isEmpty) return;
    final Database db = await _getDatabase();
    await db.transaction((Transaction txn) async {
      final List<Map<String, dynamic>> rows = await txn.rawQuery(
        'SELECT COALESCE(MAX(release_pos), -1) AS r, '
        'COALESCE(MAX(chrono_pos), -1) AS c, '
        'COALESCE(MAX(recommended_pos), -1) AS m '
        'FROM $_entries WHERE path_id = ?',
        <Object?>[pathId],
      );
      int r = (rows.first['r'] as int?) ?? -1;
      int c = (rows.first['c'] as int?) ?? -1;
      int m = (rows.first['m'] as int?) ?? -1;
      // Checked up front: an ignored insert's return value differs by engine.
      final Set<int> present = <int>{
        for (final Map<String, Object?> row in await txn.query(
          _entries,
          columns: <String>['item_id'],
          where: 'path_id = ?',
          whereArgs: <Object?>[pathId],
        ))
          row['item_id'] as int,
      };
      for (final int itemId in itemIds) {
        if (!present.add(itemId)) continue;
        await txn.insert(_entries, <String, Object?>{
          'path_id': pathId,
          'item_id': itemId,
          'release_pos': ++r,
          'chrono_pos': ++c,
          'recommended_pos': ++m,
        });
      }
    });
  }

  Future<void> updateEntry(PathEntry entry) async {
    final Database db = await _getDatabase();
    await db.update(
      _entries,
      entry.toDb(),
      where: 'id = ?',
      whereArgs: <Object?>[entry.id],
    );
  }

  Future<void> removeEntry(int id) async {
    final Database db = await _getDatabase();
    await db.delete(_entries, where: 'id = ?', whereArgs: <Object?>[id]);
  }

  /// Rewrites one order's positions to match [orderedEntryIds].
  Future<void> reorder(PathOrder order, List<int> orderedEntryIds) async {
    final String column = switch (order) {
      PathOrder.release => 'release_pos',
      PathOrder.chronological => 'chrono_pos',
      PathOrder.recommended => 'recommended_pos',
    };
    final Database db = await _getDatabase();
    final Batch batch = db.batch();
    for (int i = 0; i < orderedEntryIds.length; i++) {
      batch.update(
        _entries,
        <String, Object?>{column: i},
        where: 'id = ?',
        whereArgs: <Object?>[orderedEntryIds[i]],
      );
    }
    await batch.commit(noResult: true);
  }
}
