import '../../models/collection_item.dart';
import '../../models/data_source.dart';
import '../../models/item_status.dart';
import '../../models/media_type.dart';
import '../models/media_path.dart';
import 'time_estimator.dart';

enum StopState { done, inProgress, next, upcoming }

class PathStop {
  const PathStop({
    required this.entry,
    required this.item,
    required this.state,
    required this.hidden,
  });

  final PathEntry entry;

  /// Null only while the library is still loading; deleted items cascade away.
  final CollectionItem? item;
  final StopState state;

  /// A spoiler stop the user has not reached yet.
  final bool hidden;

  bool get isDone => state == StopState.done;
}

/// One walk of a path in a chosen order: what is done, what comes next and
/// which spoiler stops must stay masked.
class PathWalk {
  const PathWalk({
    required this.order,
    required this.stops,
    required this.requiredDone,
    required this.requiredTotal,
    required this.optionalDone,
    required this.optionalTotal,
  });

  factory PathWalk.compute({
    required List<PathEntry> entries,
    required Map<int, CollectionItem> items,
    required PathOrder order,
  }) {
    final List<PathEntry> sorted = List<PathEntry>.of(entries)
      ..sort((PathEntry a, PathEntry b) {
        final int byPos = a.positionFor(order).compareTo(b.positionFor(order));
        return byPos != 0 ? byPos : a.id.compareTo(b.id);
      });

    final List<PathStop> stops = <PathStop>[];
    bool pathCleared = true;
    bool nextAssigned = false;
    int requiredDone = 0;
    int requiredTotal = 0;
    int optionalDone = 0;
    int optionalTotal = 0;

    for (final PathEntry entry in sorted) {
      final CollectionItem? item = items[entry.itemId];
      final ItemStatus? status = item?.status;
      final bool done = status != null && isFinishedStatus(status);
      final bool active =
          status == ItemStatus.inProgress || status == ItemStatus.replaying;

      if (entry.optional) {
        optionalTotal++;
        if (done) optionalDone++;
      } else {
        requiredTotal++;
        if (done) requiredDone++;
      }

      StopState state;
      if (done && status != ItemStatus.replaying) {
        state = StopState.done;
      } else if (active) {
        state = StopState.inProgress;
      } else if (!nextAssigned && !entry.optional) {
        state = StopState.next;
      } else {
        state = StopState.upcoming;
      }
      if (!entry.optional &&
          (state == StopState.inProgress || state == StopState.next)) {
        nextAssigned = true;
      }

      // Reaching a stop means every required stop before it is finished.
      final bool hidden = entry.spoiler && !done && !active && !pathCleared;
      stops.add(
        PathStop(entry: entry, item: item, state: state, hidden: hidden),
      );
      if (!entry.optional && !done) pathCleared = false;
    }

    return PathWalk(
      order: order,
      stops: stops,
      requiredDone: requiredDone,
      requiredTotal: requiredTotal,
      optionalDone: optionalDone,
      optionalTotal: optionalTotal,
    );
  }

  final PathOrder order;
  final List<PathStop> stops;
  final int requiredDone;
  final int requiredTotal;
  final int optionalDone;
  final int optionalTotal;

  double get fraction => requiredTotal == 0 ? 0 : requiredDone / requiredTotal;

  bool get isComplete => requiredTotal > 0 && requiredDone == requiredTotal;

  /// The stop to show as "continue here": an active one wins over the next.
  PathStop? get current {
    for (final PathStop s in stops) {
      if (s.state == StopState.inProgress && !s.entry.optional) return s;
    }
    for (final PathStop s in stops) {
      if (s.state == StopState.next) return s;
    }
    for (final PathStop s in stops) {
      if (s.state == StopState.inProgress) return s;
    }
    return null;
  }

  int indexOfItem(int itemId) =>
      stops.indexWhere((PathStop s) => s.entry.itemId == itemId);
}

/// Library works whose titles carry every word of the path name, as a first
/// guess for "Gundam" or "The Witcher" before the user picks by hand.
class PathSuggestions {
  const PathSuggestions._();

  static const int _minWordLength = 3;

  static const int defaultLimit = 30;

  static List<CollectionItem> byTitle(
    String pathName,
    Iterable<CollectionItem> library, {
    Set<int> exclude = const <int>{},
    int limit = defaultLimit,
  }) {
    final List<String> words = _words(pathName);
    if (words.isEmpty) return const <CollectionItem>[];
    final List<CollectionItem> hits = <CollectionItem>[
      for (final CollectionItem item in library)
        if (!exclude.contains(item.id) &&
            _matches(_normalize(item.itemName), words))
          item,
    ];
    hits.sort(_byRelease);
    return hits.length <= limit ? hits : hits.sublist(0, limit);
  }

