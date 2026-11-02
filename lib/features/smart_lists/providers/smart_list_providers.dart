import 'package:core/models/collection_item.dart';
import 'package:core/models/media_type.dart';
import 'package:core/plus/analytics/smart_list_evaluator.dart';
import 'package:core/plus/database/goals_dao.dart';
import 'package:core/plus/database/smart_list_dao.dart';
import 'package:core/plus/models/smart_list.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/database_service.dart';
import '../../insights/providers/insights_providers.dart';

final Provider<SmartListDao> smartListDaoProvider = Provider<SmartListDao>((
  Ref ref,
) {
  final DatabaseService db = ref.watch(databaseServiceProvider);
  return SmartListDao(() => db.database);
});

final FutureProvider<List<SmartList>> smartListsProvider =
    FutureProvider<List<SmartList>>(
      (Ref ref) => ref.watch(smartListDaoProvider).getAll(),
    );

/// Everything a rule needs besides the rule itself, loaded once and shared by
/// the lists, the detail screen and the editor's live preview.
class SmartListContext {
  const SmartListContext({
    required this.items,
    required this.tagIdsByItem,
    required this.gameSecondsById,
  });

  final List<CollectionItem> items;
  final Map<int, List<int>> tagIdsByItem;
  final Map<int, int> gameSecondsById;

  List<CollectionItem> apply(SmartListRules rules) => SmartListEvaluator.apply(
    rules,
    items,
    now: DateTime.now(),
    tagIdsByItem: tagIdsByItem,
    gameSecondsById: gameSecondsById,
  );
}

final FutureProvider<SmartListContext> smartListContextProvider =
    FutureProvider<SmartListContext>((Ref ref) async {
      final List<CollectionItem> items = await ref.watch(
        libraryItemsProvider.future,
      );
      final Map<int, List<int>> tags = await ref
          .read(globalTagDaoProvider)
          .getAllItemTags();
      final List<int> gameIds = <int>{
        for (final CollectionItem i in items)
          if (i.mediaType == MediaType.game) i.externalId,
      }.toList();
      final GoalsDao goals = ref.read(goalsDaoProvider);
      // Lengths come from the shared cache; missing ones are fetched once here.
      await refreshTimeToBeat(ref, goals, gameIds, DateTime.now());
      return SmartListContext(
        items: items,
        tagIdsByItem: tags,
        gameSecondsById: await goals.getTimeToBeat(gameIds),
      );
    });

final FutureProviderFamily<List<CollectionItem>, int> smartListItemsProvider =
    FutureProvider.family<List<CollectionItem>, int>((Ref ref, int id) async {
      final List<SmartList> lists = await ref.watch(smartListsProvider.future);
      final SmartList? list = lists
          .where((SmartList l) => l.id == id)
          .firstOrNull;
      if (list == null) return <CollectionItem>[];
      final SmartListContext context = await ref.watch(
        smartListContextProvider.future,
      );
      return context.apply(list.rules);
    });

final Provider<SmartListController> smartListControllerProvider =
    Provider<SmartListController>(SmartListController.new);

class SmartListController {
  SmartListController(this._ref);

  final Ref _ref;

  Future<SmartList> save(SmartList list) async {
    final SmartList saved = await _ref.read(smartListDaoProvider).save(list);
    _ref.invalidate(smartListsProvider);
    return saved;
  }

  Future<void> delete(SmartList list) async {
    await _ref.read(smartListDaoProvider).delete(list.id);
    _ref.invalidate(smartListsProvider);
  }

  Future<void> reorder(List<int> orderedIds) async {
    await _ref.read(smartListDaoProvider).reorder(orderedIds);
    _ref.invalidate(smartListsProvider);
  }
}
