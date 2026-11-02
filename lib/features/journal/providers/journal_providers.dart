import 'dart:math' as math;

import 'package:core/models/collection_item.dart';
import 'package:core/models/item_status.dart';
import 'package:core/plus/database/journal_dao.dart';
import 'package:core/plus/models/journal_entry.dart';
import 'package:core/plus/models/play_session.dart';
import 'package:core/plus/models/playthrough.dart';
import 'package:core/plus/models/resume_bookmark.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logging/logging.dart';

import '../../../core/database/database_service.dart';
import '../../collections/providers/collections_provider.dart';

final Provider<JournalDao> journalDaoProvider = Provider<JournalDao>((Ref ref) {
  final DatabaseService db = ref.watch(databaseServiceProvider);
  return JournalDao(() => db.database);
});

final FutureProviderFamily<PlaySession?, int> runningSessionProvider =
    FutureProvider.family<PlaySession?, int>(
      (Ref ref, int itemId) =>
          ref.watch(journalDaoProvider).getRunningSession(itemId),
    );

final FutureProvider<List<PlaySession>> allRunningSessionsProvider =
    FutureProvider<List<PlaySession>>(
      (Ref ref) => ref.watch(journalDaoProvider).getRunningSessions(),
    );

final FutureProviderFamily<List<PlaySession>, int> itemSessionsProvider =
    FutureProvider.family<List<PlaySession>, int>(
      (Ref ref, int itemId) =>
          ref.watch(journalDaoProvider).getSessionsForItem(itemId),
    );

final FutureProviderFamily<List<JournalEntry>, int> itemEntriesProvider =
    FutureProvider.family<List<JournalEntry>, int>(
      (Ref ref, int itemId) =>
          ref.watch(journalDaoProvider).getEntriesForItem(itemId),
    );

final FutureProviderFamily<List<Playthrough>, int> itemPlaythroughsProvider =
    FutureProvider.family<List<Playthrough>, int>(
      (Ref ref, int itemId) =>
          ref.watch(journalDaoProvider).getPlaythroughs(itemId),
    );

final FutureProviderFamily<ResumeBookmark?, int> itemBookmarkProvider =
    FutureProvider.family<ResumeBookmark?, int>(
      (Ref ref, int itemId) =>
          ref.watch(journalDaoProvider).getBookmark(itemId),
    );

final Provider<JournalController> journalControllerProvider =
    Provider<JournalController>(JournalController.new);

/// Every diary write goes through here, so the item's total time, its status
/// and the cached providers never drift from what the sessions say.
class JournalController {
  JournalController(this._ref);

  final Ref _ref;

  static final Logger _log = Logger('JournalController');

  JournalDao get _dao => _ref.read(journalDaoProvider);

  /// Starting on an item not yet begun also moves it to "in progress".
  Future<PlaySession> startSession(int itemId, {int? playthroughId}) async {
    final PlaySession session = await _dao.startSession(
      itemId,
      now: DateTime.now(),
      playthroughId: playthroughId,
    );
    await _markInProgress(itemId);
    _refreshSessions(itemId);
    return session;
  }

  Future<PlaySession?> stopSession(
    PlaySession session, {
    String? note,
    String? progressLabel,
  }) async {
    final PlaySession? stopped = await _dao.stopSession(
      session.id,
      now: DateTime.now(),
      note: note,
      progressLabel: progressLabel,
    );
    if (stopped != null) {
      await _shiftTimeSpent(stopped.itemId, stopped.countedMinutes);
    }
    _refreshSessions(session.itemId);
    return stopped;
  }

  Future<PlaySession> addManualSession({
    required int itemId,
    required DateTime startedAt,
    required Duration duration,
    int? playthroughId,
    String? note,
    String? progressLabel,
  }) async {
    final PlaySession session = await _dao.addManualSession(
      itemId: itemId,
      startedAt: startedAt,
      duration: duration,
      now: DateTime.now(),
      playthroughId: playthroughId,
      note: note,
      progressLabel: progressLabel,
    );
    await _shiftTimeSpent(itemId, session.countedMinutes);
    _refreshSessions(itemId);
    return session;
  }

