import '../../models/collection_item.dart';
import '../../models/media_type.dart';
import 'time_estimator.dart';

/// How the backlog is doing: its size and age, whether it grows or shrinks,
/// and how long clearing it would take at the user's own pace.
class BacklogHealth {
  const BacklogHealth({
    required this.backlogCount,
    required this.countByType,
    required this.averageAgeDays,
    required this.oldest,
    required this.completedPerMonth,
    required this.addedPerMonth,
    required this.estimatedMinutes,
    required this.unknownCount,
    required this.minutesPerWeek,
  });

  static const int defaultWindowDays = 180;
  static const int defaultOldestCount = 5;
  static const double _daysPerMonth = 30.44;
  static const int _daysPerWeek = 7;
  static const int _secondsPerMinute = 60;

  final int backlogCount;
  final Map<MediaType, int> countByType;
  final double averageAgeDays;

  /// Longest-waiting items first.
  final List<CollectionItem> oldest;

  final double completedPerMonth;
  final double addedPerMonth;

  /// Sum over the items whose length is known.
  final int estimatedMinutes;

  /// Items with no length estimate, left out of [estimatedMinutes].
  final int unknownCount;

  /// Average time logged in sessions per week, over the same window.
  final double minutesPerWeek;

  bool get isEmpty => backlogCount == 0;

  bool get isShrinking => completedPerMonth > addedPerMonth;

  /// Null when nothing was finished lately: at that pace it never clears.
  double? get monthsToClearByPace =>
      completedPerMonth > 0 ? backlogCount / completedPerMonth : null;

  /// Null without logged time or without any known length.
  double? get weeksToClearByTime => (minutesPerWeek > 0 && estimatedMinutes > 0)
      ? estimatedMinutes / minutesPerWeek
      : null;

  static BacklogHealth compute({
    required List<CollectionItem> items,
    required DateTime now,
    required Map<int, int> gameSecondsById,
    required int sessionSecondsInWindow,
    int windowDays = defaultWindowDays,
    int oldestCount = defaultOldestCount,
  }) {
    final DateTime windowStart = now.subtract(Duration(days: windowDays));
    final double windowMonths = windowDays / _daysPerMonth;
    final double windowWeeks = windowDays / _daysPerWeek;

    final List<CollectionItem> backlog = items
        .where((CollectionItem i) => isBacklogStatus(i.status))
        .toList()
      ..sort((CollectionItem a, CollectionItem b) =>
          a.addedAt.compareTo(b.addedAt));

    final Map<MediaType, int> byType = <MediaType, int>{};
    double ageDaysSum = 0;
    int estimated = 0;
    int unknown = 0;
    for (final CollectionItem item in backlog) {
      byType[item.mediaType] = (byType[item.mediaType] ?? 0) + 1;
      final Duration age = now.difference(item.addedAt);
      ageDaysSum += age.isNegative ? 0 : age.inHours / Duration.hoursPerDay;
      final int? minutes = TimeEstimator.minutesFor(
        item,
        gameSeconds: gameSecondsById[item.externalId],
      );
      if (minutes == null) {
        unknown++;
      } else {
        estimated += minutes;
      }
    }

    final int completedInWindow = items.where((CollectionItem i) {
      final DateTime? done = i.completedAt;
      return isFinishedStatus(i.status) &&
          done != null &&
          !done.isBefore(windowStart) &&
          !done.isAfter(now);
    }).length;
    final int addedInWindow = items
        .where((CollectionItem i) =>
            !i.addedAt.isBefore(windowStart) && !i.addedAt.isAfter(now))
        .length;

    return BacklogHealth(
      backlogCount: backlog.length,
      countByType: byType,
      averageAgeDays: backlog.isEmpty ? 0 : ageDaysSum / backlog.length,
      oldest: backlog.take(oldestCount).toList(),
      completedPerMonth: completedInWindow / windowMonths,
      addedPerMonth: addedInWindow / windowMonths,
      estimatedMinutes: estimated,
      unknownCount: unknown,
      minutesPerWeek:
          sessionSecondsInWindow / _secondsPerMinute / windowWeeks,
    );
  }
}
