import 'package:core/models/collection_item.dart';
import 'package:core/models/item_status.dart';
import 'package:core/models/media_type.dart';
import 'package:core/models/profile.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tonkatsu_box/features/settings/providers/profile_provider.dart';
import 'package:tonkatsu_box/features/together/providers/together_providers.dart';
import 'package:tonkatsu_box/features/together/screens/together_screen.dart';
import 'package:tonkatsu_box/features/together/widgets/together_vote.dart';

import '../../helpers/test_helpers.dart';

void main() {
  final DateTime t0 = DateTime(2026, 6, 1);

  CollectionItem film(int id, String title, int runtime, ItemStatus status) =>
      createTestCollectionItem(
        id: id,
        mediaType: MediaType.movie,
        externalId: id,
        status: status,
        movie: createTestMovie(tmdbId: id, title: title, runtime: runtime),
      );

  final ProfilesData profiles = ProfilesData(
    version: 1,
    currentProfileId: 'me',
    profiles: <Profile>[
      Profile(id: 'me', name: 'Ada', color: '#EF7B44', createdAt: t0),
      Profile(id: 'bo', name: 'Bo', color: '#4488EE', createdAt: t0),
    ],
  );

  List<Override> overrides({Map<String, LibraryAccess>? access}) => <Override>[
    profilesDataProvider.overrideWith((Ref ref) => profiles),
    togetherLibrariesProvider.overrideWith(
      (Ref ref) async => TogetherLibraries(
        libraries: <String, List<CollectionItem>>{
          'me': <CollectionItem>[
            film(1, 'Alpha', 90, ItemStatus.planned),
            film(2, 'Beta', 100, ItemStatus.notStarted),
            film(3, 'Seen', 80, ItemStatus.completed),
          ],
        },
        access: access ?? <String, LibraryAccess>{'me': LibraryAccess.ready},
        gameSecondsById: const <int, int>{},
      ),
    ),
  ];

  void phone(WidgetTester tester) {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
  }

  Future<void> voteFor(WidgetTester tester, String favourite) async {
    while (find.byType(TogetherBallotCard).evaluate().isNotEmpty) {
      final bool isFavourite = find.text(favourite).evaluate().isNotEmpty;
      await tester.tap(
        find.byIcon(
          isFavourite ? Icons.favorite : Icons.thumb_down_alt_outlined,
        ),
      );
      await tester.pumpAndSettle();
    }
  }

  group('TogetherScreen', () {
    testWidgets('runs a vote between the user and a guest', (
      WidgetTester tester,
    ) async {
      phone(tester);
      await tester.pumpApp(
        const TogetherScreen(),
        wrapInScaffold: true,
        overrides: overrides(),
      );
      expect(tester.takeException(), isNull);
      expect(find.text('Seen'), findsNothing);

      await tester.tap(find.byIcon(Icons.person_add_alt));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'Cleo');
      await tester.tap(
        find
            .descendant(
              of: find.byType(AlertDialog),
              matching: find.byType(TextButton),
            )
            .last,
      );
      await tester.pumpAndSettle();
      expect(find.text('Cleo'), findsOneWidget);

      await tester.tap(find.byIcon(Icons.how_to_vote_outlined));
      await tester.pumpAndSettle();
      expect(find.byType(TogetherHandoff), findsOneWidget);

      for (int voter = 0; voter < 2; voter++) {
        await tester.tap(find.byType(FilledButton));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        await voteFor(tester, 'Beta');
      }

      expect(find.byType(TogetherBallotCard), findsNothing);
      expect(find.widgetWithText(ListTile, 'Alpha'), findsOneWidget);
      expect(find.widgetWithText(ListTile, 'Beta'), findsNothing);
      expect(find.text('Beta'), findsOneWidget);
    });

    testWidgets('undo steps back within one turn', (WidgetTester tester) async {
      phone(tester);
      await tester.pumpApp(
        const TogetherScreen(),
        wrapInScaffold: true,
        overrides: overrides(),
      );
      await tester.tap(find.byIcon(Icons.how_to_vote_outlined));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(FilledButton));
      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.undo), findsNothing);
      await tester.tap(find.byIcon(Icons.help_outline));
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.undo));
      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.undo), findsNothing);
    });

    testWidgets('flags a profile whose file is out of date', (
      WidgetTester tester,
    ) async {
      phone(tester);
      await tester.pumpApp(
        const TogetherScreen(),
        wrapInScaffold: true,
        overrides: overrides(
          access: <String, LibraryAccess>{
            'me': LibraryAccess.ready,
            'bo': LibraryAccess.outdated,
          },
        ),
      );
      await tester.tap(find.text('Bo'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.byIcon(Icons.warning_amber), findsOneWidget);
    });
  });
}
