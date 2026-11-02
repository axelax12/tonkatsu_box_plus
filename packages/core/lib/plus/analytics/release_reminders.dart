import '../../models/collection_item.dart';
import 'time_estimator.dart';

class ReleaseReminder {
  const ReleaseReminder({
    required this.itemId,
    required this.title,
    required this.releaseDay,
  });

  final int itemId;
  final String title;

  /// Local midnight of the release day.
  final DateTime releaseDay;
}

/// Works waiting on the user's list that come out on a known future day.
abstract final class ReleaseReminders {
  /// Android caps pending alarms per app; this stays well under it.
  static const int maxCount = 40;

  static const Duration horizon = Duration(days: 365);

  static List<ReleaseReminder> plan(
    Iterable<CollectionItem> items,
    DateTime now, {
    int limit = maxCount,
  }) {
    final DateTime today = DateTime(now.year, now.month, now.day);
    final DateTime last = today.add(horizon);
    final Map<int, ReleaseReminder> byItem = <int, ReleaseReminder>{};
    for (final CollectionItem item in items) {
      if (!isBacklogStatus(item.status)) continue;
      final DateTime? date = item.releaseDate;
      if (date == null) continue;
      final DateTime day = DateTime(date.year, date.month, date.day);
      if (!day.isAfter(today) || day.isAfter(last)) continue;
      byItem[item.id] = ReleaseReminder(
        itemId: item.id,
        title: item.itemName,
        releaseDay: day,
      );
    }
    final List<ReleaseReminder> sorted = byItem.values.toList()
      ..sort((ReleaseReminder a, ReleaseReminder b) {
        final int byDay = a.releaseDay.compareTo(b.releaseDay);
        return byDay != 0 ? byDay : a.itemId.compareTo(b.itemId);
      });
    return sorted.length <= limit ? sorted : sorted.sublist(0, limit);
  }

  /// Changes whenever a reminder would move, so an unchanged plan is skipped.
  static String signature(List<ReleaseReminder> plan) => <String>[
    for (final ReleaseReminder r in plan)
      '${r.itemId}@${r.releaseDay.millisecondsSinceEpoch}',
  ].join(',');
}
