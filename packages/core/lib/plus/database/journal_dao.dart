import 'package:sqflite_common/sqlite_api.dart';

import '../models/journal_entry.dart';
import '../models/play_session.dart';
import '../models/playthrough.dart';
import '../models/resume_bookmark.dart';

/// Reads and writes the experience diary. It never touches
/// `collection_items`: the app adds session minutes through its own notifier.
class JournalDao {
  const JournalDao(this._getDatabase);

  final Future<Database> Function() _getDatabase;

  static const String _sessions = 'plus_sessions';
  static const String _playthroughs = 'plus_playthroughs';
  static const String _entries = 'plus_journal_entries';
  static const String _bookmarks = 'plus_bookmarks';

  Future<PlaySession?> getSession(int id) async {
    final Database db = await _getDatabase();
    final List<Map<String, dynamic>> rows = await db.query(
      _sessions,
      where: 'id = ?',
      whereArgs: <Object?>[id],
      limit: 1,
    );
    return rows.isEmpty ? null : PlaySession.fromDb(rows.first);
  }

  Future<PlaySession?> getRunningSession(int itemId) async {
    final Database db = await _getDatabase();
    final List<Map<String, dynamic>> rows = await db.query(
      _sessions,
      where: 'item_id = ? AND ended_at IS NULL',
      whereArgs: <Object?>[itemId],
      orderBy: 'started_at DESC',
      limit: 1,
    );
    return rows.isEmpty ? null : PlaySession.fromDb(rows.first);
  }

  Future<List<PlaySession>> getRunningSessions() async {
    final Database db = await _getDatabase();
    final List<Map<String, dynamic>> rows = await db.query(
      _sessions,
      where: 'ended_at IS NULL',
      orderBy: 'started_at DESC',
    );
    return rows.map(PlaySession.fromDb).toList();
  }

  /// Starting twice is harmless: the item's running session comes back as is.
  Future<PlaySession> startSession(
    int itemId, {
    required DateTime now,
    int? playthroughId,
  }) async {
    final Database db = await _getDatabase();
    return db.transaction<PlaySession>((Transaction txn) async {
      final List<Map<String, dynamic>> running = await txn.query(
        _sessions,
        where: 'item_id = ? AND ended_at IS NULL',
        whereArgs: <Object?>[itemId],
        limit: 1,
      );
      if (running.isNotEmpty) return PlaySession.fromDb(running.first);

      final PlaySession session = PlaySession(
        id: 0,
        itemId: itemId,
        playthroughId: playthroughId,
        startedAt: now,
        durationSeconds: 0,
        createdAt: now,
      );
      final int id = await txn.insert(_sessions, session.toDb());
      return session.copyWith(id: id);
    });
  }

  /// Returns null when the session is gone or was already stopped, so a
  /// double tap on "stop" never counts the same time twice.
  Future<PlaySession?> stopSession(
    int sessionId, {
    required DateTime now,
    String? note,
    String? progressLabel,
  }) async {
    final Database db = await _getDatabase();
    return db.transaction<PlaySession?>((Transaction txn) async {
      final List<Map<String, dynamic>> rows = await txn.query(
        _sessions,
        where: 'id = ? AND ended_at IS NULL',
        whereArgs: <Object?>[sessionId],
        limit: 1,
      );
      if (rows.isEmpty) return null;
      final PlaySession running = PlaySession.fromDb(rows.first);
      final DateTime endedAt =
          now.isBefore(running.startedAt) ? running.startedAt : now;
      final PlaySession stopped = running.copyWith(
        endedAt: endedAt,
        durationSeconds: endedAt.difference(running.startedAt).inSeconds,
        note: _blankToNull(note),
        progressLabel: _blankToNull(progressLabel),
      );
      await txn.update(
        _sessions,
        stopped.toDb(),
        where: 'id = ?',
        whereArgs: <Object?>[sessionId],
      );
      return stopped;
    });
  }

