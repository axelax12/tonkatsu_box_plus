import '../../models/collection_item.dart';
import '../../models/media_type.dart';
import '../models/play_session.dart';
import '../models/yearly_goal.dart';
import 'time_estimator.dart';

enum GoalPace { done, ahead, onTrack, behind }

class GoalProgress {
  const GoalProgress({
    required this.goal,
    required this.current,
    required this.expected,
  });

  /// Inside this share of the target, ahead or behind still reads "on track".
  static const double paceTolerance = 0.05;
  static const int _secondsPerHour = 3600;

  final YearlyGoal goal;

  /// Hours for [GoalMetric.hours], a count otherwise.
  final double current;

  /// Where a steady pace would be today.
  final double expected;

  double get fraction {
    final double f = current / goal.target;
    return f.isNaN ? 0 : f.clamp(0, 1).toDouble();
  }

  double get remaining {
    final double r = goal.target - current;
    return r < 0 ? 0 : r;
  }

  GoalPace get pace {
    if (current >= goal.target) return GoalPace.done;
    final double margin = goal.target * paceTolerance;
    final double diff = current - expected;
    if (diff >= margin) return GoalPace.ahead;
    if (diff <= -margin) return GoalPace.behind;
    return GoalPace.onTrack;
  }

  /// [sessions] may span more than the goal's year; only that year counts.
  static GoalProgress compute(
    YearlyGoal goal, {
    required List<CollectionItem> items,
    required List<PlaySession> sessions,
    required DateTime now,
  }) {
    final DateTime start = DateTime(goal.year);
    final DateTime end = DateTime(goal.year + 1);
    bool inYear(DateTime d) => !d.isBefore(start) && d.isBefore(end);
    bool typeMatches(MediaType type) =>
        goal.mediaType == null || goal.mediaType == type;

    final double current;
    switch (goal.metric) {
      case GoalMetric.completed:
      case GoalMetric.backlogCleared:
        final bool onlyBacklog = goal.metric == GoalMetric.backlogCleared;
        current = items.where((CollectionItem i) {
          final DateTime? done = i.completedAt;
          return isFinishedStatus(i.status) &&
              done != null &&
              inYear(done) &&
              typeMatches(i.mediaType) &&
              (!onlyBacklog || i.addedAt.isBefore(start));
        }).length.toDouble();
      case GoalMetric.hours:
        final Map<int, MediaType> typeById = <int, MediaType>{
          for (final CollectionItem i in items) i.id: i.mediaType,
        };
        int seconds = 0;
        for (final PlaySession s in sessions) {
          if (s.isRunning || !inYear(s.startedAt)) continue;
          final MediaType? type = typeById[s.itemId];
          if (type == null || !typeMatches(type)) continue;
          seconds += s.durationSeconds;
        }
        current = seconds / _secondsPerHour;
    }

    return GoalProgress(
      goal: goal,
      current: current,
      expected: goal.target * yearElapsed(goal.year, now),
    );
  }

  /// 0 before the year starts, 1 once it is over.
  static double yearElapsed(int year, DateTime now) {
    final DateTime start = DateTime(year);
    final DateTime end = DateTime(year + 1);
    if (!now.isAfter(start)) return 0;
    if (!now.isBefore(end)) return 1;
    return now.difference(start).inSeconds / end.difference(start).inSeconds;
  }
}
