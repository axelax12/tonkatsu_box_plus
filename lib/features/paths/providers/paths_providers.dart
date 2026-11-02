import 'package:core/models/collection_item.dart';
import 'package:core/models/media_type.dart';
import 'package:core/plus/analytics/path_exchange.dart';
import 'package:core/plus/analytics/path_walk.dart';
import 'package:core/plus/analytics/theme_index.dart';
import 'package:core/plus/database/aspects_dao.dart';
import 'package:core/plus/database/paths_dao.dart';
import 'package:core/plus/models/item_aspect.dart';
import 'package:core/plus/models/media_path.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logging/logging.dart';

import '../../../core/api/anilist_api.dart';
import '../../../core/api/igdb_api.dart';
import '../../../core/api/tmdb_api.dart';
import '../../../core/database/database_service.dart';
import '../../insights/providers/insights_providers.dart';

final Provider<PathsDao> pathsDaoProvider = Provider<PathsDao>((Ref ref) {
  final DatabaseService db = ref.watch(databaseServiceProvider);
  return PathsDao(() => db.database);
});

final Provider<AspectsDao> aspectsDaoProvider = Provider<AspectsDao>((Ref ref) {
  final DatabaseService db = ref.watch(databaseServiceProvider);
  return AspectsDao(() => db.database);
});

final FutureProvider<List<MediaPath>> pathsProvider =
    FutureProvider<List<MediaPath>>(
      (Ref ref) => ref.watch(pathsDaoProvider).getPaths(),
    );

final FutureProviderFamily<List<PathEntry>, int> pathEntriesProvider =
    FutureProvider.family<List<PathEntry>, int>((Ref ref, int pathId) {
      ref.watch(pathsProvider);
      return ref.read(pathsDaoProvider).getEntries(pathId);
    });

final FutureProvider<Map<int, CollectionItem>> libraryByIdProvider =
    FutureProvider<Map<int, CollectionItem>>((Ref ref) async {
      final List<CollectionItem> items = await ref.watch(
        libraryItemsProvider.future,
      );
      return <int, CollectionItem>{
        for (final CollectionItem i in items) i.id: i,
      };
    });

/// The order a path is being walked in; starts at the path's own default.
class PathOrderNotifier extends FamilyNotifier<PathOrder?, int> {
  @override
  PathOrder? build(int pathId) => null;

  void select(PathOrder order) => state = order;
}

final NotifierProviderFamily<PathOrderNotifier, PathOrder?, int>
pathOrderProvider = NotifierProvider.family<PathOrderNotifier, PathOrder?, int>(
  PathOrderNotifier.new,
);

typedef PathWalkKey = ({int pathId, PathOrder order});

final FutureProviderFamily<PathWalk, PathWalkKey> pathWalkProvider =
    FutureProvider.family<PathWalk, PathWalkKey>((
      Ref ref,
      PathWalkKey key,
    ) async {
      final List<PathEntry> entries = await ref.watch(
        pathEntriesProvider(key.pathId).future,
      );
      final Map<int, CollectionItem> items = await ref.watch(
        libraryByIdProvider.future,
      );
      return PathWalk.compute(entries: entries, items: items, order: key.order);
    });

/// A path as seen from one of its works: where that work sits and what is next.
class ItemPathView {
  const ItemPathView({required this.path, required this.walk});

  final MediaPath path;
  final PathWalk walk;
}

final FutureProviderFamily<List<ItemPathView>, int> itemPathsProvider =
    FutureProvider.family<List<ItemPathView>, int>((Ref ref, int itemId) async {
      ref.watch(pathsProvider);
      final List<MediaPath> paths = await ref
          .read(pathsDaoProvider)
          .getPathsForItem(itemId);
      final List<ItemPathView> views = <ItemPathView>[];
      for (final MediaPath path in paths) {
        final PathWalk walk = await ref.watch(
          pathWalkProvider((pathId: path.id, order: path.defaultOrder)).future,
        );
        views.add(ItemPathView(path: path, walk: walk));
      }
      return views;
    });

final FutureProvider<List<ItemAspectTag>> allAspectTagsProvider =
    FutureProvider<List<ItemAspectTag>>(
      (Ref ref) => ref.watch(aspectsDaoProvider).getAll(),
    );

final FutureProviderFamily<List<ItemAspectTag>, int> itemAspectTagsProvider =
    FutureProvider.family<List<ItemAspectTag>, int>((
      Ref ref,
      int itemId,
    ) async {
      final List<ItemAspectTag> all = await ref.watch(
        allAspectTagsProvider.future,
      );
      return <ItemAspectTag>[
        for (final ItemAspectTag t in all)
          if (t.itemId == itemId) t,
      ];
    });

final FutureProvider<ThemeIndex> themeIndexProvider =
    FutureProvider<ThemeIndex>((Ref ref) async {
      final List<CollectionItem> items = await ref.watch(
        libraryItemsProvider.future,
      );
      final List<ItemAspectTag> tags = await ref.watch(
        allAspectTagsProvider.future,
      );
      return ThemeIndex.build(items: items, tags: tags);
    });