  /// A session logged after the fact ("played two hours yesterday").
  Future<PlaySession> addManualSession({
    required int itemId,
    required DateTime startedAt,
    required Duration duration,
    required DateTime now,
    int? playthroughId,
    String? note,
    String? progressLabel,
  }) async {
    final Duration safe = duration.isNegative ? Duration.zero : duration;
    final PlaySession session = PlaySession(
      id: 0,
      itemId: itemId,
      playthroughId: playthroughId,
      startedAt: startedAt,
      endedAt: startedAt.add(safe),
      durationSeconds: safe.inSeconds,
      note: _blankToNull(note),
      progressLabel: _blankToNull(progressLabel),
      createdAt: now,
    );
    final Database db = await _getDatabase();
    final int id = await db.insert(_sessions, session.toDb());
    return session.copyWith(id: id);
  }

  /// Returns the row as it was before the update (null if it is gone), so the
  /// caller can move the item's total by the difference.
  Future<PlaySession?> updateSession(PlaySession session) async {
    final Database db = await _getDatabase();
    return db.transaction<PlaySession?>((Transaction txn) async {
      final List<Map<String, dynamic>> rows = await txn.query(
        _sessions,
        where: 'id = ?',
        whereArgs: <Object?>[session.id],
        limit: 1,
      );
      if (rows.isEmpty) return null;
      await txn.update(
        _sessions,
        session.toDb(),
        where: 'id = ?',
        whereArgs: <Object?>[session.id],
      );
      return PlaySession.fromDb(rows.first);
    });
  }

  /// Returns the deleted row (null if it was already gone).
  Future<PlaySession?> deleteSession(int id) async {
    final Database db = await _getDatabase();
    return db.transaction<PlaySession?>((Transaction txn) async {
      final List<Map<String, dynamic>> rows = await txn.query(
        _sessions,
        where: 'id = ?',
        whereArgs: <Object?>[id],
        limit: 1,
      );
      if (rows.isEmpty) return null;
      await txn.delete(_sessions, where: 'id = ?', whereArgs: <Object?>[id]);
      return PlaySession.fromDb(rows.first);
    });
  }

  Future<List<PlaySession>> getSessionsForItem(int itemId) async {
    final Database db = await _getDatabase();
    final List<Map<String, dynamic>> rows = await db.query(
      _sessions,
      where: 'item_id = ?',
      whereArgs: <Object?>[itemId],
      orderBy: 'started_at DESC, id DESC',
    );
    return rows.map(PlaySession.fromDb).toList();
  }

  /// Finished sessions that started in `[from, to)`, oldest first.
  Future<List<PlaySession>> getSessionsBetween(
    DateTime from,
    DateTime to,
  ) async {
    final Database db = await _getDatabase();
    final List<Map<String, dynamic>> rows = await db.query(
      _sessions,
      where: 'ended_at IS NOT NULL AND started_at >= ? AND started_at < ?',
      whereArgs: <Object?>[
        from.millisecondsSinceEpoch,
        to.millisecondsSinceEpoch,
      ],
      orderBy: 'started_at ASC, id ASC',
    );
    return rows.map(PlaySession.fromDb).toList();
  }

  Future<int> getTotalSecondsForItem(int itemId) async {
    final Database db = await _getDatabase();
    final List<Map<String, dynamic>> rows = await db.rawQuery(
      'SELECT COALESCE(SUM(duration_seconds), 0) AS total FROM $_sessions '
      'WHERE item_id = ? AND ended_at IS NOT NULL',
      <Object?>[itemId],
    );
    return (rows.first['total'] as int?) ?? 0;
  }

  Future<List<Playthrough>> getPlaythroughs(int itemId) async {
    final Database db = await _getDatabase();
    final List<Map<String, dynamic>> rows = await db.query(
      _playthroughs,
      where: 'item_id = ?',
      whereArgs: <Object?>[itemId],
      orderBy: 'COALESCE(started_at, created_at) ASC, id ASC',
    );
    return rows.map(Playthrough.fromDb).toList();
  }

