import 'package:sqflite_common/sqlite_api.dart';

import '../models/smart_list.dart';

class SmartListDao {
  const SmartListDao(this._getDatabase);

  final Future<Database> Function() _getDatabase;

  static const String _table = 'plus_smart_lists';

  Future<List<SmartList>> getAll() async {
    final Database db = await _getDatabase();
    final List<Map<String, dynamic>> rows = await db.query(
      _table,
      orderBy: 'sort_order ASC, id ASC',
    );
    return rows.map(SmartList.fromDb).toList();
  }

  Future<SmartList?> getById(int id) async {
    final Database db = await _getDatabase();
    final List<Map<String, dynamic>> rows = await db.query(
      _table,
      where: 'id = ?',
      whereArgs: <Object?>[id],
      limit: 1,
    );
    return rows.isEmpty ? null : SmartList.fromDb(rows.first);
  }

  /// New lists go to the end of the order.
  Future<SmartList> save(SmartList list) async {
    final Database db = await _getDatabase();
    if (list.id != 0) {
      await db.update(
        _table,
        list.toDb(),
        where: 'id = ?',
        whereArgs: <Object?>[list.id],
      );
      return list;
    }
    return db.transaction<SmartList>((Transaction txn) async {
      final List<Map<String, dynamic>> rows = await txn.rawQuery(
        'SELECT COALESCE(MAX(sort_order), -1) + 1 AS next FROM $_table',
      );
      final int next = (rows.first['next'] as int?) ?? 0;
      final SmartList placed = list.copyWith(sortOrder: next);
      final int id = await txn.insert(_table, placed.toDb());
      return placed.copyWith(id: id);
    });
  }

  Future<void> delete(int id) async {
    final Database db = await _getDatabase();
    await db.delete(_table, where: 'id = ?', whereArgs: <Object?>[id]);
  }

  Future<void> reorder(List<int> orderedIds) async {
    final Database db = await _getDatabase();
    final Batch batch = db.batch();
    for (int i = 0; i < orderedIds.length; i++) {
      batch.update(
        _table,
        <String, Object?>{'sort_order': i},
        where: 'id = ?',
        whereArgs: <Object?>[orderedIds[i]],
      );
    }
    await batch.commit(noResult: true);
  }
}
