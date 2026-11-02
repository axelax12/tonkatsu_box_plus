import 'package:core/models/collection_item.dart';
import 'package:core/models/data_source.dart';
import 'package:core/models/item_status.dart';
import 'package:core/models/media_type.dart';
import 'package:core/plus/analytics/path_walk.dart';
import 'package:core/plus/analytics/theme_index.dart';
import 'package:core/plus/database/aspects_dao.dart';
import 'package:core/plus/database/paths_dao.dart';
import 'package:core/plus/models/item_aspect.dart';
import 'package:core/plus/models/media_path.dart';
import 'package:core/testing/builders.dart';
import 'package:test/test.dart';

import 'plus_test_db.dart';

void main() {
  final DateTime t0 = DateTime(2026, 3, 1);

  MediaPath newPath(String name, {PathKind kind = PathKind.universe}) =>
      MediaPath(
        id: 0,
        name: name,
        kind: kind,
        defaultOrder: PathOrder.recommended,
        createdAt: t0,
        updatedAt: t0,
      );

  PathEntry entry(
    int id,
    int itemId, {
    int? pos,
    int? chrono,
    bool optional = false,
    bool spoiler = false,
  }) => PathEntry(
    id: id,
    pathId: 1,
    itemId: itemId,
    releasePos: pos ?? id,
    chronoPos: chrono ?? id,
    recommendedPos: pos ?? id,
    optional: optional,
    spoiler: spoiler,
  );

  CollectionItem item(
    int id,
    ItemStatus status, {
    String name = 'Work',
    int? year,
    List<String>? genres,
  }) => createTestCollectionItem(
    id: id,
    externalId: id,
    status: status,
    game: createTestGame(
      id: id,
      name: name,
      releaseDate: year == null ? null : DateTime(year),
      genres: genres,
    ),
  );

  group('PathEntry / MediaPath', () {
    test('round-trip through rows and fall back on unknown values', () {
      final PathEntry e = entry(
        4,
        9,
        optional: true,
        spoiler: true,
      ).copyWith(note: 'side story', aspect: PathAspect.setting);
      final PathEntry back = PathEntry.fromDb(<String, dynamic>{
        ...e.toDb(),
        'id': 4,
      });
      expect(back.optional, isTrue);
      expect(back.spoiler, isTrue);
      expect(back.note, 'side story');
      expect(back.aspect, PathAspect.setting);
      expect(back.copyWith(clearNote: true, clearAspect: true).note, isNull);
      expect(e.withPosition(PathOrder.chronological, 7).chronoPos, 7);
      expect(
        e.withPosition(PathOrder.release, 2).positionFor(PathOrder.release),
        2,
      );
      expect(e.withPosition(PathOrder.recommended, 3).recommendedPos, 3);

      expect(PathKind.fromString('theme'), PathKind.theme);
      expect(PathKind.fromString('???'), PathKind.universe);
      expect(PathOrder.fromString('nope'), PathOrder.recommended);
      expect(PathAspect.tryFromString(null), isNull);

      final MediaPath p = MediaPath.fromDb(<String, dynamic>{
        ...newPath('Gundam').copyWith(description: 'd').toDb(),
        'id': 2,
      });
      expect(p.id, 2);
      expect(p.description, 'd');
      expect(p.copyWith(clearDescription: true).description, isNull);
    });
  });

  group('PathWalk', () {
    test('marks done, active and next, and masks unreached spoilers', () {
      final PathWalk walk = PathWalk.compute(
        entries: <PathEntry>[
          entry(3, 30, spoiler: true),
          entry(1, 10),
          entry(2, 20, optional: true),
          entry(4, 40, spoiler: true),
        ],
        items: <int, CollectionItem>{
          10: item(10, ItemStatus.completed),
          20: item(20, ItemStatus.notStarted),
          30: item(30, ItemStatus.notStarted),
          40: item(40, ItemStatus.notStarted),
        },
        order: PathOrder.recommended,
      );
      expect(walk.stops.map((PathStop s) => s.entry.itemId), <int>[
        10,
        20,
        30,
        40,
      ]);
      expect(walk.stops[0].state, StopState.done);
      expect(walk.stops[1].state, StopState.upcoming);
      expect(walk.stops[2].state, StopState.next);
      expect(walk.stops[2].hidden, isFalse, reason: 'optional never blocks');
      expect(walk.stops[3].hidden, isTrue);
      expect(walk.current?.entry.itemId, 30);
      expect(walk.requiredDone, 1);
      expect(walk.requiredTotal, 3);
      expect(walk.optionalTotal, 1);
      expect(walk.fraction, closeTo(1 / 3, 1e-9));
      expect(walk.isComplete, isFalse);
      expect(walk.indexOfItem(40), 3);
    });

    test('an active stop is current and a replay is not done twice', () {
      final PathWalk walk = PathWalk.compute(
        entries: <PathEntry>[entry(1, 10), entry(2, 20), entry(3, 30)],
        items: <int, CollectionItem>{
          10: item(10, ItemStatus.replaying),
          20: item(20, ItemStatus.inProgress),
          30: item(30, ItemStatus.planned),
        },
        order: PathOrder.release,
      );
      expect(walk.stops[0].state, StopState.inProgress);
      expect(walk.stops[1].state, StopState.inProgress);
      expect(walk.stops[2].state, StopState.upcoming);
      expect(walk.current?.entry.itemId, 10);
      expect(walk.requiredDone, 1);
    });

    test('follows the chosen order and reports completion', () {
      final List<PathEntry> entries = <PathEntry>[
        entry(1, 10, chrono: 1),
        entry(2, 20, chrono: 0),
      ];
      final Map<int, CollectionItem> items = <int, CollectionItem>{
        10: item(10, ItemStatus.completed),
        20: item(20, ItemStatus.completed),
      };
      final PathWalk walk = PathWalk.compute(
        entries: entries,
        items: items,
        order: PathOrder.chronological,
      );
      expect(walk.stops.first.entry.itemId, 20);
      expect(walk.isComplete, isTrue);
      expect(walk.current, isNull);

      final PathWalk empty = PathWalk.compute(
        entries: const <PathEntry>[],
        items: items,
        order: PathOrder.recommended,
      );
      expect(empty.fraction, 0);
      expect(empty.isComplete, isFalse);
    });

    test('an optional stop in progress is current only as a last resort', () {
      final PathWalk walk = PathWalk.compute(
        entries: <PathEntry>[entry(1, 10, optional: true)],
        items: <int, CollectionItem>{10: item(10, ItemStatus.inProgress)},
        order: PathOrder.recommended,
      );
      expect(walk.current?.entry.itemId, 10);
      expect(walk.stops.single.item, isNotNull);
    });
  });

  group('PathSuggestions', () {
    test('matches every word of the name, oldest first', () {
      final List<CollectionItem> library = <CollectionItem>[
        item(1, ItemStatus.notStarted, name: 'Gundam Wing', year: 1995),
        item(2, ItemStatus.notStarted, name: 'Mobile Suit Gundam', year: 1979),
        item(3, ItemStatus.notStarted, name: 'Gundam: Witch', year: 2022),
        item(4, ItemStatus.notStarted, name: 'Macross', year: 1982),
        item(5, ItemStatus.notStarted, name: 'Gundam Unknown'),
      ];
      final List<CollectionItem> hits = PathSuggestions.byTitle(
        'GUNDAM',
        library,
        exclude: <int>{3},
      );
      expect(hits.map((CollectionItem i) => i.id), <int>[2, 1, 5]);
      expect(PathSuggestions.byTitle('a b', library), isEmpty);
      expect(
        PathSuggestions.byTitle('gundam', library, limit: 1),
        hasLength(1),
      );
      expect(PathSuggestions.releaseOrder(library.reversed), <int>[
        2,
        4,
        1,
        3,
        5,
      ]);
    });
  });

  group('PathSuggestions.bySeries', () {
    test('finds library games sharing a franchise or collection', () {
      final List<CollectionItem> library = <CollectionItem>[
        item(1, ItemStatus.completed, name: 'Halo', year: 2001),
        item(2, ItemStatus.notStarted, name: 'Halo 3', year: 2007),
        item(3, ItemStatus.notStarted, name: 'ODST', year: 2009),
        item(4, ItemStatus.notStarted, name: 'Doom', year: 1993),
        createTestCollectionItem(
          id: 5,
          externalId: 2,
          status: ItemStatus.planned,
          game: createTestGame(id: 2, name: 'Halo 3'),
        ),
      ];
      final Map<int, Set<String>> tokens = <int, Set<String>>{
        1: <String>{'f:7'},
        2: <String>{'f:7', 'c:1'},
        3: <String>{'c:1'},
        4: <String>{'f:9'},
      };
      final List<CollectionItem> hits = PathSuggestions.bySeries(
        seeds: <CollectionItem>[library.first],
        library: library,
        tokens: tokens,
        exclude: <int>{1},
      );
      expect(hits.map((CollectionItem i) => i.id), <int>[2]);
      expect(
        PathSuggestions.bySeries(
          seeds: <CollectionItem>[library[1]],
          library: library,
          tokens: tokens,
          exclude: <int>{2},
        ).map((CollectionItem i) => i.id),
        <int>[1, 3, 5],
      );
      expect(
        PathSuggestions.bySeries(
          seeds: <CollectionItem>[library[3]],
          library: library,
          tokens: const <int, Set<String>>{},
        ),
        isEmpty,
      );
    });
  });

  group('PathSuggestions.byRelations', () {
    CollectionItem anime(int id, {DataSource source = DataSource.anilist}) =>
        createTestCollectionItem(
          id: id,
          externalId: id,
          mediaType: MediaType.anime,
          source: source,
          anime: createTestAnime(id: id, title: 'A$id', source: source),
        );

    test('walks relations through the library only', () {
      final List<CollectionItem> library = <CollectionItem>[
        anime(1),
        anime(2),
        anime(3),
        anime(4),
        anime(5, source: DataSource.kitsu),
      ];
      final Map<String, Set<String>> related = <String, Set<String>>{
        'anime:1': <String>{'anime:2', 'manga:9'},
        'anime:2': <String>{'anime:3'},
        'anime:4': <String>{'anime:8'},
        'anime:8': <String>{'anime:5'},
      };
      final List<CollectionItem> hits = PathSuggestions.byRelations(
        seeds: <CollectionItem>[library.first],
        library: library,
        related: related,
        exclude: <int>{1},
      );
      expect(hits.map((CollectionItem i) => i.id).toSet(), <int>{2, 3});
      expect(PathSuggestions.aniListKey(library[4]), isNull);
      expect(
        PathSuggestions.byRelations(
          seeds: <CollectionItem>[library[4]],
          library: library,
          related: related,
        ),
        isEmpty,
      );
    });
  });

  group('PathSuggestions.byCollection', () {
    CollectionItem film(int id, int year) => createTestCollectionItem(
      id: id,
      externalId: id,
      mediaType: MediaType.movie,
      movie: createTestMovie(tmdbId: id, releaseYear: year),
    );

    test('finds library films of the same TMDB collection', () {
      final List<CollectionItem> library = <CollectionItem>[
        film(120, 2001),
        film(121, 2002),
        film(122, 2003),
        film(999, 1999),
        item(5, ItemStatus.notStarted),
      ];
      final List<CollectionItem> hits = PathSuggestions.byCollection(
        seeds: <CollectionItem>[library[1]],
        library: library,
        siblings: <int, Set<String>>{
          121: <String>{'movie:120', 'movie:122'},
        },
        exclude: <int>{121},
      );
      expect(hits.map((CollectionItem i) => i.id), <int>[120, 122]);
      expect(PathSuggestions.isTmdbMovie(library.last), isFalse);
      expect(
        PathSuggestions.byCollection(
          seeds: <CollectionItem>[library[3]],
          library: library,
          siblings: const <int, Set<String>>{},
        ),
        isEmpty,
      );
    });
  });

  group('ThemeIndex', () {
    test('derives themes from genres by whole words', () {
      expect(
        ThemeIndex.themesFor(<String>[
          'Sci-Fi & Fantasy',
          'Role-playing (RPG)',
        ]),
        <BuiltInTheme>{
          BuiltInTheme.space,
          BuiltInTheme.fantasyWorlds,
          BuiltInTheme.rolePlaying,
        },
      );
      expect(ThemeIndex.themesFor(<String>['Software', 'Award']), isEmpty);
    });

    test('groups library items under built-in and custom tags', () {
      final List<CollectionItem> items = <CollectionItem>[
        item(1, ItemStatus.completed, genres: <String>['Horror', 'Drama']),
        item(2, ItemStatus.notStarted, genres: <String>['Survival Horror']),
        item(3, ItemStatus.notStarted),
      ];
      final ThemeIndex index = ThemeIndex.build(
        items: items,
        tags: <ItemAspectTag>[
          ItemAspectTag(
            id: 1,
            itemId: 3,
            aspect: PathAspect.atmosphere,
            label: 'Melancholic',
            createdAt: t0,
          ),
          ItemAspectTag(
            id: 2,
            itemId: 1,
            aspect: PathAspect.atmosphere,
            label: 'melancholic',
            createdAt: t0,
          ),
          ItemAspectTag(
            id: 3,
            itemId: 99,
            aspect: PathAspect.setting,
            label: 'orphan',
            createdAt: t0,
          ),
        ],
      );
      final List<ThemeKey> atmosphere = index.keysFor(PathAspect.atmosphere);
      expect(atmosphere.first, const ThemeKey.builtIn(BuiltInTheme.dark));
      expect(index.itemsFor(atmosphere.first), hasLength(2));
      expect(
        atmosphere,
        contains(const ThemeKey.custom(PathAspect.atmosphere, 'MELANCHOLIC')),
      );
      expect(
        index.itemsFor(
          const ThemeKey.custom(PathAspect.atmosphere, 'melancholic'),
        ),
        hasLength(2),
      );
      expect(index.keysFor(PathAspect.setting), isEmpty);
      expect(index.isEmpty, isFalse);
      expect(
        const ThemeKey.custom(PathAspect.themes, 'x').aspectOf,
        PathAspect.themes,
      );
    });
  });

  group('PathsDao', () {
    late PlusTestDb t;
    late PathsDao dao;

    setUp(() async {
      t = await PlusTestDb.open();
      dao = PathsDao(() async => t.db);
    });
    tearDown(() async => t.close());

    test('adds items once, reorders one order, and cascades', () async {
      final int a = await t.newItem(externalId: 1);
      final int b = await t.newItem(externalId: 2);
      final int c = await t.newItem(externalId: 3);
      final MediaPath path = await dao.savePath(newPath('Gundam'));
      expect(path.id, greaterThan(0));

      await dao.addItems(path.id, <int>[a, b]);
      await dao.addItems(path.id, <int>[b, c]);
      await dao.addItems(path.id, <int>[]);
      List<PathEntry> entries = await dao.getEntries(path.id);
      expect(entries.map((PathEntry e) => e.itemId), <int>[a, b, c]);
      expect(entries.map((PathEntry e) => e.releasePos), <int>[0, 1, 2]);

      await dao.reorder(PathOrder.chronological, <int>[
        entries[2].id,
        entries[0].id,
        entries[1].id,
      ]);
      entries = await dao.getEntries(path.id);
      expect(entries.map((PathEntry e) => e.chronoPos), <int>[1, 2, 0]);
      expect(entries.map((PathEntry e) => e.recommendedPos), <int>[0, 1, 2]);

      await dao.updateEntry(entries.first.copyWith(optional: true, note: 'n'));
      expect((await dao.getEntries(path.id)).first.optional, isTrue);

      await dao.savePath(path.copyWith(name: 'Gundam UC', updatedAt: t0));
      expect((await dao.getPaths()).single.name, 'Gundam UC');
      expect(await dao.getPaths(kind: PathKind.theme), isEmpty);
      expect((await dao.getPathsForItem(b)).single.id, path.id);

      await t.db.delete(
        'collection_items',
        where: 'id = ?',
        whereArgs: <int>[a],
      );
      expect(await dao.getEntries(path.id), hasLength(2));
      await dao.removeEntry(entries[1].id);
      expect(await dao.getAllEntries(), hasLength(1));
      await dao.insertEntries(<PathEntry>[]);
      await dao.insertEntries(<PathEntry>[
        PathEntry(
          id: 42,
          pathId: path.id,
          itemId: c,
          releasePos: 5,
          chronoPos: 6,
          recommendedPos: 7,
          spoiler: true,
        ),
      ]);
      expect(
        (await dao.getEntries(path.id)).map((PathEntry e) => e.itemId),
        <int>[c],
        reason: 'the duplicate for c is ignored',
      );
      await dao.deletePath(path.id);
      expect(await dao.getAllEntries(), isEmpty);
    });
  });

  group('AspectsDao', () {
    late PlusTestDb t;
    late AspectsDao dao;

    setUp(() async {
      t = await PlusTestDb.open();
      dao = AspectsDao(() async => t.db);
    });
    tearDown(() async => t.close());

    test('normalizes labels, ignores blanks and duplicates', () async {
      final int a = await t.newItem();
      expect(
        await dao.add(
          itemId: a,
          aspect: PathAspect.atmosphere,
          label: '  rainy   nights ',
          now: t0,
        ),
        isTrue,
      );
      expect(
        await dao.add(
          itemId: a,
          aspect: PathAspect.atmosphere,
          label: 'Rainy Nights',
          now: t0,
        ),
        isFalse,
      );
      expect(
        await dao.add(
          itemId: a,
          aspect: PathAspect.setting,
          label: '  ',
          now: t0,
        ),
        isFalse,
      );
      final List<ItemAspectTag> tags = await dao.getForItem(a);
      expect(tags.single.label, 'rainy nights');
      expect(await dao.getAll(), hasLength(1));
      expect(
        AspectsDao.normalizeLabel('x' * 60).length,
        AspectsDao.maxLabelLength,
      );
      await dao.remove(tags.single.id);
      expect(await dao.getForItem(a), isEmpty);
    });
  });
}
