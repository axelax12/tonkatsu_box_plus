import 'package:sqflite_common/sqlite_api.dart';

import '../models/yearly_goal.dart';

class GoalsDao {
  const GoalsDao(this._getDatabase);

  final Future<Database> Function() _getDatabase;

  static const String _goals = 'plus_goals';
  static const String _ttb = 'plus_time_to_beat';
  static const int _chunkSize = 500;

  Future<List<YearlyGoal>> getGoals(int year) async {
    final Database db = await _getDatabase();
    final List<Map<String, dynamic>> rows = await db.query(
      _goals,
      where: 'year = ?',
      whereArgs: <Object?>[year],
      orderBy: 'id ASC',
    );
    return rows.map(YearlyGoal.fromDb).toList();
  }

  /// One goal per year, metric and type: saving a duplicate replaces it.
  Future<YearlyGoal> saveGoal(YearlyGoal goal) async {
    final Database db = await _getDatabase();
    return db.transaction<YearlyGoal>((Transaction txn) async {
      if (goal.id != 0) {
        await txn.update(
          _goals,
          goal.toDb(),
          where: 'id = ?',
          whereArgs: <Object?>[goal.id],
        );
        return goal;
      }
      await txn.delete(
        _goals,
        where: "year = ? AND metric = ? AND COALESCE(media_type, '') = ?",
        whereArgs: <Object?>[
          goal.year,
          goal.metric.value,
          goal.mediaType?.value ?? '',
        ],
      );
      final int id = await txn.insert(_goals, goal.toDb());
      return goal.copyWith(id: id);
    });
  }

  Future<void> deleteGoal(int id) async {
    final Database db = await _getDatabase();
    await db.delete(_goals, where: 'id = ?', whereArgs: <Object?>[id]);
  }

  /// Representative seconds per IGDB game id (normal, else rushed, else 100%).
  /// Games fetched without data are absent.
  Future<Map<int, int>> getTimeToBeat(List<int> igdbIds) async {
    if (igdbIds.isEmpty) return <int, int>{};
    final Database db = await _getDatabase();
    final Map<int, int> result = <int, int>{};
    for (int i = 0; i < igdbIds.length; i += _chunkSize) {
      final List<int> chunk = igdbIds.sublist(
        i,
        i + _chunkSize < igdbIds.length ? i + _chunkSize : igdbIds.length,
      );
      final String marks = List<String>.filled(chunk.length, '?').join(', ');
      final List<Map<String, dynamic>> rows = await db.rawQuery(
        'SELECT igdb_game_id, '
        'COALESCE(normally_seconds, hastily_seconds, completely_seconds) '
        'AS seconds FROM $_ttb WHERE igdb_game_id IN ($marks)',
        chunk,
      );
      for (final Map<String, dynamic> row in rows) {
        final int? seconds = row['seconds'] as int?;
        if (seconds != null && seconds > 0) {
          result[row['igdb_game_id'] as int] = seconds;
        }
      }
    }
    return result;
  }

  /// Ids never fetched, or fetched before [staleBefore].
  Future<List<int>> idsNeedingTimeToBeat(
    List<int> igdbIds, {
    required DateTime staleBefore,
  }) async {
    if (igdbIds.isEmpty) return <int>[];
    final Database db = await _getDatabase();
    final Set<int> fresh = <int>{};
    for (int i = 0; i < igdbIds.length; i += _chunkSize) {
      final List<int> chunk = igdbIds.sublist(
        i,
        i + _chunkSize < igdbIds.length ? i + _chunkSize : igdbIds.length,
      );
      final String marks = List<String>.filled(chunk.length, '?').join(', ');
      final List<Map<String, dynamic>> rows = await db.rawQuery(
        'SELECT igdb_game_id FROM $_ttb '
        'WHERE fetched_at >= ? AND igdb_game_id IN ($marks)',
        <Object?>[staleBefore.millisecondsSinceEpoch, ...chunk],
      );
      for (final Map<String, dynamic> row in rows) {
        fresh.add(row['igdb_game_id'] as int);
      }
    }
    return igdbIds.where((int id) => !fresh.contains(id)).toSet().toList();
  }

  /// Stores what IGDB answered; [requested] ids missing from [found] are
  /// stored empty so they are not asked again until they go stale.
  Future<void> saveTimeToBeat({
    required List<int> requested,
    required Map<int, ({int? hastily, int? normally, int? completely})> found,
    required DateTime now,
  }) async {
    if (requested.isEmpty) return;
    final Database db = await _getDatabase();
    final Batch batch = db.batch();
    for (final int id in requested.toSet()) {
      final ({int? hastily, int? normally, int? completely})? t = found[id];
      batch.insert(
        _ttb,
        <String, Object?>{
          'igdb_game_id': id,
          'hastily_seconds': t?.hastily,
          'normally_seconds': t?.normally,
          'completely_seconds': t?.completely,
          'fetched_at': now.millisecondsSinceEpoch,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    await batch.commit(noResult: true);
  }
}
