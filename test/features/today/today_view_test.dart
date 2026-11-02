import 'dart:async';

import 'package:core/models/collection_item.dart';
import 'package:core/models/item_status.dart';
import 'package:core/plus/analytics/backlog_health.dart';
import 'package:core/plus/analytics/goal_progress.dart';
import 'package:core/plus/models/media_path.dart';
import 'package:core/plus/models/resume_bookmark.dart';
import 'package:core/plus/models/smart_list.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tonkatsu_box/features/insights/providers/insights_providers.dart';
import 'package:tonkatsu_box/features/journal/providers/journal_providers.dart';
import 'package:tonkatsu_box/features/paths/providers/paths_providers.dart';
import 'package:tonkatsu_box/features/smart_lists/providers/smart_list_providers.dart';
import 'package:tonkatsu_box/features/today/providers/today_providers.dart';
import 'package:tonkatsu_box/features/today/screens/today_view.dart';
import 'package:tonkatsu_box/features/today/widgets/resume_hero.dart';

import '../../helpers/test_helpers.dart';

void main() {
  final DateTime t0 = DateTime(2026, 9, 1);

  CollectionItem work(int id, String name, ItemStatus status, {DateTime? at}) =>
      createTestCollectionItem(
        id: id,
        status: status,
        lastActivityAt: at,
        game: createTestGame(
          id: id,
          name: name,
          releaseDate: DateTime(2099, 1, id),
        ),
      );

  final List<CollectionItem> items = <CollectionItem>[
    work(1, 'Older run', ItemStatus.inProgress, at: t0),
    work(2, 'Latest run', ItemStatus.inProgress, at: t0.add(const Duration(days: 3))),
    work(3, 'Coming soon', ItemStatus.planned),
  ];

  List<Override> overrides() => <Override>[
    libraryItemsProvider.overrideWith((Ref ref) async => items),
    goalProgressProvider.overrideWith(
      (Ref ref, int year) async => const <GoalProgress>[],
    ),
    backlogHealthProvider.overrideWith(
      (Ref ref) => Completer<BacklogHealth>().future,
    ),
    pathsProvider.overrideWith((Ref ref) async => const <MediaPath>[]),
    smartListsProvider.overrideWith((Ref ref) async => const <SmartList>[]),
    runningSessionProvider.overrideWith(
      (Ref ref, int id) async => null,
    ),
    itemBookmarkProvider.overrideWith(
      (Ref ref, int id) async =>
          ResumeBookmark(itemId: id, updatedAt: t0, position: 'Chapter 4'),
    ),
  ];

  group('TodayLayout', () {
    test('round-trips and repairs unknown or missing sections', () {
      final TodayLayout layout = TodayLayout.decode('goals,-resume,bogus,goals');
      expect(layout.order.take(2), <TodaySection>[
        TodaySection.goals,
        TodaySection.resume,
      ]);
      expect(layout.order, hasLength(TodaySection.values.length));
      expect(layout.hidden, <TodaySection>{TodaySection.resume});
      expect(layout.visible, isNot(contains(TodaySection.resume)));
      expect(TodayLayout.decode(layout.encode()).encode(), layout.encode());
      expect(TodayLayout.decode(null).order, TodaySection.values);
    });
  });

  group('TodayView', () {
    testWidgets('leads with the most recently touched work', (
      WidgetTester tester,
    ) async {
      tester.view.physicalSize = const Size(360, 720);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpApp(
        const TodayView(),
        wrapInScaffold: true,
        overrides: overrides(),
      );
      expect(tester.takeException(), isNull);
      final ResumeHero hero = tester.widget(find.byType(ResumeHero));
      expect(hero.item.id, 2);
      expect(find.textContaining('Chapter 4'), findsOneWidget);
    });

    testWidgets('hides a section switched off in the saved layout', (
      WidgetTester tester,
    ) async {
      SharedPreferences.setMockInitialValues(<String, Object>{
        TodayLayoutNotifier.prefsKey: '-resume',
      });
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      await tester.pumpApp(
        const TodayView(),
        wrapInScaffold: true,
        prefs: prefs,
        overrides: overrides(),
      );
      expect(find.byType(ResumeHero), findsNothing);
    });
  });
}
