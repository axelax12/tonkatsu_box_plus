import 'package:core/models/collection_item.dart';
import 'package:core/models/item_status.dart';
import 'package:core/models/media_type.dart';
import 'package:core/plus/analytics/backlog_health.dart';
import 'package:core/plus/analytics/goal_progress.dart';
import 'package:core/plus/analytics/year_review.dart';
import 'package:core/plus/models/journal_entry.dart';
import 'package:core/plus/models/play_session.dart';
import 'package:core/plus/models/yearly_goal.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tonkatsu_box/features/insights/providers/insights_providers.dart';
import 'package:tonkatsu_box/features/insights/screens/backlog_health_screen.dart';
import 'package:tonkatsu_box/features/insights/screens/goals_screen.dart';
import 'package:tonkatsu_box/features/insights/screens/year_review_screen.dart';
import 'package:tonkatsu_box/features/insights/widgets/goal_card.dart';
import 'package:tonkatsu_box/features/insights/widgets/item_cover_row.dart';

import '../../helpers/test_helpers.dart';

void main() {
  final int year = DateTime.now().year;
  final DateTime now = DateTime.now();

  void phone(WidgetTester tester) {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
  }

  YearlyGoal goal(int id, GoalMetric metric, int target) => YearlyGoal(
    id: id,
    year: year,
    metric: metric,
    target: target,
    createdAt: now,
    updatedAt: now,
  );

  group('GoalsScreen', () {
    testWidgets('shows a card per goal', (WidgetTester tester) async {
      phone(tester);
      await tester.pumpApp(
        const GoalsScreen(),
        wrapInScaffold: true,
        overrides: <Override>[
          goalProgressProvider(year).overrideWith(
            (Ref ref) async => <GoalProgress>[
              GoalProgress(
                goal: goal(1, GoalMetric.completed, 20),
                current: 4,
                expected: 8,
              ),
              GoalProgress(
                goal: goal(2, GoalMetric.hours, 100),
                current: 120,
                expected: 50,
              ),
            ],
          ),
        ],
      );

      expect(tester.takeException(), isNull);
      expect(find.byType(GoalCard), findsNWidgets(2));
    });

    testWidgets('shows the empty state without goals', (
      WidgetTester tester,
    ) async {
      phone(tester);
      await tester.pumpApp(
        const GoalsScreen(),
        wrapInScaffold: true,
        overrides: <Override>[
          goalProgressProvider(
            year,
          ).overrideWith((Ref ref) async => <GoalProgress>[]),
        ],
      );

      expect(tester.takeException(), isNull);
      expect(find.byType(GoalCard), findsNothing);
      expect(find.byIcon(Icons.add), findsOneWidget);
    });
  });

  group('BacklogHealthScreen', () {
    testWidgets('lays out stats and the oldest items', (
      WidgetTester tester,
    ) async {
      phone(tester);
      final CollectionItem oldest = createTestCollectionItem(
        id: 3,
        addedAt: now.subtract(const Duration(days: 400)),
      );
      await tester.pumpApp(
        const BacklogHealthScreen(),
        wrapInScaffold: true,
        overrides: <Override>[
          backlogHealthProvider.overrideWith(
            (Ref ref) async => BacklogHealth(
              backlogCount: 12,
              countByType: const <MediaType, int>{
                MediaType.game: 8,
                MediaType.book: 4,
              },
              averageAgeDays: 210,
              oldest: <CollectionItem>[oldest],
              completedPerMonth: 1.5,
              addedPerMonth: 2.5,
              estimatedMinutes: 6000,
              unknownCount: 3,
              minutesPerWeek: 300,
            ),
          ),
        ],
      );

      expect(tester.takeException(), isNull);
      expect(find.text('12'), findsOneWidget);
      await tester.scrollUntilVisible(find.byType(ItemCoverRow), 200);
      expect(find.byType(ItemCoverRow), findsOneWidget);
    });
  });

  group('YearReviewScreen', () {
    testWidgets('renders the review card for a busy year', (
      WidgetTester tester,
    ) async {
      phone(tester);
      final YearReview review = YearReview.compute(
        year: year,
        items: <CollectionItem>[
          createTestCollectionItem(
            id: 1,
            status: ItemStatus.completed,
            userRating: 9,
            completedAt: DateTime(year, 1, 5),
          ),
        ],
        sessions: <PlaySession>[
          PlaySession(
            id: 1,
            itemId: 1,
            startedAt: DateTime(year, 1, 2, 20),
            endedAt: DateTime(year, 1, 2, 22),
            durationSeconds: 7200,
            createdAt: DateTime(year, 1, 2),
          ),
        ],
        entries: <JournalEntry>[
          JournalEntry(
            id: 1,
            itemId: 1,
            kind: JournalEntryKind.quote,
            body: 'Worth remembering',
            isSpoiler: false,
            occurredAt: DateTime(year, 1, 3),
            createdAt: DateTime(year, 1, 3),
            updatedAt: DateTime(year, 1, 3),
          ),
        ],
      );
      await tester.pumpApp(
        const YearReviewScreen(),
        wrapInScaffold: true,
        overrides: <Override>[
          yearReviewProvider(year).overrideWith((Ref ref) async => review),
        ],
      );

      expect(tester.takeException(), isNull);
      expect(find.byType(RepaintBoundary), findsWidgets);
      await tester.scrollUntilVisible(
        find.textContaining('Worth remembering'),
        200,
      );
      expect(find.textContaining('Worth remembering'), findsOneWidget);
    });

    testWidgets('shows the empty state for a quiet year', (
      WidgetTester tester,
    ) async {
      phone(tester);
      await tester.pumpApp(
        const YearReviewScreen(),
        wrapInScaffold: true,
        overrides: <Override>[
          yearReviewProvider(year).overrideWith(
            (Ref ref) async => YearReview.compute(
              year: year,
              items: const <CollectionItem>[],
              sessions: const <PlaySession>[],
              entries: const <JournalEntry>[],
            ),
          ),
        ],
      );

      expect(tester.takeException(), isNull);
      expect(find.byIcon(Icons.ios_share), findsNothing);
    });
  });
}