final Logger _log = Logger('Paths');

/// Series or relation tokens per catalog id, fetched once per id for the
/// app's lifetime: a franchise does not change between two picker visits.
class SeriesTokenCache {
  SeriesTokenCache(this._fetch);

  final Future<Map<int, Set<String>>> Function(List<int> ids) _fetch;
  final Map<int, Set<String>> _known = <int, Set<String>>{};

  Future<Map<int, Set<String>>> tokensFor(Iterable<int> ids) async {
    final List<int> missing = <int>[
      for (final int id in ids.toSet())
        if (!_known.containsKey(id)) id,
    ];
    if (missing.isNotEmpty) {
      try {
        final Map<int, Set<String>> fetched = await _fetch(missing);
        for (final int id in missing) {
          _known[id] = fetched[id] ?? const <String>{};
        }
      } on Exception catch (e, stack) {
        // Left unknown, so the next visit tries again once the API answers.
        _log.info('Series lookup unavailable', e, stack);
      }
    }
    return _known;
  }
}

final Provider<SeriesTokenCache> igdbSeriesCacheProvider =
    Provider<SeriesTokenCache>(
      (Ref ref) => SeriesTokenCache(ref.read(igdbApiProvider).seriesTokensFor),
    );

final Provider<SeriesTokenCache> tmdbCollectionCacheProvider =
    Provider<SeriesTokenCache>(
      (Ref ref) =>
          SeriesTokenCache(ref.read(tmdbApiProvider).collectionSiblingsFor),
    );

final Provider<SeriesTokenCache> aniListRelationsCacheProvider =
    Provider<SeriesTokenCache>(
      (Ref ref) =>
          SeriesTokenCache(ref.read(aniListApiProvider).relatedTokensFor),
    );

/// Library works of the same series as the path's own: IGDB franchises for
/// games, TMDB collections for films, AniList relations for anime and manga.
final FutureProviderFamily<List<CollectionItem>, int>
seriesSuggestionsProvider = FutureProvider.family<List<CollectionItem>, int>((
  Ref ref,
  int pathId,
) async {
  final List<PathEntry> entries = await ref.watch(
    pathEntriesProvider(pathId).future,
  );
  final Map<int, CollectionItem> byId = await ref.watch(
    libraryByIdProvider.future,
  );
  final List<CollectionItem> seeds = <CollectionItem>[
    for (final PathEntry e in entries) ?byId[e.itemId],
  ];
  final Set<int> exclude = <int>{for (final PathEntry e in entries) e.itemId};
  final List<CollectionItem> result = <CollectionItem>[];

  if (seeds.any((CollectionItem i) => i.mediaType == MediaType.game)) {
    final Map<int, Set<String>> tokens = await ref
        .read(igdbSeriesCacheProvider)
        .tokensFor(<int>[
          for (final CollectionItem i in byId.values)
            if (i.mediaType == MediaType.game) i.externalId,
        ]);
    result.addAll(
      PathSuggestions.bySeries(
        seeds: seeds,
        library: byId.values,
        tokens: tokens,
        exclude: exclude,
      ),
    );
  }

  // Only the path's own films are looked up: two calls each, not the library.
  final List<int> seedFilms = <int>[
    for (final CollectionItem i in seeds)
      if (PathSuggestions.isTmdbMovie(i)) i.externalId,
  ];
  if (seedFilms.isNotEmpty) {
    final Map<int, Set<String>> siblings = await ref
        .read(tmdbCollectionCacheProvider)
        .tokensFor(seedFilms);
    result.addAll(
      PathSuggestions.byCollection(
        seeds: seeds,
        library: byId.values,
        siblings: siblings,
        exclude: exclude,
      ),
    );
  }

  final List<CollectionItem> aniList = <CollectionItem>[
    for (final CollectionItem i in byId.values)
      if (PathSuggestions.aniListKey(i) != null) i,
  ];
  if (seeds.any((CollectionItem i) => PathSuggestions.aniListKey(i) != null)) {
    final Map<int, Set<String>> relations = await ref
        .read(aniListRelationsCacheProvider)
        .tokensFor(<int>[for (final CollectionItem i in aniList) i.externalId]);
    // Keys carry the media type; AniList ids are unique across both.
    final Map<String, Set<String>> related = <String, Set<String>>{
      for (final CollectionItem i in aniList)
        if (PathSuggestions.aniListKey(i) case final String key)
          key: relations[i.externalId] ?? const <String>{},
    };
    result.addAll(
      PathSuggestions.byRelations(
        seeds: seeds,
        library: byId.values,
        related: related,
        exclude: exclude,
      ),
    );
  }
  return result;
});

final Provider<PathsController> pathsControllerProvider =
    Provider<PathsController>(PathsController.new);

class PathsController {
  PathsController(this._ref);

  final Ref _ref;

