import '../../models/collection_item.dart';
import '../../models/media_type.dart';
import '../models/smart_list.dart';
import 'time_estimator.dart';

/// Applies [SmartListRules] to the loaded library. Pure and synchronous, so a
/// rule editor can preview the match count on every keystroke.
abstract final class SmartListEvaluator {
  static List<CollectionItem> apply(
    SmartListRules rules,
    List<CollectionItem> items, {
    required DateTime now,
    Map<int, List<int>> tagIdsByItem = const <int, List<int>>{},
    Map<int, int> gameSecondsById = const <int, int>{},
  }) {
    final String needle = rules.text?.trim().toLowerCase() ?? '';
    final Map<int, int?> minutesById = <int, int?>{};
    int? minutesOf(CollectionItem item) => minutesById.putIfAbsent(
      item.id,
      () => TimeEstimator.minutesFor(
        item,
        gameSeconds: gameSecondsById[item.externalId],
      ),
    );

    bool matches(CollectionItem item) {
      if (rules.mediaTypes.isNotEmpty &&
          !rules.mediaTypes.contains(item.mediaType)) {
        return false;
      }
      if (rules.statuses.isNotEmpty && !rules.statuses.contains(item.status)) {
        return false;
      }
      if (rules.collectionIds.isNotEmpty &&
          !rules.collectionIds.contains(item.collectionId)) {
        return false;
      }
      if (rules.tagIds.isNotEmpty) {
        final List<int> tags = tagIdsByItem[item.id] ?? const <int>[];
        if (!tags.any(rules.tagIds.contains)) return false;
      }
      if (rules.favoritesOnly && !item.isFavorite) return false;
      if (rules.neverStarted && item.startedAt != null) return false;

      final double? minRating = rules.minRating;
      if (minRating != null && (item.userRating ?? 0) < minRating) {
        return false;
      }
      final int? minAge = rules.minAgeDays;
      if (minAge != null && now.difference(item.addedAt).inDays < minAge) {
        return false;
      }

      final int? minMinutes = rules.minMinutes;
      final int? maxMinutes = rules.maxMinutes;
      if (minMinutes != null || maxMinutes != null) {
        final int? minutes = minutesOf(item);
        if (minutes == null) return false;
        if (minMinutes != null && minutes < minMinutes) return false;
        if (maxMinutes != null && minutes > maxMinutes) return false;
      }

      final int? maxLeft = rules.maxUnitsLeft;
      if (maxLeft != null) {
        final int? left = unitsLeft(item);
        if (left == null || left > maxLeft) return false;
      }

      if (needle.isNotEmpty && !_haystack(item).contains(needle)) return false;
      return true;
    }

    final List<CollectionItem> result = items.where(matches).toList();
    switch (rules.sort) {
      case SmartListSort.addedOldest:
        result.sort(
          (CollectionItem a, CollectionItem b) => a.addedAt.compareTo(b.addedAt),
        );
      case SmartListSort.addedNewest:
        result.sort(
          (CollectionItem a, CollectionItem b) => b.addedAt.compareTo(a.addedAt),
        );
      case SmartListSort.shortestFirst:
        // Unknown lengths go last instead of pretending to be zero.
        result.sort((CollectionItem a, CollectionItem b) {
          final int? ma = minutesOf(a);
          final int? mb = minutesOf(b);
          if (ma == null && mb == null) return 0;
          if (ma == null) return 1;
          if (mb == null) return -1;
          return ma.compareTo(mb);
        });
      case SmartListSort.ratingHighest:
        result.sort(
          (CollectionItem a, CollectionItem b) =>
              (b.userRating ?? 0).compareTo(a.userRating ?? 0),
        );
      case SmartListSort.nameAsc:
        result.sort(
          (CollectionItem a, CollectionItem b) =>
              a.itemName.toLowerCase().compareTo(b.itemName.toLowerCase()),
        );
    }
    return result;
  }

  /// Started items with a known total only: "3 left" means nothing for a
  /// series nobody has begun.
  static int? unitsLeft(CollectionItem item) {
    final int current = item.currentEpisode;
    if (current <= 0) return null;
    final int? total = switch (item.mediaType) {
      MediaType.tvShow || MediaType.animation => item.totalEpisodes,
      MediaType.anime => item.anime?.episodes ?? item.totalEpisodes,
      MediaType.manga => item.manga?.chapters,
      MediaType.book => item.book?.pageCount,
      _ => null,
    };
    if (total == null || total <= 0) return null;
    final int left = total - current;
    return left < 0 ? 0 : left;
  }

  static String _haystack(CollectionItem item) {
    return <String?>[
      item.itemName,
      item.genresString,
      ...?item.book?.authors,
    ].whereType<String>().join(' ').toLowerCase();
  }
}
