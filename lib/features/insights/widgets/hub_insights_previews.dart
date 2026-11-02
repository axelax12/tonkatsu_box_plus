import 'package:core/models/collection_item.dart';
import 'package:core/plus/analytics/goal_progress.dart';
import 'package:core/plus/analytics/time_estimator.dart';
import 'package:core/plus/analytics/year_review.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/app_localizations.dart';
import '../../../shared/theme/app_colors.dart';
import '../../../shared/theme/app_spacing.dart';
import '../../../shared/theme/app_typography.dart';
import '../../../shared/utils/duration_formatter.dart';
import '../providers/insights_providers.dart';
import '../utils/insights_format.dart';
import 'goal_ring.dart';

const int _maxPreviewRings = 4;
const double _previewRingSize = 48;
const int _percent = 100;
const int _secondsPerMinute = 60;

class HubGoalsPreview extends ConsumerWidget {
  const HubGoalsPreview({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final S l = S.of(context);
    final List<GoalProgress> goals =
        ref.watch(goalProgressProvider(DateTime.now().year)).valueOrNull ??
            const <GoalProgress>[];
    if (goals.isEmpty) {
      return Text(
        l.goalNoneYet(DateTime.now().year),
        style: AppTypography.bodySmall.copyWith(color: AppColors.textSecondary),
      );
    }
    return Wrap(
      spacing: AppSpacing.md,
      runSpacing: AppSpacing.sm,
      children: <Widget>[
        for (final GoalProgress p in goals.take(_maxPreviewRings))
          GoalRing(
            key: ValueKey<int>(p.goal.id),
            fraction: p.fraction,
            color: goalPaceColor(p.pace),
            size: _previewRingSize,
            strokeWidth: 5,
            child: Text(
              '${(p.fraction * _percent).round()}%',
              style: AppTypography.caption.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
      ],
    );
  }
}

class HubBacklogPreview extends ConsumerWidget {
  const HubBacklogPreview({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final S l = S.of(context);
    final List<CollectionItem> items =
        ref.watch(libraryItemsProvider).valueOrNull ?? const <CollectionItem>[];
    final DateTime now = DateTime.now();
    final List<CollectionItem> backlog = items
        .where((CollectionItem i) => isBacklogStatus(i.status))
        .toList();
    final int avgDays = backlog.isEmpty
        ? 0
        : backlog
                .map((CollectionItem i) => now.difference(i.addedAt).inDays)
                .reduce((int a, int b) => a + b) ~/
            backlog.length;
    return Text(
      backlog.isEmpty
          ? l.backlogEmpty
          : l.hubBacklogPreview(backlog.length, l.backlogDays(avgDays)),
      style: AppTypography.bodySmall.copyWith(color: AppColors.textSecondary),
    );
  }
}

class HubYearPreview extends ConsumerWidget {
  const HubYearPreview({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final S l = S.of(context);
    final YearReview? review =
        ref.watch(yearReviewProvider(DateTime.now().year)).valueOrNull;
    if (review == null || review.isEmpty) {
      return Text(
        l.yearEmpty(DateTime.now().year),
        style: AppTypography.bodySmall.copyWith(color: AppColors.textSecondary),
      );
    }
    return Text(
      l.hubYearPreview(
        review.completed.length,
        formatMinutes(review.sessionSeconds ~/ _secondsPerMinute, l),
      ),
      style: AppTypography.bodySmall.copyWith(color: AppColors.textSecondary),
    );
  }
}
