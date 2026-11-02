import 'package:core/models/collection.dart';
import 'package:core/models/collection_item.dart';
import 'package:core/models/item_status.dart';
import 'package:core/models/tag.dart';
import 'package:core/plus/models/smart_list.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tonkatsu_box/features/collections/providers/collections_provider.dart';
import 'package:tonkatsu_box/features/collections/providers/global_tags_provider.dart';
import 'package:tonkatsu_box/features/smart_lists/providers/smart_list_providers.dart';
import 'package:tonkatsu_box/features/smart_lists/screens/smart_list_editor_screen.dart';
import 'package:tonkatsu_box/features/smart_lists/screens/smart_list_screen.dart';
import 'package:tonkatsu_box/features/smart_lists/screens/smart_lists_screen.dart';

import '../../helpers/test_helpers.dart';

class _NoTags extends GlobalTagsNotifier {
  @override
  Future<List<Tag>> build() async => const <Tag>[];
}

class _NoCollections extends CollectionsNotifier {
  @override
  Future<List<Collection>> build() async => const <Collection>[];
}

void main() {
  final DateTime now = DateTime(2026, 5, 1);

  final List<CollectionItem> library = <CollectionItem>[
    createTestCollectionItem(id: 1),
    createTestCollectionItem(id: 2, status: ItemStatus.completed),
  ];

  final SmartList waiting = SmartList(
    id: 5,
    name: 'Waiting',
    rules: const SmartListRules(statuses: <ItemStatus>{ItemStatus.notStarted}),
    createdAt: now,
    updatedAt: now,
  );

  List<Override> overrides({List<SmartList> lists = const <SmartList>[]}) =>
      <Override>[
        smartListsProvider.overrideWith((Ref ref) async => lists),
        smartListContextProvider.overrideWith(
          (Ref ref) async => SmartListContext(
            items: library,
            tagIdsByItem: const <int, List<int>>{},
            gameSecondsById: const <int, int>{},
          ),
        ),
        globalTagsProvider.overrideWith(_NoTags.new),
        collectionsProvider.overrideWith(_NoCollections.new),
      ];

  void phone(WidgetTester tester) {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
  }

  group('SmartListsScreen', () {
    testWidgets('offers templates when there are no lists', (
      WidgetTester tester,
    ) async {
      phone(tester);
      await tester.pumpApp(
        const SmartListsScreen(),
        wrapInScaffold: true,
        overrides: overrides(),
      );
      expect(tester.takeException(), isNull);
      expect(find.byType(ActionChip), findsWidgets);
    });

    testWidgets('lists saved smart lists', (WidgetTester tester) async {
      phone(tester);
      await tester.pumpApp(
        const SmartListsScreen(),
        wrapInScaffold: true,
        overrides: overrides(lists: <SmartList>[waiting]),
      );
      expect(tester.takeException(), isNull);
      expect(find.text('Waiting'), findsOneWidget);
    });
  });

  group('SmartListScreen', () {
    testWidgets('shows the matching items', (WidgetTester tester) async {
      phone(tester);
      await tester.pumpApp(
        const SmartListScreen(listId: 5),
        overrides: overrides(lists: <SmartList>[waiting]),
      );
      expect(tester.takeException(), isNull);
      expect(find.byType(InkWell), findsWidgets);
    });
  });

  group('SmartListEditorScreen', () {
    testWidgets('keeps Save disabled until there is a name', (
      WidgetTester tester,
    ) async {
      phone(tester);
      await tester.pumpApp(
        const SmartListEditorScreen(),
        overrides: overrides(),
      );
      expect(tester.takeException(), isNull);
      final FilledButton save = tester.widget<FilledButton>(
        find.byType(FilledButton),
      );
      expect(save.onPressed, isNull);

      await tester.enterText(find.byType(TextField).first, 'Mine');
      await tester.pump();
      expect(
        tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
        isNotNull,
      );
    });
  });
}
