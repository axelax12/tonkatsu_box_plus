import 'package:sqflite_common/sqlite_api.dart';

import '../models/owned_copy.dart';

class CopiesDao {
  const CopiesDao(this._getDatabase);

  final Future<Database> Function() _getDatabase;

  static const String _table = 'plus_copies';

  Future<List<OwnedCopy>> getForItem(int itemId) async {
    final Database db = await _getDatabase();
    final List<Map<String, dynamic>> rows = await db.query(
      _table,
      where: 'item_id = ?',
      whereArgs: <Object?>[itemId],
      orderBy: 'COALESCE(purchased_at, created_at) ASC, id ASC',
    );
    return rows.map(OwnedCopy.fromDb).toList();
  }

  Future<List<OwnedCopy>> getAll() async {
    final Database db = await _getDatabase();
    final List<Map<String, dynamic>> rows = await db.query(
      _table,
      orderBy: 'item_id ASC, id ASC',
    );
    return rows.map(OwnedCopy.fromDb).toList();
  }

  /// Copies currently lent out, the ones due soonest first.
  Future<List<OwnedCopy>> getActiveLoans() async {
    final Database db = await _getDatabase();
    final List<Map<String, dynamic>> rows = await db.query(
      _table,
      where: "loaned_to IS NOT NULL AND TRIM(loaned_to) <> ''",
      orderBy: 'loan_due_at IS NULL, loan_due_at ASC, loaned_at ASC',
    );
    return rows.map(OwnedCopy.fromDb).toList();
  }

  Future<OwnedCopy> save(OwnedCopy copy) async {
    final Database db = await _getDatabase();
    if (copy.id != 0) {
      await db.update(
        _table,
        copy.toDb(),
        where: 'id = ?',
        whereArgs: <Object?>[copy.id],
      );
      return copy;
    }
    final int id = await db.insert(_table, copy.toDb());
    return copy.copyWith(id: id);
  }

  Future<void> delete(int id) async {
    final Database db = await _getDatabase();
    await db.delete(_table, where: 'id = ?', whereArgs: <Object?>[id]);
  }

  Future<void> lend(
    int id, {
    required String to,
    required DateTime now,
    DateTime? dueAt,
  }) async {
    final Database db = await _getDatabase();
    await db.update(
      _table,
      <String, Object?>{
        'loaned_to': to.trim(),
        'loaned_at': now.millisecondsSinceEpoch,
        'loan_due_at': dueAt?.millisecondsSinceEpoch,
        'updated_at': now.millisecondsSinceEpoch,
      },
      where: 'id = ?',
      whereArgs: <Object?>[id],
    );
  }

  Future<void> markReturned(int id, {required DateTime now}) async {
    final Database db = await _getDatabase();
    await db.update(
      _table,
      <String, Object?>{
        'loaned_to': null,
        'loaned_at': null,
        'loan_due_at': null,
        'updated_at': now.millisecondsSinceEpoch,
      },
      where: 'id = ?',
      whereArgs: <Object?>[id],
    );
  }
}
