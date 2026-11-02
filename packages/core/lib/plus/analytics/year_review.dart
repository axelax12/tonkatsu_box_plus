import '../../models/collection_item.dart';
import '../../models/media_type.dart';
import '../models/journal_entry.dart';
import '../models/play_session.dart';
import 'time_estimator.dart';

/// A year told in numbers and moments: what was finished, how much time went
/// in, the streaks, and the lines worth remembering from the journal.
class YearReview {
  const YearReview({
    required this.year,
    required this.completed,
    required this.completedByType,
    required this.sessionSeconds,
    required this.sessionCount,
    required this.activeDays,
    required this.longestStreakDays,
    required this.secondsByMonth,
    required this.completedByMonth,
    required this.topRated,
    required this.highlights,
    required this.entryCount,
    this.longestSession,
    this.mostPlayed,
    this.mostPlayedSeconds = 0,
  });

  static const int topRatedCount = 5;
  static const int highlightCount = 3;
  static const int monthsPerYear = 12;

  final int year;

  /// Finished during the year, oldest completion first.
  final List<CollectionItem> completed;
  final Map<MediaType, int> completedByType;

  final int sessionSeconds;
  final int sessionCount;

  /// Days with at least one session or journal entry.
  final int activeDays;
  final int longestStreakDays;

  /// Index 0 is January.
  final List<int> secondsByMonth;
  final List<int> completedByMonth;

  final List<CollectionItem> topRated;

  /// Spoiler-free quotes, impressions and milestones, newest first.
  final List<JournalEntry> highlights;
  final int entryCount;

  final PlaySession? longestSession;
  final CollectionItem? mostPlayed;
  final int mostPlayedSeconds;

  bool get isEmpty => completed.isEmpty && sessionCount == 0 && entryCount == 0;

  CollectionItem? get firstCompleted => completed.isEmpty ? null : completed.first;

  CollectionItem? get lastCompleted => completed.isEmpty ? null : completed.last;

  /// 1-based month with the most logged time, or null without sessions.
  int? get busiestMonth {
    int best = -1;
    int bestSeconds = 0;
    for (int m = 0; m < secondsByMonth.length; m++) {
      if (secondsByMonth[m] > bestSeconds) {
        bestSeconds = secondsByMonth[m];
        best = m;
      }
    }
    return best < 0 ? null : best + 1;
  }

  static YearReview compute({
    required int year,
    required List<CollectionItem> items,
    required List<PlaySession> sessions,
    required List<JournalEntry> entries,
  }) {
    final DateTime start = DateTime(year);
    final DateTime end = DateTime(year + 1);
    bool inYear(DateTime d) => !d.isBefore(start) && d.isBefore(end);

    final List<CollectionItem> completed = items.where((CollectionItem i) {
      final DateTime? done = i.completedAt;
      return isFinishedStatus(i.status) && done != null && inYear(done);
    }).toList()
      ..sort((CollectionItem a, CollectionItem b) =>
          _completedAt(a).compareTo(_completedAt(b)));

    final Map<MediaType, int> byType = <MediaType, int>{};
    final List<int> completedByMonth = List<int>.filled(monthsPerYear, 0);
    for (final CollectionItem item in completed) {
      byType[item.mediaType] = (byType[item.mediaType] ?? 0) + 1;
      completedByMonth[_completedAt(item).month - 1]++;
    }

    final List<PlaySession> yearSessions = sessions
        .where((PlaySession s) => !s.isRunning && inYear(s.startedAt))
        .toList();
    final List<int> secondsByMonth = List<int>.filled(monthsPerYear, 0);
    final Map<int, int> secondsByItem = <int, int>{};
    final Set<DateTime> days = <DateTime>{};
    int total = 0;
    PlaySession? longest;
    for (final PlaySession s in yearSessions) {
      total += s.durationSeconds;
      secondsByMonth[s.startedAt.month - 1] += s.durationSeconds;
      secondsByItem[s.itemId] =
          (secondsByItem[s.itemId] ?? 0) + s.durationSeconds;
      days.add(_day(s.startedAt));
      if (longest == null || s.durationSeconds > longest.durationSeconds) {
        longest = s;
      }
    }

    final List<JournalEntry> yearEntries = entries
        .where((JournalEntry e) => inYear(e.occurredAt))
        .toList();
    for (final JournalEntry e in yearEntries) {
      days.add(_day(e.occurredAt));
    }

    int? mostPlayedId;
    int mostPlayedSeconds = 0;
    secondsByItem.forEach((int id, int seconds) {
      if (seconds > mostPlayedSeconds) {
        mostPlayedSeconds = seconds;
        mostPlayedId = id;
      }
    });
    CollectionItem? mostPlayed;
    for (final CollectionItem item in items) {
      if (item.id == mostPlayedId) mostPlayed = item;
    }

    final List<CollectionItem> rated = completed
        .where((CollectionItem i) => i.userRating != null)
        .toList()
      ..sort((CollectionItem a, CollectionItem b) =>
          (b.userRating ?? 0).compareTo(a.userRating ?? 0));

    final List<JournalEntry> highlights = yearEntries
        .where((JournalEntry e) =>
            !e.isSpoiler &&
            (e.body?.trim().isNotEmpty ?? false) &&
            e.kind != JournalEntryKind.note &&
            e.kind != JournalEntryKind.screenshot)
        .toList()
      ..sort((JournalEntry a, JournalEntry b) =>
          b.occurredAt.compareTo(a.occurredAt));

    return YearReview(
      year: year,
      completed: completed,
      completedByType: byType,
      sessionSeconds: total,
      sessionCount: yearSessions.length,
      activeDays: days.length,
      longestStreakDays: longestStreak(days),
      secondsByMonth: secondsByMonth,
      completedByMonth: completedByMonth,
      topRated: rated.take(topRatedCount).toList(),
      highlights: highlights.take(highlightCount).toList(),
      entryCount: yearEntries.length,
      longestSession: longest,
      mostPlayed: mostPlayed,
      mostPlayedSeconds: mostPlayedSeconds,
    );
  }

  /// Longest run of consecutive calendar days in [days].
  static int longestStreak(Set<DateTime> days) {
    if (days.isEmpty) return 0;
    final List<DateTime> sorted = days.toList()..sort();
    int best = 1;
    int run = 1;
    for (int i = 1; i < sorted.length; i++) {
      final DateTime expectedNext = DateTime(
        sorted[i - 1].year,
        sorted[i - 1].month,
        sorted[i - 1].day + 1,
      );
      run = sorted[i] == expectedNext ? run + 1 : 1;
      if (run > best) best = run;
    }
    return best;
  }

  static DateTime _day(DateTime d) => DateTime(d.year, d.month, d.day);

  static DateTime _completedAt(CollectionItem i) =>
      i.completedAt ?? DateTime(0);
}
