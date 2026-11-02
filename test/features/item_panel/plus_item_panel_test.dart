import 'package:core/models/collection_item.dart';
import 'package:core/models/media_type.dart';
import 'package:core/plus/models/journal_entry.dart';
import 'package:core/plus/models/owned_copy.dart';
import 'package:core/plus/models/play_session.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tonkatsu_box/features/collector/providers/collector_providers.dart';
import 'package:tonkatsu_box/features/collector/widgets/copies_section.dart';
import 'package:tonkatsu_box/features/item_panel/plus_item_panel.dart';
import 'package:tonkatsu_box/features/journal/providers/journal_providers.dart';
import 'package:tonkatsu_box/features/journal/widgets/journal_section.dart';

import '../../helpers/test_helpers.dart';

void main() {
  const int itemId = 7;
  late MockJournalDao dao;

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

  Future<SharedPreferences> pump(
    WidgetTester tester,
    CollectionItem item,
  ) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await tester.pumpApp(
      SingleChildScrollView(
        child: PlusItemPanel(
          item: item,
          itemName: 'Outer Wilds',
          accentColor: Colors.orange,
          isEditable: true,
        ),
      ),
      wrapInScaffold: true,
      settle: false,
      prefs: prefs,
      overrides: <Override>[
        journalDaoProvider.overrideWithValue(dao),
        itemCopiesProvider.overrideWith(
          (Ref ref, int id) async => const <OwnedCopy>[],
        ),
      ],
    );
    await tester.pump();
    await tester.pump();
    return prefs;
  }

  group('PlusItemPanel', () {
    testWidgets('shows one section at a time and remembers the choice', (
      WidgetTester tester,
    ) async {
      final SharedPreferences prefs = await pump(
        tester,
        createTestCollectionItem(id: itemId),
      );
      expect(tester.takeException(), isNull);
      expect(find.byType(JournalSection), findsOneWidget);
      expect(find.byType(CopiesSection), findsNothing);

      await tester.tap(find.byIcon(Icons.shelves).first);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.byType(JournalSection), findsNothing);
      expect(find.byType(CopiesSection), findsOneWidget);
      expect(prefs.getString(PlusItemPanel.prefsKey), PlusPanelTab.copies.name);
    });

    testWidgets('offers achievements only for games', (
      WidgetTester tester,
    ) async {
      await pump(tester, createTestCollectionItem(id: itemId));
      final int forGame = find.byType(ChoiceChip).evaluate().length;
      await pump(
        tester,
        createTestCollectionItem(
          id: itemId,
          mediaType: MediaType.movie,
          movie: createTestMovie(),
        ),
      );
      expect(find.byType(ChoiceChip).evaluate().length, lessThan(forGame));
    });
  });
}
