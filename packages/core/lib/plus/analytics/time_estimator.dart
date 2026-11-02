import '../../models/collection_item.dart';
import '../../models/item_status.dart';
import '../../models/media_type.dart';

/// Rough minutes needed to finish an item, from its own catalog data. These
/// are deliberately simple averages: good enough to size a backlog, not a promise.
abstract final class TimeEstimator {
  static const int movieFallbackMinutes = 110;
  static const int tvEpisodeMinutes = 45;
  static const int animeEpisodeMinutes = 24;
  static const double bookMinutesPerPage = 1.5;
  static const int mangaChapterMinutes = 6;
  static const int secondsPerMinute = 60;

  /// Null when nothing is known (a game IGDB has no times for, a podcast).
  static int? minutesFor(CollectionItem item, {int? gameSeconds}) {
    switch (item.mediaType) {
      case MediaType.game:
        if (gameSeconds == null || gameSeconds <= 0) return null;
        return (gameSeconds / secondsPerMinute).round();
      case MediaType.movie:
        return item.runtime ?? movieFallbackMinutes;
      case MediaType.animation:
        final int? runtime = item.runtime;
        if (runtime != null && runtime > 0) return runtime;
        return _times(item.totalEpisodes, animeEpisodeMinutes);
      case MediaType.tvShow:
        return _times(item.totalEpisodes, tvEpisodeMinutes);
      case MediaType.anime:
        return _times(
          item.anime?.episodes ?? item.totalEpisodes,
          animeEpisodeMinutes,
        );
      case MediaType.book:
        final int? pages = item.book?.pageCount;
        if (pages == null || pages <= 0) return null;
        return (pages * bookMinutesPerPage).round();
      case MediaType.manga:
        return _times(item.manga?.chapters, mangaChapterMinutes);
      case MediaType.visualNovel:
        final int? minutes = item.visualNovel?.lengthMinutes;
        return (minutes == null || minutes <= 0) ? null : minutes;
      case MediaType.audio:
      case MediaType.custom:
        return null;
    }
  }

  static int? _times(int? count, int minutesEach) =>
      (count == null || count <= 0) ? null : count * minutesEach;
}

/// Waiting to be started: the backlog, as opposed to the wishlist.
bool isBacklogStatus(ItemStatus status) =>
    status == ItemStatus.notStarted || status == ItemStatus.planned;

/// Finished at least once; a replay keeps the original completion date.
bool isFinishedStatus(ItemStatus status) =>
    status == ItemStatus.completed || status == ItemStatus.replaying;
