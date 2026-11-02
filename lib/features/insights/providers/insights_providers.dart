import 'dart:async';

import 'package:core/models/collection_item.dart';
import 'package:core/models/game_time_to_beat.dart';
import 'package:core/models/media_type.dart';
import 'package:core/plus/analytics/backlog_health.dart';
import 'package:core/plus/analytics/goal_progress.dart';
import 'package:core/plus/analytics/time_estimator.dart';
import 'package:core/plus/analytics/year_review.dart';
import 'package:core/plus/database/goals_dao.dart';
import 'package:core/plus/models/journal_entry.dart';
import 'package:core/plus/models/play_session.dart';
import 'package:core/plus/models/yearly_goal.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logging/logging.dart';

import '../../../core/api/igdb_api.dart';
import '../../../core/database/database_service.dart';
import '../../home/providers/all_items_provider.dart';
import '../../journal/providers/journal_providers.dart';

final Logger _log = Logger('Insights');

/// IGDB times change rarely; a month keeps the estimate fresh enough.
const Duration kTimeToBeatMaxAge = Duration(days: 30);

final Provider<GoalsDao> goalsDaoProvider = Provider<GoalsDao>((Ref ref) {
  final DatabaseService db = ref.watch(databaseServiceProvider);
  return GoalsDao(() => db.database);
});

/// The whole library with its media, kept in sync by the All Items notifier.
final FutureProvider<List<CollectionItem>> libraryItemsProvider =
    FutureProvider<List<CollectionItem>>((Ref ref) {
      final AsyncValue<List<CollectionItem>> all = ref.watch(
        allItemsNotifierProvider,
      );
      final List<CollectionItem>? items = all.valueOrNull;
      if (items != null) return items;
      final Object? error = all.error;
      if (error != null) {
        return Future<List<CollectionItem>>.error(
          error,
          all.stackTrace ?? StackTrace.current,
        );
      }
      // Still loading: the watch above rebuilds this provider once data lands.
      return Completer<List<CollectionItem>>().future;
    });

/// Finished sessions of a calendar year; refreshed whenever the journal is.
final FutureProviderFamily<List<PlaySession>, int> yearSessionsProvider =
    FutureProvider.family<List<PlaySession>, int>((Ref ref, int year) {
      ref.watch(allRunningSessionsProvider);
      return ref
          .watch(journalDaoProvider)
          .getSessionsBetween(DateTime(year), DateTime(year + 1));
    });

final FutureProviderFamily<List<YearlyGoal>, int> goalsProvider =
    FutureProvider.family<List<YearlyGoal>, int>(
      (Ref ref, int year) => ref.watch(goalsDaoProvider).getGoals(year),
    );

final FutureProviderFamily<List<GoalProgress>, int> goalProgressProvider =
    FutureProvider.family<List<GoalProgress>, int>((Ref ref, int year) async {
      final List<YearlyGoal> goals = await ref.watch(
        goalsProvider(year).future,
      );
      if (goals.isEmpty) return <GoalProgress>[];
      final List<CollectionItem> items = await ref.watch(
        libraryItemsProvider.future,
      );
      final List<PlaySession> sessions = await ref.watch(
        yearSessionsProvider(year).future,
      );
      final DateTime now = DateTime.now();
      return <GoalProgress>[
        for (final YearlyGoal goal in goals)
          GoalProgress.compute(
            goal,
            items: items,
            sessions: sessions,
            now: now,
          ),
      ];
    });

final FutureProvider<BacklogHealth> backlogHealthProvider =
    FutureProvider<BacklogHealth>((Ref ref) async {
      final List<CollectionItem> items = await ref.watch(
        libraryItemsProvider.future,
      );
      final DateTime now = DateTime.now();
      final DateTime windowStart = now.subtract(
        const Duration(days: BacklogHealth.defaultWindowDays),
      );
      ref.watch(allRunningSessionsProvider);
      final List<PlaySession> sessions = await ref
          .read(journalDaoProvider)
          .getSessionsBetween(windowStart, now);
      final int sessionSeconds = sessions.fold<int>(
        0,
        (int sum, PlaySession s) => sum + s.durationSeconds,
      );

      final List<int> gameIds = <int>{
        for (final CollectionItem i in items)
          if (i.mediaType == MediaType.game && isBacklogStatus(i.status))
            i.externalId,
      }.toList();
      final GoalsDao dao = ref.read(goalsDaoProvider);
      await _refreshTimeToBeat(ref, dao, gameIds, now);
      final Map<int, int> gameSeconds = await dao.getTimeToBeat(gameIds);

      return BacklogHealth.compute(
        items: items,
        now: now,
        gameSecondsById: gameSeconds,
        sessionSecondsInWindow: sessionSeconds,
      );
    });

// Best effort: without IGDB keys or network the estimate simply covers fewer
// games, and the screen says how many were left out.
Future<void> _refreshTimeToBeat(
  Ref ref,
  GoalsDao dao,
  List<int> gameIds,
  DateTime now,
) async {
  final List<int> missing = await dao.idsNeedingTimeToBeat(
    gameIds,
    staleBefore: now.subtract(kTimeToBeatMaxAge),
  );
  if (missing.isEmpty) return;
  try {
    final Map<int, GameTimeToBeat> fetched = await ref
        .read(igdbApiProvider)
        .getTimeToBeat(missing);
    await dao.saveTimeToBeat(
      requested: missing,
      found: <int, ({int? hastily, int? normally, int? completely})>{
        for (final MapEntry<int, GameTimeToBeat> e in fetched.entries)
          e.key: (
            hastily: e.value.hastily,
            normally: e.value.normally,
            completely: e.value.completely,
          ),
      },
      now: now,
    );
  } on Exception catch (e, stack) {
    _log.info('Time to beat unavailable, estimating without it', e, stack);
  }
}

final FutureProviderFamily<YearReview, int> yearReviewProvider =
    FutureProvider.family<YearReview, int>((Ref ref, int year) async {
      final List<CollectionItem> items = await ref.watch(
        libraryItemsProvider.future,
      );
      final List<PlaySession> sessions = await ref.watch(
        yearSessionsProvider(year).future,
      );
      final List<JournalEntry> entries = await ref
          .read(journalDaoProvider)
          .getEntriesBetween(DateTime(year), DateTime(year + 1));
      return YearReview.compute(
        year: year,
        items: items,
        sessions: sessions,
        entries: entries,
      );
    });

final Provider<GoalsController> goalsControllerProvider =
    Provider<GoalsController>(GoalsController.new);

class GoalsController {
  GoalsController(this._ref);

  final Ref _ref;

  Future<void> save(YearlyGoal goal) async {
    await _ref.read(goalsDaoProvider).saveGoal(goal);
    _ref.invalidate(goalsProvider(goal.year));
  }

  Future<void> delete(YearlyGoal goal) async {
    await _ref.read(goalsDaoProvider).deleteGoal(goal.id);
    _ref.invalidate(goalsProvider(goal.year));
  }
}