  PathsDao get _dao => _ref.read(pathsDaoProvider);

  Future<MediaPath> save(MediaPath path) async {
    final MediaPath saved = await _dao.savePath(path);
    _ref.invalidate(pathsProvider);
    return saved;
  }

  /// Creates a path already holding [itemIds], laid out by release date.
  Future<MediaPath> create({
    required String name,
    required PathKind kind,
    String? description,
    List<CollectionItem> items = const <CollectionItem>[],
  }) async {
    final DateTime now = DateTime.now();
    final MediaPath saved = await _dao.savePath(
      MediaPath(
        id: 0,
        name: name.trim(),
        kind: kind,
        description: description,
        defaultOrder: PathOrder.recommended,
        createdAt: now,
        updatedAt: now,
      ),
    );
    await _dao.addItems(saved.id, PathSuggestions.releaseOrder(items));
    _ref.invalidate(pathsProvider);
    return saved;
  }

  /// Recreates a shared path from the works this library holds; returns the
  /// new path and the stops left out.
  Future<({MediaPath path, List<SharedStop> missing})> importShared(
    SharedPath shared,
  ) async {
    final List<CollectionItem> library = await _ref.read(
      libraryItemsProvider.future,
    );
    final PathMatch match = PathExchange.match(shared, library);
    final DateTime now = DateTime.now();
    final MediaPath saved = await _dao.savePath(
      MediaPath(
        id: 0,
        name: shared.name,
        kind: shared.kind,
        description: shared.description,
        defaultOrder: shared.defaultOrder,
        createdAt: now,
        updatedAt: now,
      ),
    );
    await _dao.insertEntries(<PathEntry>[
      for (final ({SharedStop stop, CollectionItem item}) f in match.found)
        PathEntry(
          id: 0,
          pathId: saved.id,
          itemId: f.item.id,
          releasePos: f.stop.releasePos,
          chronoPos: f.stop.chronoPos,
          recommendedPos: f.stop.recommendedPos,
          optional: f.stop.optional,
          spoiler: f.stop.spoiler,
          note: f.stop.note,
          aspect: f.stop.aspect,
        ),
    ]);
    _ref.invalidate(pathsProvider);
    return (path: saved, missing: match.missing);
  }

  Future<String> exportText(MediaPath path) async {
    final List<PathEntry> entries = await _dao.getEntries(path.id);
    final Map<int, CollectionItem> items = await _ref.read(
      libraryByIdProvider.future,
    );
    return PathExchange.encode(path, entries, items);
  }

  Future<void> delete(int pathId) async {
    await _dao.deletePath(pathId);
    _ref.invalidate(pathsProvider);
  }

  Future<void> addItems(int pathId, List<CollectionItem> items) async {
    await _dao.addItems(pathId, PathSuggestions.releaseOrder(items));
    _ref.invalidate(pathEntriesProvider(pathId));
    _ref.invalidate(pathsProvider);
  }

  Future<void> updateEntry(PathEntry entry) async {
    await _dao.updateEntry(entry);
    _ref.invalidate(pathEntriesProvider(entry.pathId));
  }

  Future<void> removeEntry(PathEntry entry) async {
    await _dao.removeEntry(entry.id);
    _ref.invalidate(pathEntriesProvider(entry.pathId));
    _ref.invalidate(pathsProvider);
  }

  Future<void> reorder(int pathId, PathOrder order, List<int> entryIds) async {
    await _dao.reorder(order, entryIds);
    _ref.invalidate(pathEntriesProvider(pathId));
  }

  /// Rewrites the release order from the works' own dates.
  Future<void> sortByRelease(int pathId) async {
    final List<PathEntry> entries = await _dao.getEntries(pathId);
    final Map<int, CollectionItem> items = await _ref.read(
      libraryByIdProvider.future,
    );
    final List<int> itemOrder = PathSuggestions.releaseOrder(<CollectionItem>[
      for (final PathEntry e in entries) ?items[e.itemId],
    ]);
    final Map<int, int> entryByItem = <int, int>{
      for (final PathEntry e in entries) e.itemId: e.id,
    };
    final List<int> ordered = <int>[
      for (final int itemId in itemOrder) ?entryByItem[itemId],
    ];
    // Works not loaded yet keep a slot at the end instead of colliding.
    await reorder(pathId, PathOrder.release, <int>[
      ...ordered,
      for (final PathEntry e in entries)
        if (!ordered.contains(e.id)) e.id,
    ]);
  }

  Future<bool> addTag(int itemId, PathAspect aspect, String label) async {
    final bool added = await _ref
        .read(aspectsDaoProvider)
        .add(itemId: itemId, aspect: aspect, label: label, now: DateTime.now());
    if (added) _ref.invalidate(allAspectTagsProvider);
    return added;
  }

  Future<void> removeTag(ItemAspectTag tag) async {
    await _ref.read(aspectsDaoProvider).remove(tag.id);
    _ref.invalidate(allAspectTagsProvider);
  }
}
