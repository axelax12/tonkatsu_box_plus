import 'package:core/models/collection_item.dart';
import 'package:core/models/item_status.dart';
import 'package:core/models/media_type.dart';
import 'package:core/plus/analytics/smart_list_evaluator.dart';
import 'package:core/plus/database/smart_list_dao.dart';
import 'package:core/plus/models/smart_list.dart';
import 'package:core/testing/builders.dart';
import 'package:test/test.dart';

import 'plus_test_db.dart';

void main() {
  final DateTime now = DateTime(2026, 6, 1);

  List<int> ids(List<CollectionItem> items) =>
      items.map((CollectionItem i) => i.id).toList();

  group('SmartListRules', () {
    test('round-trips through JSON', () {
      const SmartListRules rules = SmartListRules(
        mediaTypes: <MediaType>{MediaType.game, MediaType.book},
        statuses: <ItemStatus>{ItemStatus.notStarted},
        tagIds: <int>{3},
        collectionIds: <int>{9},
        minMinutes: 10,
        maxMinutes: 600,
        maxUnitsLeft: 5,
        minRating: 7,
        minAgeDays: 365,
        favoritesOnly: true,
        neverStarted: true,
        text: 'souls',
        sort: SmartListSort.shortestFirst,
      );
      final SmartListRules back = SmartListRules.fromJson(rules.toJson());
      expect(back.mediaTypes, rules.mediaTypes);
      expect(back.statuses, rules.statuses);
      expect(back.tagIds, rules.tagIds);
      expect(back.collectionIds, rules.collectionIds);
      expect(back.maxMinutes, 600);
      expect(back.minMinutes, 10);
      expect(back.maxUnitsLeft, 5);
      expect(back.minRating, 7);
      expect(back.minAgeDays, 365);
      expect(back.favoritesOnly, isTrue);
      expect(back.neverStarted, isTrue);
      expect(back.text, 'souls');
      expect(back.sort, SmartListSort.shortestFirst);
      expect(back.needsLengths, isTrue);
    });

    test('ignores unknown values and junk', () {
      final SmartListRules rules = SmartListRules.fromJson(<String, dynamic>{
        'media_types': <dynamic>['game', 'hologram', 4],
        'statuses': 'nope',
        'sort': 'sideways',
      });
      expect(rules.mediaTypes, <MediaType>{MediaType.game});
      expect(rules.statuses, isEmpty);
      expect(rules.sort, SmartListSort.addedOldest);
      expect(rules.needsLengths, isFalse);
    });

    test('a corrupt row reads as an empty rule set', () {
      final SmartList list = SmartList.fromDb(<String, dynamic>{
        'id': 1,
        'name': 'x',
        'rules': '{not json',
        'created_at': 0,
        'updated_at': 0,
      });
      expect(list.rules.mediaTypes, isEmpty);
    });
  });

  group('SmartListEvaluator', () {
    final List<CollectionItem> library = <CollectionItem>[
      createTestCollectionItem(
        id: 1,
        externalId: 11,
        addedAt: DateTime(2024, 1, 1),
      ),
      createTestCollectionItem(
        id: 2,
        externalId: 22,
        addedAt: DateTime(2026, 5, 1),
        isFavorite: true,
      ),
      createTestCollectionItem(
        id: 3,
        mediaType: MediaType.anime,
        status: ItemStatus.dropped,
        currentEpisode: 22,
        startedAt: DateTime(2025, 1, 1),
        anime: createTestAnime(episodes: 25),
        addedAt: DateTime(2025, 1, 1),
      ),
      createTestCollectionItem(
        id: 4,
        mediaType: MediaType.book,
        status: ItemStatus.completed,
        userRating: 9,
        book: createTestBook(
          title: 'Kafka on the Shore',
          authors: const <String>['Haruki Murakami'],
          pageCount: 500,
        ),
        addedAt: DateTime(2023, 1, 1),
      ),
    ];

    test('an empty rule set keeps everything, oldest first', () {
      expect(
        ids(SmartListEvaluator.apply(const SmartListRules(), library, now: now)),
        <int>[4, 1, 3, 2],
      );
    });

    test('short games in the backlog, shortest first', () {
      const SmartListRules rules = SmartListRules(
        mediaTypes: <MediaType>{MediaType.game},
        statuses: <ItemStatus>{ItemStatus.notStarted},
        maxMinutes: 600,
        sort: SmartListSort.shortestFirst,
      );
      final List<CollectionItem> found = SmartListEvaluator.apply(
        rules,
        library,
        now: now,
        gameSecondsById: const <int, int>{11: 30000, 22: 3600},
      );
      expect(ids(found), <int>[2, 1]);
    });

    test('games without a known length never pass a length rule', () {
      expect(
        SmartListEvaluator.apply(
          const SmartListRules(maxMinutes: 600),
          library
              .where((CollectionItem i) => i.mediaType == MediaType.game)
              .toList(),
          now: now,
        ),
        isEmpty,
      );
    });

    test('dropped anime close to the end', () {
      expect(
        ids(
          SmartListEvaluator.apply(
            const SmartListRules(
              statuses: <ItemStatus>{ItemStatus.dropped},
              maxUnitsLeft: 5,
            ),
            library,
            now: now,
          ),
        ),
        <int>[3],
      );
    });

    test('matches text on authors, case-insensitively', () {
      expect(
        ids(
          SmartListEvaluator.apply(
            const SmartListRules(text: 'murakami'),
            library,
            now: now,
          ),
        ),
        <int>[4],
      );
    });

    test('tags, favorites, rating, age and never started', () {
      expect(
        ids(
          SmartListEvaluator.apply(
            const SmartListRules(tagIds: <int>{5}),
            library,
            now: now,
            tagIdsByItem: const <int, List<int>>{
              1: <int>[5],
              2: <int>[6],
            },
          ),
        ),
        <int>[1],
      );
      expect(
        ids(
          SmartListEvaluator.apply(
            const SmartListRules(favoritesOnly: true),
            library,
            now: now,
          ),
        ),
        <int>[2],
      );
      expect(
        ids(
          SmartListEvaluator.apply(
            const SmartListRules(minRating: 8),
            library,
            now: now,
          ),
        ),
        <int>[4],
      );
      expect(
        ids(
          SmartListEvaluator.apply(
            const SmartListRules(minAgeDays: 365, neverStarted: true),
            library,
            now: now,
          ),
        ),
        <int>[4, 1],
      );
    });

    test('sorts by rating and by name', () {
      expect(
        ids(
          SmartListEvaluator.apply(
            const SmartListRules(sort: SmartListSort.ratingHighest),
            library,
            now: now,
          ),
        ).first,
        4,
      );
      expect(
        SmartListEvaluator.apply(
          const SmartListRules(sort: SmartListSort.nameAsc),
          library,
          now: now,
        ),
        hasLength(4),
      );
    });

    test('unitsLeft needs a started item with a known total', () {
      expect(SmartListEvaluator.unitsLeft(library[2]), 3);
      expect(SmartListEvaluator.unitsLeft(library[0]), isNull);
      expect(
        SmartListEvaluator.unitsLeft(
          createTestCollectionItem(
            mediaType: MediaType.book,
            currentEpisode: 600,
            book: createTestBook(pageCount: 500),
          ),
        ),
        0,
      );
    });
  });

  group('SmartListDao', () {
    late PlusTestDb t;
    late SmartListDao dao;

    setUp(() async {
      t = await PlusTestDb.open();
      dao = SmartListDao(() async => t.db);
    });
    tearDown(() async => t.close());

    SmartList draft(String name) => SmartList(
      id: 0,
      name: name,
      rules: const SmartListRules(statuses: <ItemStatus>{ItemStatus.planned}),
      createdAt: now,
      updatedAt: now,
    );

    test('saves at the end, reorders, updates and deletes', () async {
      final SmartList a = await dao.save(draft('A'));
      final SmartList b = await dao.save(draft('B'));
      expect(b.sortOrder, a.sortOrder + 1);

      await dao.reorder(<int>[b.id, a.id]);
      expect(
        (await dao.getAll()).map((SmartList l) => l.name),
        <String>['B', 'A'],
      );

      await dao.save(a.copyWith(name: 'A2'));
      expect((await dao.getById(a.id))?.name, 'A2');
      expect(
        (await dao.getById(a.id))?.rules.statuses,
        <ItemStatus>{ItemStatus.planned},
      );

      await dao.delete(a.id);
      expect(await dao.getById(a.id), isNull);
      expect(await dao.getAll(), hasLength(1));
    });
  });
}