  Future<void> updateSession(PlaySession session) async {
    final PlaySession? before = await _dao.updateSession(session);
    if (before != null && !before.isRunning && !session.isRunning) {
      await _shiftTimeSpent(
        session.itemId,
        session.countedMinutes - before.countedMinutes,
      );
    }
    _refreshSessions(session.itemId);
  }

  Future<void> deleteSession(PlaySession session) async {
    final PlaySession? deleted = await _dao.deleteSession(session.id);
    if (deleted != null && !deleted.isRunning) {
      await _shiftTimeSpent(deleted.itemId, -deleted.countedMinutes);
    }
    _refreshSessions(session.itemId);
  }

  Future<JournalEntry> saveEntry(JournalEntry entry) async {
    final JournalEntry saved;
    if (entry.id == 0) {
      saved = await _dao.insertEntry(entry);
    } else {
      await _dao.updateEntry(entry);
      saved = entry;
    }
    _ref.invalidate(itemEntriesProvider(entry.itemId));
    return saved;
  }

  Future<void> deleteEntry(JournalEntry entry) async {
    await _dao.deleteEntry(entry.id);
    _ref.invalidate(itemEntriesProvider(entry.itemId));
  }

  Future<Playthrough> savePlaythrough(Playthrough playthrough) async {
    final Playthrough saved;
    if (playthrough.id == 0) {
      saved = await _dao.insertPlaythrough(playthrough);
    } else {
      await _dao.updatePlaythrough(playthrough);
      saved = playthrough;
    }
    _ref.invalidate(itemPlaythroughsProvider(playthrough.itemId));
    return saved;
  }

  Future<void> deletePlaythrough(Playthrough playthrough) async {
    await _dao.deletePlaythrough(playthrough.id);
    _ref.invalidate(itemPlaythroughsProvider(playthrough.itemId));
    _ref.invalidate(itemSessionsProvider(playthrough.itemId));
    _ref.invalidate(itemEntriesProvider(playthrough.itemId));
  }

  Future<void> saveBookmark(ResumeBookmark bookmark) async {
    await _dao.saveBookmark(bookmark);
    _ref.invalidate(itemBookmarkProvider(bookmark.itemId));
  }

  void _refreshSessions(int itemId) {
    _ref.invalidate(runningSessionProvider(itemId));
    _ref.invalidate(allRunningSessionsProvider);
    _ref.invalidate(itemSessionsProvider(itemId));
  }

  // The total is read from the database, not from a loaded list: a session can
  // stop from a screen where the item's collection was never opened.
  Future<void> _shiftTimeSpent(int itemId, int deltaMinutes) async {
    if (deltaMinutes == 0) return;
    try {
      final CollectionItem? item = await _ref
          .read(databaseServiceProvider)
          .getCollectionItemById(itemId);
      if (item == null) return;
      final int total = math.max(0, item.timeSpentMinutes + deltaMinutes);
      await _ref
          .read(collectionItemsNotifierProvider(item.collectionId).notifier)
          .setTimeSpent(itemId, total);
    } on Exception catch (e, stack) {
      _log.warning('Could not update time spent for item $itemId', e, stack);
    }
  }

  Future<void> _markInProgress(int itemId) async {
    try {
      final CollectionItem? item = await _ref
          .read(databaseServiceProvider)
          .getCollectionItemById(itemId);
      if (item == null) return;
      if (item.status != ItemStatus.notStarted &&
          item.status != ItemStatus.planned) {
        return;
      }
      await _ref
          .read(collectionItemsNotifierProvider(item.collectionId).notifier)
          .updateStatus(itemId, ItemStatus.inProgress, item.mediaType);
    } on Exception catch (e, stack) {
      _log.warning('Could not mark item $itemId in progress', e, stack);
    }
  }
}
