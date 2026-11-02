import 'package:sqflite_common/sqlite_api.dart';

import '../models/item_aspect.dart';
import '../models/media_path.dart';

class AspectsDao {
  const AspectsDao(this._getDatabase);

  final Future<Database> Function() _getDatabase;

  static const String _table = 'plus_item_aspects';

  /// Longest label kept; a tag is a word or two, not a review.
  static const int maxLabelLength = 40;

  Future<List<ItemAspectTag>> getAll() async {
    final Database db = await _getDatabase();
    final List<Map<String, dynamic>> rows = await db.query(
      _table,
      orderBy: 'label COLLATE NOCASE ASC',
    );
    return rows.map(ItemAspectTag.fromDb).toList();
  }

  Future<List<ItemAspectTag>> getForItem(int itemId) async {
    final Database db = await _getDatabase();
    final List<Map<String, dynamic>> rows = await db.query(
      _table,
      where: 'item_id = ?',
      whereArgs: <Object?>[itemId],
      orderBy: 'aspect ASC, label COLLATE NOCASE ASC',
    );
    return rows.map(ItemAspectTag.fromDb).toList();
  }

  /// Returns false for a blank label or one the item already carries.
  Future<bool> add({
    required int itemId,
    required PathAspect aspect,
    required String label,
    required DateTime now,
  }) async {
    final String clean = normalizeLabel(label);
    if (clean.isEmpty) return false;
    final Database db = await _getDatabase();
    // The label column is NOCASE, so this lookup ignores case as well.
    final List<Map<String, Object?>> existing = await db.query(
      _table,
      columns: <String>['id'],
      where: 'item_id = ? AND aspect = ? AND label = ?',
      whereArgs: <Object?>[itemId, aspect.value, clean],
      limit: 1,
    );
    if (existing.isNotEmpty) return false;
    await db.insert(
      _table,
      ItemAspectTag(
        id: 0,
        itemId: itemId,
        aspect: aspect,
        label: clean,
        createdAt: now,
      ).toDb(),
    );
    return true;
  }

  Future<void> remove(int id) async {
    final Database db = await _getDatabase();
    await db.delete(_table, where: 'id = ?', whereArgs: <Object?>[id]);
  }

  static String normalizeLabel(String label) {
    final String collapsed = label.trim().replaceAll(RegExp(r'\s+'), ' ');
    return collapsed.length <= maxLabelLength
        ? collapsed
        : collapsed.substring(0, maxLabelLength).trimRight();
  }
}
