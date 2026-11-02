import 'package:core/models/collection_item.dart';
import 'package:core/models/item_status.dart';
import 'package:core/models/media_type.dart';
import 'package:core/plus/analytics/backlog_health.dart';
import 'package:core/plus/analytics/goal_progress.dart';
import 'package:core/plus/analytics/time_estimator.dart';
import 'package:core/plus/analytics/year_review.dart';
import 'package:core/plus/models/journal_entry.dart';
import 'package:core/plus/models/play_session.dart';
import 'package:core/plus/models/yearly_goal.dart';
import 'package:core/testing/builders.dart';
import 'package:test/test.dart';

void main() {
  final DateTime now = DateTime(2026, 7, 2);

  PlaySession session(int itemId, DateTime start, int seconds) => PlaySession(
    id: start.millisecondsSinceEpoch,
    itemId: itemId,
    startedAt: start,
    endedAt: start.add(Duration(seconds: seconds)),
    durationSeconds: seconds,
    createdAt: start,
  );

  YearlyGoal goal(GoalMetric metric, int target, {MediaType? type}) =>
      YearlyGoal(
        id: 1,
        year: 2026,
        metric: metric,
        mediaType: type,
        target: target,
        createdAt: now,
        updatedAt: now,
      );

  group('TimeEstimator.minutesFor', () {
    test('uses IGDB seconds for games and nothing without them', () {
      final CollectionItem game = createTestCollectionItem();
      expect(TimeEstimator.minutesFor(game, gameSeconds: 36000), 600);
      expect(TimeEstimator.minutesFor(game), isNull);
      expect(TimeEstimator.minutesFor(game, gameSeconds: 0), isNull);
    });

    test('falls back to an average runtime for movies', () {
      final CollectionItem movie = createTestCollectionItem(
        mediaType: MediaType.movie,
        movie: createTestMovie(),
      );
      expect(
        TimeEstimator.minutesFor(movie),
        TimeEstimator.movieFallbackMinutes,
      );
      final CollectionItem timed = createTestCollectionItem(
        mediaType: MediaType.movie,
        movie: createTestMovie(runtime: 95),
      );
      expect(TimeEstimator.minutesFor(timed), 95);
    });

    test('derives books from pages and leaves unknown pages unknown', () {
      final CollectionItem book = createTestCollectionItem(
        mediaType: MediaType.book,
        book: createTestBook(pageCount: 300),
      );
      expect(TimeEstimator.minutesFor(book), 450);
      final CollectionItem noPages = createTestCollectionItem(
        mediaType: MediaType.book,
        book: createTestBook(),
      );
      expect(TimeEstimator.minutesFor(noPages), isNull);
    });

    test('has no estimate for audio or custom items', () {
      expect(
        TimeEstimator.minutesFor(
          createTestCollectionItem(mediaType: MediaType.custom),
        ),
        isNull,
      );
    });
  });

  group('BacklogHealth.compute', () {
    test('is empty without waiting items', () {
      final BacklogHealth health = BacklogHealth.compute(
        items: <CollectionItem>[
          createTestCollectionItem(status: ItemStatus.completed),
        ],
        now: now,
        gameSecondsById: const <int, int>{},
        sessionSecondsInWindow: 0,
      );
      expect(health.isEmpty, isTrue);
      expect(health.averageAgeDays, 0);
      expect(health.monthsToClearByPace, isNull);
      expect(health.weeksToClearByTime, isNull);
    });

    test('measures size, age, estimate and pace', () {
      final List<CollectionItem> items = <CollectionItem>[
        createTestCollectionItem(
          id: 1,
          externalId: 10,
          addedAt: now.subtract(const Duration(days: 100)),
        ),
        createTestCollectionItem(
          id: 2,
          externalId: 20,
          status: ItemStatus.planned,
          addedAt: now.subtract(const Duration(days: 300)),
        ),
        createTestCollectionItem(
          id: 3,
          externalId: 30,
          status: ItemStatus.completed,
          addedAt: now.subtract(const Duration(days: 400)),
          completedAt: now.subtract(const Duration(days: 10)),
        ),
        createTestCollectionItem(
          id: 4,
          status: ItemStatus.inProgress,
          addedAt: now.subtract(const Duration(days: 5)),
        ),
      ];

      final BacklogHealth health = BacklogHealth.compute(
        items: items,
        now: now,
        gameSecondsById: const <int, int>{10: 7200},
        sessionSecondsInWindow: 180 * 60 * 60,
        windowDays: 180,
      );

      expect(health.backlogCount, 2);
      expect(health.countByType[MediaType.game], 2);
      expect(health.averageAgeDays, closeTo(200, 0.01));
      expect(health.oldest.first.id, 2);
      expect(health.estimatedMinutes, 120);
      expect(health.unknownCount, 1);
      expect(health.completedPerMonth, greaterThan(0));
      expect(health.addedPerMonth, greaterThan(0));
      expect(health.monthsToClearByPace, isNotNull);
      expect(health.weeksToClearByTime, isNotNull);
    });

    test('is shrinking only when finishing outpaces adding', () {
      final BacklogHealth growing = BacklogHealth.compute(
        items: <CollectionItem>[
          createTestCollectionItem(id: 1, addedAt: now),
          createTestCollectionItem(id: 2, addedAt: now),
        ],
        now: now,
        gameSecondsById: const <int, int>{},
        sessionSecondsInWindow: 0,
      );
      expect(growing.isShrinking, isFalse);
    });
  });

  group('GoalProgress', () {
    final List<CollectionItem> items = <CollectionItem>[
      createTestCollectionItem(
        id: 1,
        status: ItemStatus.completed,
        addedAt: DateTime(2025, 6),
        completedAt: DateTime(2026, 3, 1),
      ),
      createTestCollectionItem(
        id: 2,
        mediaType: MediaType.book,
        status: ItemStatus.completed,
        addedAt: DateTime(2026, 2),
        completedAt: DateTime(2026, 4, 1),
      ),
      createTestCollectionItem(
        id: 3,
        status: ItemStatus.completed,
        completedAt: DateTime(2025, 12, 31),
      ),
    ];

    test('counts completions in the year, filtered by type', () {
      expect(
        GoalProgress.compute(
          goal(GoalMetric.completed, 10),
          items: items,
          sessions: const <PlaySession>[],
          now: now,
        ).current,
        2,
      );
      expect(
        GoalProgress.compute(
          goal(GoalMetric.completed, 10, type: MediaType.book),
          items: items,
          sessions: const <PlaySession>[],
          now: now,
        ).current,
        1,
      );
    });

    test('backlog cleared only counts items added before the year', () {
      expect(
        GoalProgress.compute(
          goal(GoalMetric.backlogCleared, 5),
          items: items,
          sessions: const <PlaySession>[],
          now: now,
        ).current,
        1,
      );
    });

    test('sums session hours of the year and the right type', () {
      final GoalProgress progress = GoalProgress.compute(
        goal(GoalMetric.hours, 100, type: MediaType.game),
        items: items,
        sessions: <PlaySession>[
          session(1, DateTime(2026, 5, 1), 7200),
          session(2, DateTime(2026, 5, 2), 3600),
          session(1, DateTime(2025, 5, 2), 3600),
        ],
        now: now,
      );
      expect(progress.current, 2);
      expect(progress.remaining, 98);
    });

    test('reports pace against a steady year', () {
      final GoalProgress behind = GoalProgress.compute(
        goal(GoalMetric.completed, 100),
        items: items,
        sessions: const <PlaySession>[],
        now: now,
      );
      expect(behind.pace, GoalPace.behind);
      expect(behind.fraction, closeTo(0.02, 0.0001));

      final GoalProgress done = GoalProgress.compute(
        goal(GoalMetric.completed, 2),
        items: items,
        sessions: const <PlaySession>[],
        now: now,
      );
      expect(done.pace, GoalPace.done);
      expect(done.fraction, 1);
    });

    test('yearElapsed is clamped outside the year', () {
      expect(GoalProgress.yearElapsed(2027, now), 0);
      expect(GoalProgress.yearElapsed(2025, now), 1);
      expect(GoalProgress.yearElapsed(2026, now), closeTo(0.5, 0.01));
    });
  });

  group('YearReview', () {
    test('is empty for a quiet year', () {
      final YearReview review = YearReview.compute(
        year: 2026,
        items: const <CollectionItem>[],
        sessions: const <PlaySession>[],
        entries: const <JournalEntry>[],
      );
      expect(review.isEmpty, isTrue);
      expect(review.busiestMonth, isNull);
      expect(review.firstCompleted, isNull);
    });

    test('collects completions, time, streaks and highlights', () {
      final List<CollectionItem> items = <CollectionItem>[
        createTestCollectionItem(
          id: 1,
          status: ItemStatus.completed,
          userRating: 9,
          completedAt: DateTime(2026, 2, 10),
        ),
        createTestCollectionItem(
          id: 2,
          mediaType: MediaType.book,
          status: ItemStatus.completed,
          userRating: 7,
          completedAt: DateTime(2026, 1, 5),
        ),
      ];
      final List<PlaySession> sessions = <PlaySession>[
        session(1, DateTime(2026, 2, 1, 20), 3600),
        session(1, DateTime(2026, 2, 2, 20), 7200),
        session(2, DateTime(2026, 2, 4, 20), 600),
      ];
      final List<JournalEntry> entries = <JournalEntry>[
        JournalEntry(
          id: 1,
          itemId: 1,
          kind: JournalEntryKind.quote,
          body: 'A line to keep',
          isSpoiler: false,
          occurredAt: DateTime(2026, 2, 3),
          createdAt: DateTime(2026, 2, 3),
          updatedAt: DateTime(2026, 2, 3),
        ),
        JournalEntry(
          id: 2,
          itemId: 1,
          kind: JournalEntryKind.impression,
          body: 'The twist',
          isSpoiler: true,
          occurredAt: DateTime(2026, 2, 3),
          createdAt: DateTime(2026, 2, 3),
          updatedAt: DateTime(2026, 2, 3),
        ),
      ];

      final YearReview review = YearReview.compute(
        year: 2026,
        items: items,
        sessions: sessions,
        entries: entries,
      );

      expect(review.completed.map((CollectionItem i) => i.id), <int>[2, 1]);
      expect(review.completedByType[MediaType.game], 1);
      expect(review.sessionSeconds, 11400);
      expect(review.sessionCount, 3);
      expect(review.activeDays, 4);
      expect(review.longestStreakDays, 4);
      expect(review.busiestMonth, 2);
      expect(review.longestSession?.durationSeconds, 7200);
      expect(review.mostPlayed?.id, 1);
      expect(review.mostPlayedSeconds, 10800);
      expect(review.topRated.first.id, 1);
      expect(review.highlights.single.body, 'A line to keep');
    });

    test('longestStreak finds the longest consecutive run', () {
      expect(YearReview.longestStreak(<DateTime>{}), 0);
      expect(
        YearReview.longestStreak(<DateTime>{
          DateTime(2026, 1, 1),
          DateTime(2026, 1, 2),
          DateTime(2026, 1, 5),
          DateTime(2026, 1, 6),
          DateTime(2026, 1, 7),
        }),
        3,
      );
      expect(
        YearReview.longestStreak(<DateTime>{
          DateTime(2025, 12, 31),
          DateTime(2026, 1, 1),
        }),
        2,
      );
    });
  });
}