  /// Oldest first, undated last: the natural starting guess for release order.
  static int _byRelease(CollectionItem a, CollectionItem b) {
    final int? ya = a.releaseYear;
    final int? yb = b.releaseYear;
    if (ya != null && yb != null && ya != yb) return ya.compareTo(yb);
    if (ya == null && yb != null) return 1;
    if (ya != null && yb == null) return -1;
    final DateTime? da = a.releaseDate;
    final DateTime? db = b.releaseDate;
    if (da != null && db != null) return da.compareTo(db);
    return a.itemName.toLowerCase().compareTo(b.itemName.toLowerCase());
  }

  /// Library games sharing an IGDB franchise or collection with a game
  /// already on the path; [tokens] maps a game's IGDB id to its series.
  static List<CollectionItem> bySeries({
    required Iterable<CollectionItem> seeds,
    required Iterable<CollectionItem> library,
    required Map<int, Set<String>> tokens,
    Set<int> exclude = const <int>{},
    int limit = defaultLimit,
  }) {
    final Set<String> wanted = <String>{
      for (final CollectionItem s in seeds)
        if (s.mediaType == MediaType.game) ...?tokens[s.externalId],
    };
    if (wanted.isEmpty) return const <CollectionItem>[];
    final Map<int, CollectionItem> hits = <int, CollectionItem>{};
    for (final CollectionItem item in library) {
      if (item.mediaType != MediaType.game || exclude.contains(item.id)) {
        continue;
      }
      final Set<String>? own = tokens[item.externalId];
      if (own != null && own.any(wanted.contains)) {
        // One entry per game even when it sits in several collections.
        hits.putIfAbsent(item.externalId, () => item);
      }
    }
    final List<CollectionItem> sorted = hits.values.toList()..sort(_byRelease);
    return sorted.length <= limit ? sorted : sorted.sublist(0, limit);
  }

  /// AniList key of an anime or manga, or null when it came from elsewhere.
  static String? aniListKey(CollectionItem item) {
    if (item.dataSource != DataSource.anilist) return null;
    return switch (item.mediaType) {
      MediaType.anime => 'anime:${item.externalId}',
      MediaType.manga => 'manga:${item.externalId}',
      _ => null,
    };
  }

  /// Library anime and manga connected to the path's own through AniList
  /// relations, followed across the library: 0079 reaches Zeta, Zeta reaches ZZ.
  static List<CollectionItem> byRelations({
    required Iterable<CollectionItem> seeds,
    required Iterable<CollectionItem> library,
    required Map<String, Set<String>> related,
    Set<int> exclude = const <int>{},
    int limit = defaultLimit,
  }) {
    final Map<String, Set<String>> edges = <String, Set<String>>{};
    void link(String a, String b) {
      edges.putIfAbsent(a, () => <String>{}).add(b);
      edges.putIfAbsent(b, () => <String>{}).add(a);
    }

    for (final MapEntry<String, Set<String>> e in related.entries) {
      for (final String other in e.value) {
        link(e.key, other);
      }
    }
    final Map<String, CollectionItem> byKey = <String, CollectionItem>{};
    for (final CollectionItem item in library) {
      final String? key = aniListKey(item);
      if (key != null) byKey.putIfAbsent(key, () => item);
    }
    final List<String> queue = <String>[
      for (final CollectionItem s in seeds) ?aniListKey(s),
    ];
    final Set<String> seen = queue.toSet();
    final Map<int, CollectionItem> hits = <int, CollectionItem>{};
    while (queue.isNotEmpty) {
      final String key = queue.removeLast();
      for (final String next in edges[key] ?? const <String>{}) {
        if (!seen.add(next)) continue;
        final CollectionItem? item = byKey[next];
        // Only works in the library extend the walk, keeping it local.
        if (item == null) continue;
        queue.add(next);
        if (!exclude.contains(item.id)) hits[item.id] = item;
      }
    }
    final List<CollectionItem> sorted = hits.values.toList()..sort(_byRelease);
    return sorted.length <= limit ? sorted : sorted.sublist(0, limit);
  }

  /// Release order for already-chosen items, by the same rule as suggestions.
  static List<int> releaseOrder(Iterable<CollectionItem> items) {
    final List<CollectionItem> sorted = List<CollectionItem>.of(items)
      ..sort(_byRelease);
    return <int>[for (final CollectionItem i in sorted) i.id];
  }

  static bool _matches(String title, List<String> words) {
    for (final String w in words) {
      if (!title.contains(w)) return false;
    }
    return true;
  }

  static List<String> _words(String text) => _normalize(
    text,
  ).split(' ').where((String w) => w.length >= _minWordLength).toList();

  static String _normalize(String text) => text
      .toLowerCase()
      .replaceAll(RegExp(r'[^\p{L}\p{N}]+', unicode: true), ' ')
      .trim();
}