  Future<Playthrough> insertPlaythrough(Playthrough playthrough) async {
    final Database db = await _getDatabase();
    final int id = await db.insert(
      _playthroughs,
      playthrough.copyWith(id: 0).toDb(),
    );
    return playthrough.copyWith(id: id);
  }

  Future<void> updatePlaythrough(Playthrough playthrough) async {
    final Database db = await _getDatabase();
    await db.update(
      _playthroughs,
      playthrough.toDb(),
      where: 'id = ?',
      whereArgs: <Object?>[playthrough.id],
    );
  }

  /// Sessions and entries of the run survive, detached (ON DELETE SET NULL).
  Future<void> deletePlaythrough(int id) async {
    final Database db = await _getDatabase();
    await db.delete(_playthroughs, where: 'id = ?', whereArgs: <Object?>[id]);
  }

  Future<List<JournalEntry>> getEntriesForItem(int itemId) async {
    final Database db = await _getDatabase();
    final List<Map<String, dynamic>> rows = await db.query(
      _entries,
      where: 'item_id = ?',
      whereArgs: <Object?>[itemId],
      orderBy: 'occurred_at DESC, id DESC',
    );
    return rows.map(JournalEntry.fromDb).toList();
  }

  /// The global timeline, newest first; [before] pages back through it.
  Future<List<JournalEntry>> getRecentEntries({
    int limit = 50,
    DateTime? before,
  }) async {
    final Database db = await _getDatabase();
    final List<Map<String, dynamic>> rows = await db.query(
      _entries,
      where: before != null ? 'occurred_at < ?' : null,
      whereArgs:
          before != null ? <Object?>[before.millisecondsSinceEpoch] : null,
      orderBy: 'occurred_at DESC, id DESC',
      limit: limit,
    );
    return rows.map(JournalEntry.fromDb).toList();
  }

  Future<List<JournalEntry>> getEntriesBetween(
    DateTime from,
    DateTime to,
  ) async {
    final Database db = await _getDatabase();
    final List<Map<String, dynamic>> rows = await db.query(
      _entries,
      where: 'occurred_at >= ? AND occurred_at < ?',
      whereArgs: <Object?>[
        from.millisecondsSinceEpoch,
        to.millisecondsSinceEpoch,
      ],
      orderBy: 'occurred_at ASC, id ASC',
    );
    return rows.map(JournalEntry.fromDb).toList();
  }

  Future<JournalEntry> insertEntry(JournalEntry entry) async {
    final Database db = await _getDatabase();
    final int id = await db.insert(
      _entries,
      entry.copyWith(id: 0).toDb(),
    );
    return entry.copyWith(id: id);
  }

  Future<void> updateEntry(JournalEntry entry) async {
    final Database db = await _getDatabase();
    await db.update(
      _entries,
      entry.toDb(),
      where: 'id = ?',
      whereArgs: <Object?>[entry.id],
    );
  }

  Future<void> deleteEntry(int id) async {
    final Database db = await _getDatabase();
    await db.delete(_entries, where: 'id = ?', whereArgs: <Object?>[id]);
  }

  Future<ResumeBookmark?> getBookmark(int itemId) async {
    final Database db = await _getDatabase();
    final List<Map<String, dynamic>> rows = await db.query(
      _bookmarks,
      where: 'item_id = ?',
      whereArgs: <Object?>[itemId],
      limit: 1,
    );
    return rows.isEmpty ? null : ResumeBookmark.fromDb(rows.first);
  }

  /// An all-blank bookmark deletes the row instead of storing empty text.
  Future<void> saveBookmark(ResumeBookmark bookmark) async {
    final Database db = await _getDatabase();
    if (bookmark.isEmpty) {
      await db.delete(
        _bookmarks,
        where: 'item_id = ?',
        whereArgs: <Object?>[bookmark.itemId],
      );
      return;
    }
    await db.insert(
      _bookmarks,
      bookmark.toDb(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  static String? _blankToNull(String? value) {
    final String? trimmed = value?.trim();
    return (trimmed == null || trimmed.isEmpty) ? null : trimmed;
  }
}
