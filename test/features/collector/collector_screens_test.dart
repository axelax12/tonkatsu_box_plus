import 'package:core/models/collection_item.dart';
import 'package:core/plus/analytics/collector_insights.dart';
import 'package:core/plus/models/owned_copy.dart';
import 'package:core/plus/models/play_session.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tonkatsu_box/features/collector/providers/collector_providers.dart';
import 'package:tonkatsu_box/features/collector/screens/collector_screen.dart';
import 'package:tonkatsu_box/features/collector/widgets/collector_room.dart';
import 'package:tonkatsu_box/features/collector/widgets/copies_section.dart';
import 'package:tonkatsu_box/features/insights/providers/insights_providers.dart';

import '../../helpers/test_helpers.dart';

void main() {
  final DateTime t0 = DateTime(2026, 4, 1);
  final List<CollectionItem> items = <CollectionItem>[
    for (int i = 1; i <= 9; i++) createTestCollectionItem(id: i),
  ];
  final List<OwnedCopy> copies = <OwnedCopy>[
    for (final CollectionItem item in items)
      OwnedCopy(
        id: item.id,
        itemId: item.id,
        format: CopyFormat.physical,
        pricePaid: 30,
        currency: 'EUR',
        loanedTo: item.id == 1 ? 'Ada' : null,
        loanDueAt: item.id == 1 ? t0 : null,
        createdAt: t0,
        updatedAt: t0,
      ),
  ];

  void phone(WidgetTester tester) {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
  }

  List<Override> overrides() => <Override>[
    libraryItemsProvider.overrideWith((Ref ref) async => items),
    allCopiesProvider.overrideWith((Ref ref) async => copies),
    activeLoansProvider.overrideWith(
      (Ref ref) async => copies.where((OwnedCopy c) => c.isLoaned).toList(),
    ),
    keepsakesProvider.overrideWith(
      (Ref ref) async => Keepsakes.compute(
        items: items,
        sessions: const <PlaySession>[],
        journalEntryCount: 0,
        copies: copies,
      ),
    ),
  ];

  group('CollectorScreen', () {
    testWidgets('builds the room with shelves on a phone', (
      WidgetTester tester,
    ) async {
      phone(tester);
      await tester.pumpApp(
        const CollectorScreen(),
        wrapInScaffold: true,
        overrides: overrides(),
      );
      expect(tester.takeException(), isNull);
      expect(find.byType(CollectorRoom), findsOneWidget);
    });

    testWidgets('every room theme lays out', (WidgetTester tester) async {
      phone(tester);
      for (final RoomTheme theme in RoomTheme.values) {
        await tester.pumpApp(
          SingleChildScrollView(
            child: CollectorRoom(
              items: items,
              keepsakes: Keepsakes.compute(
                items: items,
                sessions: const <PlaySession>[],
                journalEntryCount: 0,
                copies: copies,
              ),
              theme: theme,
            ),
          ),
          wrapInScaffold: true,
        );
        expect(tester.takeException(), isNull, reason: theme.name);
      }
    });

    testWidgets('lists loans with a return action', (
      WidgetTester tester,
    ) async {
      phone(tester);
      await tester.pumpApp(
        const CollectorScreen(),
        wrapInScaffold: true,
        overrides: overrides(),
      );
      await tester.tap(find.byType(Tab).last);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.byIcon(Icons.assignment_return_outlined), findsOneWidget);
    });
  });

  group('CopiesSection', () {
    testWidgets('shows copies and the lend action', (
      WidgetTester tester,
    ) async {
      phone(tester);
      await tester.pumpApp(
        const SingleChildScrollView(
          child: CopiesSection(
            itemId: 2,
            accentColor: Colors.teal,
            isEditable: true,
          ),
        ),
        wrapInScaffold: true,
        overrides: <Override>[
          itemCopiesProvider(
            2,
          ).overrideWith((Ref ref) async => <OwnedCopy>[copies[1]]),
        ],
      );
      expect(tester.takeException(), isNull);
      expect(find.byIcon(Icons.handshake_outlined), findsOneWidget);
    });

    testWidgets('read-only hides the actions', (WidgetTester tester) async {
      phone(tester);
      await tester.pumpApp(
        const SingleChildScrollView(
          child: CopiesSection(
            itemId: 2,
            accentColor: Colors.teal,
            isEditable: false,
          ),
        ),
        wrapInScaffold: true,
        overrides: <Override>[
          itemCopiesProvider(
            2,
          ).overrideWith((Ref ref) async => <OwnedCopy>[copies[1]]),
        ],
      );
      expect(find.byIcon(Icons.handshake_outlined), findsNothing);
      expect(find.byIcon(Icons.add), findsNothing);
    });
  });
}
