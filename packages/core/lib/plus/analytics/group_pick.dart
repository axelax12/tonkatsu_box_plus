import 'dart:math';

import '../../models/collection_item.dart';
import '../../models/item_status.dart';
import '../../models/media_type.dart';
import 'time_estimator.dart';

/// One work up for the vote, merged across every library that holds it.
class PickCandidate {
  const PickCandidate({
    required this.key,
    required this.item,
    required this.owners,
    required this.minutes,
  });

  /// Same work in two profiles: their row ids differ, the catalog id does not.
  final String key;

  /// The copy from the first library that had it; the current profile's wins.
  final CollectionItem item;

  /// Participant ids whose backlog holds it.
  final Set<String> owners;
  final int? minutes;
}

class PickFilters {
  const PickFilters({
    this.types = const <MediaType>{},
    this.maxMinutes,
    this.includeUnknownLength = true,
  });

  /// Empty means every type.
  final Set<MediaType> types;
  final int? maxMinutes;
  final bool includeUnknownLength;
}

enum Vote {
  no(0),
  maybe(1),
  yes(2);

  const Vote(this.points);

  final int points;
}

class PickResult {
  const PickResult({
    required this.candidate,
    required this.points,
    required this.yes,
    required this.no,
  });

  final PickCandidate candidate;
  final int points;
  final int yes;
  final int no;

  bool unanimousFor(int voters) => voters > 0 && yes == voters;
}

/// "What do we watch tonight?": a pool nobody in the group has already seen,
/// sized to the evening, then a pass-the-phone vote.
abstract final class GroupPick {
  static String keyOf(CollectionItem item) =>
      '${item.mediaType.value}:${item.externalId}';

  /// [libraries] maps participant id to their items, the current profile
  /// first; guests vote without a library.
  static List<PickCandidate> candidates({
    required Map<String, List<CollectionItem>> libraries,
    PickFilters filters = const PickFilters(),
    Map<int, int> gameSecondsById = const <int, int>{},
  }) {
    final Set<String> seen = <String>{};
    final Map<String, CollectionItem> firstCopy = <String, CollectionItem>{};
    final Map<String, Set<String>> owners = <String, Set<String>>{};

    for (final MapEntry<String, List<CollectionItem>> library
        in libraries.entries) {
      for (final CollectionItem item in library.value) {
        final String key = keyOf(item);
        if (!_untouched(item.status)) {
          seen.add(key);
          continue;
        }
        firstCopy.putIfAbsent(key, () => item);
        owners.putIfAbsent(key, () => <String>{}).add(library.key);
      }
    }

    final List<PickCandidate> pool = <PickCandidate>[];
    for (final MapEntry<String, CollectionItem> e in firstCopy.entries) {
      if (seen.contains(e.key)) continue;
      final CollectionItem item = e.value;
      if (filters.types.isNotEmpty && !filters.types.contains(item.mediaType)) {
        continue;
      }
      final int? minutes = TimeEstimator.minutesFor(
        item,
        gameSeconds: item.mediaType == MediaType.game
            ? gameSecondsById[item.externalId]
            : null,
      );
      final int? cap = filters.maxMinutes;
      if (cap != null) {
        if (minutes == null && !filters.includeUnknownLength) continue;
        if (minutes != null && minutes > cap) continue;
      }
      pool.add(
        PickCandidate(
          key: e.key,
          item: item,
          owners: owners[e.key] ?? <String>{},
          minutes: minutes,
        ),
      );
    }
    return pool;
  }

  /// Works more of the group wants come first; the rest are shuffled so the
  /// same titles do not open every round.
  static List<PickCandidate> ballot(
    List<PickCandidate> pool, {
    required int size,
    Random? random,
  }) {
    final Random rng = random ?? Random();
    final List<PickCandidate> shuffled = List<PickCandidate>.of(pool)
      ..shuffle(rng);
    shuffled.sort(
      (PickCandidate a, PickCandidate b) =>
          b.owners.length.compareTo(a.owners.length),
    );
    return shuffled.length <= size ? shuffled : shuffled.sublist(0, size);
  }

  /// Highest points first; ties go to more yeses, fewer noes, then the shorter.
  static List<PickResult> tally(
    List<PickCandidate> ballot,
    Map<String, Map<String, Vote>> votesByVoter,
  ) {
    final List<PickResult> results = <PickResult>[
      for (final PickCandidate c in ballot)
        _resultFor(c, votesByVoter.values),
    ];
    results.sort((PickResult a, PickResult b) {
      if (a.points != b.points) return b.points.compareTo(a.points);
      if (a.yes != b.yes) return b.yes.compareTo(a.yes);
      if (a.no != b.no) return a.no.compareTo(b.no);
      final int ma = a.candidate.minutes ?? _unknownLength;
      final int mb = b.candidate.minutes ?? _unknownLength;
      return ma.compareTo(mb);
    });
    return results;
  }

  static const int _unknownLength = 1 << 30;

  static PickResult _resultFor(
    PickCandidate c,
    Iterable<Map<String, Vote>> voters,
  ) {
    int points = 0;
    int yes = 0;
    int no = 0;
    for (final Map<String, Vote> votes in voters) {
      final Vote? v = votes[c.key];
      if (v == null) continue;
      points += v.points;
      if (v == Vote.yes) yes++;
      if (v == Vote.no) no++;
    }
    return PickResult(candidate: c, points: points, yes: yes, no: no);
  }

  // Anything started, finished, dropped or parked counts as already seen.
  static bool _untouched(ItemStatus status) =>
      status == ItemStatus.notStarted || status == ItemStatus.planned;
}
