import 'package:core/plus/models/journal_entry.dart';
import 'package:core/plus/models/play_session.dart';
import 'package:core/plus/models/resume_bookmark.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:tonkatsu_box/features/journal/providers/journal_providers.dart';
import 'package:tonkatsu_box/features/journal/widgets/journal_entry_tile.dart';
import 'package:tonkatsu_box/features/journal/widgets/journal_section.dart';
import 'package:tonkatsu_box/features/journal/widgets/live_session_clock.dart';

import '../../../helpers/test_helpers.dart';

void main() {
  const int itemId = 7;
  late MockJournalDao dao;
  final DateTime t0 = DateTime(2026, 4, 2, 21);

  setUp(() {
    dao = MockJournalDao();
    when(() => dao.getRunningSession(itemId)).thenAnswer((_) async => null);
    when(
      () => dao.getSessionsForItem(itemId),
    ).thenAnswer((_) async => <PlaySession>[]);
    when(
      () => dao.getEntriesForItem(itemId),
    ).thenAnswer((_) async => <JournalEntry>[]);
    when(() => dao.getBookmark(itemId)).thenAnswer((_) async => null);
  });

  Future<void> pump(WidgetTester tester, {bool editable = true}) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpApp(
      SingleChildScrollView(
        child: JournalSection(
          itemId: itemId,
          itemName: 'Outer Wilds',
          accentColor: Colors.orange,
          isEditable: editable,
        ),
      ),
      wrapInScaffold: true,
      settle: false,
      overrides: <Override>[journalDaoProvider.overrideWithValue(dao)],
    );
    await tester.pump();
    await tester.pump();
  }

  group('JournalSection', () {
    testWidgets('offers to start or log a session when idle', (
      WidgetTester tester,
    ) async {
      await pump(tester);

      expect(tester.takeException(), isNull);
      expect(find.byIcon(Icons.play_arrow_rounded), findsOneWidget);
      expect(find.byIcon(Icons.history), findsOneWidget);
      expect(find.byType(LiveSessionClock), findsNothing);
    });

    testWidgets('shows the live clock and a stop button while running', (
      WidgetTester tester,
    ) async {
      final PlaySession running = PlaySession(
        id: 1,
        itemId: itemId,
        startedAt: DateTime.now().subtract(const Duration(minutes: 5)),
        durationSeconds: 0,
        createdAt: t0,
      );
      when(
        () => dao.getRunningSession(itemId),
      ).thenAnswer((_) async => running);

      await pump(tester);

      expect(tester.takeException(), isNull);
      expect(find.byType(LiveSessionClock), findsOneWidget);
      expect(find.byIcon(Icons.stop_rounded), findsOneWidget);
    });

    testWidgets('hides every action when the item is read-only', (
      WidgetTester tester,
    ) async {
      await pump(tester, editable: false);

      expect(find.byIcon(Icons.play_arrow_rounded), findsNothing);
      expect(find.byIcon(Icons.add), findsNothing);
    });

    testWidgets('previews at most three entries', (WidgetTester tester) async {
      when(() => dao.getEntriesForItem(itemId)).thenAnswer(
        (_) async => <JournalEntry>[
          for (int i = 0; i < 5; i++)
            JournalEntry(
              id: i + 1,
              itemId: itemId,
              kind: JournalEntryKind.note,
              body: 'note $i',
              isSpoiler: false,
              occurredAt: t0.subtract(Duration(days: i)),
              createdAt: t0,
              updatedAt: t0,
            ),
        ],
      );

      await pump(tester);

      expect(find.byType(JournalEntryTile), findsNWidgets(3));
    });

    testWidgets('keeps a spoiler hidden until tapped', (
      WidgetTester tester,
    ) async {
      when(() => dao.getEntriesForItem(itemId)).thenAnswer(
        (_) async => <JournalEntry>[
          JournalEntry(
            id: 1,
            itemId: itemId,
            kind: JournalEntryKind.note,
            body: 'the twist',
            isSpoiler: true,
            occurredAt: t0,
            createdAt: t0,
            updatedAt: t0,
          ),
        ],
      );

      await pump(tester);
      expect(find.text('the twist'), findsNothing);

      await tester.tap(find.byIcon(Icons.visibility_off_outlined));
      await tester.pump();
      expect(find.text('the twist'), findsOneWidget);
    });

    testWidgets('shows the bookmark position when one is saved', (
      WidgetTester tester,
    ) async {
      when(() => dao.getBookmark(itemId)).thenAnswer(
        (_) async => ResumeBookmark(
          itemId: itemId,
          position: 'Quantum tower',
          updatedAt: t0,
        ),
      );

      await pump(tester);

      expect(find.text('Quantum tower'), findsOneWidget);
    });
  });
}
