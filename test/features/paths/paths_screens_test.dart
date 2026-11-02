import 'package:core/models/collection_item.dart';
import 'package:core/models/item_status.dart';
import 'package:core/models/media_type.dart';
import 'package:core/plus/analytics/path_walk.dart';
import 'package:core/plus/models/item_aspect.dart';
import 'package:core/plus/models/media_path.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tonkatsu_box/features/insights/providers/insights_providers.dart';
import 'package:tonkatsu_box/features/paths/providers/paths_providers.dart';
import 'package:tonkatsu_box/features/paths/screens/path_screen.dart';
import 'package:tonkatsu_box/features/paths/screens/paths_screen.dart';
import 'package:tonkatsu_box/features/paths/widgets/library_picker_sheet.dart';
import 'package:tonkatsu_box/features/paths/widgets/path_stop_tile.dart';
import 'package:tonkatsu_box/features/paths/widgets/paths_section.dart';

import '../../helpers/test_helpers.dart';

void main() {
  final DateTime t0 = DateTime(2026, 5, 1);

  CollectionItem work(
    int id,
    String name,
    ItemStatus status, {
    List<String>? genres,
    MediaType mediaType = MediaType.game,
  }) => createTestCollectionItem(
    id: id,
    status: status,
    mediaType: mediaType,
    game: createTestGame(id: id, name: name, genres: genres),
  );

  final List<CollectionItem> items = <CollectionItem>[
    work(1, 'Gundam 0079', ItemStatus.completed, genres: <String>['Mecha']),
    work(2, 'Gundam Zeta', ItemStatus.notStarted, genres: <String>['War']),
    work(3, 'Char Counterattack', ItemStatus.notStarted),
    work(4, 'Gundam Unicorn', ItemStatus.notStarted, genres: <String>['Mecha']),
  ];

  final MediaPath universe = MediaPath(
    id: 1,
    name: 'Universal Century',
    kind: PathKind.universe,
    defaultOrder: PathOrder.recommended,
    createdAt: t0,
    updatedAt: t0,
  );
  final MediaPath theme = MediaPath(
    id: 2,
    name: 'Cosmic dread',
    kind: PathKind.theme,
    defaultOrder: PathOrder.release,
    createdAt: t0,
    updatedAt: t0,
  );

  final List<PathEntry> entries = <PathEntry>[
    for (int i = 1; i <= 3; i++)
      PathEntry(
        id: i,
        pathId: 1,
        itemId: i,
        releasePos: i,
        chronoPos: 4 - i,
        recommendedPos: i,
        spoiler: i == 3,
        note: i == 3 ? 'secret note' : null,
      ),
  ];

  void phone(WidgetTester tester) {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
  }

  List<Override> overrides() => <Override>[
    libraryItemsProvider.overrideWith((Ref ref) async => items),
    pathsProvider.overrideWith((Ref ref) async => <MediaPath>[universe, theme]),
    pathEntriesProvider.overrideWith(
      (Ref ref, int id) async => id == 1 ? entries : const <PathEntry>[],
    ),
    allAspectTagsProvider.overrideWith(
      (Ref ref) async => <ItemAspectTag>[
        ItemAspectTag(
          id: 1,
          itemId: 3,
          aspect: PathAspect.atmosphere,
          label: 'melancholic',
          createdAt: t0,
        ),
      ],
    ),
  ];

  group('PathScreen', () {
    testWidgets('masks a spoiler stop until the user reveals it', (
      WidgetTester tester,
    ) async {
      phone(tester);
      await tester.pumpApp(const PathScreen(pathId: 1), overrides: overrides());
      expect(tester.takeException(), isNull);
      expect(find.byType(PathStopTile), findsNWidgets(3));
      expect(find.text('Char Counterattack'), findsNothing);
      expect(find.text('secret note'), findsNothing);

      await tester.tap(find.text('???'));
      await tester.pumpAndSettle();
      // The dialog's confirm button is the last one it lays out.
      await tester.tap(
        find
            .descendant(
              of: find.byType(AlertDialog),
              matching: find.byType(TextButton),
            )
            .last,
      );
      await tester.pumpAndSettle();
      expect(find.text('Char Counterattack'), findsOneWidget);
      expect(find.text('secret note'), findsOneWidget);
    });

    testWidgets('edit mode shows every stop with a drag handle', (
      WidgetTester tester,
    ) async {
      phone(tester);
      await tester.pumpApp(const PathScreen(pathId: 1), overrides: overrides());
      await tester.tap(find.byIcon(Icons.edit_note));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.byIcon(Icons.drag_handle), findsNWidgets(3));
      expect(find.text('Char Counterattack'), findsOneWidget);
    });

    testWidgets('an empty path lays out on a phone', (
      WidgetTester tester,
    ) async {
      phone(tester);
      await tester.pumpApp(const PathScreen(pathId: 2), overrides: overrides());
      expect(tester.takeException(), isNull);
      expect(find.byType(PathStopTile), findsNothing);
    });
  });

  group('PathsScreen', () {
    testWidgets('lists both kinds of paths and explores by theme', (
      WidgetTester tester,
    ) async {
      phone(tester);
      await tester.pumpApp(
        const PathsScreen(),
        wrapInScaffold: true,
        overrides: overrides(),
      );
      expect(tester.takeException(), isNull);
      expect(find.byType(PathCard), findsNWidgets(2));

      await tester.tap(find.byType(Tab).last);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      // The custom tag sits under the default aspect, atmosphere.
      await tester.tap(find.textContaining('melancholic'));
      await tester.pumpAndSettle();
      expect(find.text('Char Counterattack'), findsOneWidget);
      expect(find.text('Gundam Zeta'), findsNothing);
    });
  });

  group('PathsSection', () {
    testWidgets('shows the paths an item is on and its tags', (
      WidgetTester tester,
    ) async {
      phone(tester);
      final PathWalk walk = PathWalk.compute(
        entries: entries,
        items: <int, CollectionItem>{
          for (final CollectionItem i in items) i.id: i,
        },
        order: PathOrder.recommended,
      );
      await tester.pumpApp(
        SingleChildScrollView(
          child: PathsSection(
            item: items[1],
            accentColor: Colors.blue,
            isEditable: true,
          ),
        ),
        wrapInScaffold: true,
        overrides: <Override>[
          ...overrides(),
          itemPathsProvider.overrideWith(
            (Ref ref, int id) async => <ItemPathView>[
              ItemPathView(path: universe, walk: walk),
            ],
          ),
        ],
      );
      expect(tester.takeException(), isNull);
      expect(find.text(universe.name), findsOneWidget);
      expect(find.byType(InputChip), findsNothing);
      expect(find.byType(ActionChip), findsOneWidget);
    });

    testWidgets('hides itself on a read-only item with nothing to show', (
      WidgetTester tester,
    ) async {
      await tester.pumpApp(
        PathsSection(
          item: items[2],
          accentColor: Colors.blue,
          isEditable: false,
        ),
        wrapInScaffold: true,
        overrides: <Override>[
          ...overrides(),
          allAspectTagsProvider.overrideWith(
            (Ref ref) async => const <ItemAspectTag>[],
          ),
          itemPathsProvider.overrideWith(
            (Ref ref, int id) async => const <ItemPathView>[],
          ),
        ],
      );
      expect(find.byType(ListTile), findsNothing);
      expect(find.byType(Chip), findsNothing);
    });
  });

  group('showLibraryPicker', () {
    testWidgets('offers works matching the path name and returns them', (
      WidgetTester tester,
    ) async {
      phone(tester);
      List<CollectionItem>? picked;
      await tester.pumpApp(
        Builder(
          builder: (BuildContext context) => TextButton(
            onPressed: () async {
              picked = await showLibraryPicker(
                context,
                pathName: 'gundam',
                exclude: <int>{4},
              );
            },
            child: const Text('open'),
          ),
        ),
        wrapInScaffold: true,
        overrides: overrides(),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text('Gundam Unicorn'), findsNothing);

      // "Select all" sits next to the suggested header.
      await tester.tap(find.byType(TextButton).last);
      await tester.pump();
      await tester.tap(find.byIcon(Icons.playlist_add));
      await tester.pumpAndSettle();
      expect(picked?.map((CollectionItem i) => i.id).toSet(), <int>{1, 2});
    });
  });
}
