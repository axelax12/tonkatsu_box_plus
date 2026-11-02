import 'package:core/models/media_type.dart';
import 'package:core/plus/analytics/goal_progress.dart';
import 'package:core/plus/models/yearly_goal.dart';
import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';
import '../../../shared/constants/media_type_ui.dart';
import '../../../shared/theme/app_colors.dart';

String goalMetricLabel(GoalMetric metric, S l) {
  switch (metric) {
    case GoalMetric.completed:
      return l.goalMetricCompleted;
    case GoalMetric.hours:
      return l.goalMetricHours;
    case GoalMetric.backlogCleared:
      return l.goalMetricBacklog;
  }
}

IconData goalMetricIcon(GoalMetric metric) {
  switch (metric) {
    case GoalMetric.completed:
      return Icons.emoji_events_outlined;
    case GoalMetric.hours:
      return Icons.timer_outlined;
    case GoalMetric.backlogCleared:
      return Icons.inventory_2_outlined;
  }
}

String mediaScopeLabel(MediaType? type, S l) =>
    type == null ? l.goalAllTypes : type.localizedPluralLabel(l);

/// "Finished · Games", "Hours logged · Everything".
String goalTitle(YearlyGoal goal, S l) =>
    '${goalMetricLabel(goal.metric, l)} · ${mediaScopeLabel(goal.mediaType, l)}';

String goalPaceLabel(GoalPace pace, S l) {
  switch (pace) {
    case GoalPace.done:
      return l.goalPaceDone;
    case GoalPace.ahead:
      return l.goalPaceAhead;
    case GoalPace.onTrack:
      return l.goalPaceOnTrack;
    case GoalPace.behind:
      return l.goalPaceBehind;
  }
}

Color goalPaceColor(GoalPace pace) {
  switch (pace) {
    case GoalPace.done:
    case GoalPace.ahead:
      return AppColors.success;
    case GoalPace.onTrack:
      return AppColors.brand;
    case GoalPace.behind:
      return AppColors.warning;
  }
}

/// Hours keep one decimal under ten so a fresh goal does not read "0 of 200".
String formatGoalAmount(double value, GoalMetric metric) {
  const double decimalBelow = 10;
  if (metric == GoalMetric.hours && value > 0 && value < decimalBelow) {
    return value.toStringAsFixed(1);
  }
  return value.floor().toString();
}

/// "3.5" months, "12" weeks: one decimal only while it still matters.
String formatSpan(double value) {
  const double decimalBelow = 10;
  return value < decimalBelow
      ? value.toStringAsFixed(1)
      : value.round().toString();
}
