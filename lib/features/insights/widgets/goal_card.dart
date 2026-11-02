import 'package:core/plus/analytics/goal_progress.dart';
import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';
import '../../../shared/theme/app_colors.dart';
import '../../../shared/theme/app_spacing.dart';
import '../../../shared/theme/app_typography.dart';
import '../utils/insights_format.dart';
import 'goal_ring.dart';

class GoalCard extends StatelessWidget {
  const GoalCard({required this.progress, this.onTap, super.key});

  final GoalProgress progress;
  final VoidCallback? onTap;

  static const int _percent = 100;

  @override
  Widget build(BuildContext context) {
    final S l = S.of(context);
    final GoalPace pace = progress.pace;
    final Color color = goalPaceColor(pace);
    final double target = progress.goal.target.toDouble();
    final String current = formatGoalAmount(
      progress.current,
      progress.goal.metric,
    );
    final String targetText = formatGoalAmount(target, progress.goal.metric);

    return Material(
      color: AppColors.surfaceLight,
      borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Row(
            children: <Widget>[
              GoalRing(
                fraction: progress.fraction,
                expectedFraction: target > 0
                    ? progress.expected / target
                    : null,
                color: color,
                child: Text(
                  '${(progress.fraction * _percent).round()}%',
                  style: AppTypography.body.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        Icon(
                          goalMetricIcon(progress.goal.metric),
                          size: 16,
                          color: AppColors.textSecondary,
                        ),
                        const SizedBox(width: AppSpacing.xs),
                        Expanded(
                          child: Text(
                            goalTitle(progress.goal, l),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTypography.bodySmall.copyWith(
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      l.goalProgressCount(current, targetText),
                      style: AppTypography.h2,
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Row(
                      children: <Widget>[
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.sm,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: color.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(
                              AppSpacing.radiusSm,
                            ),
                          ),
                          child: Text(
                            goalPaceLabel(pace, l),
                            style: AppTypography.caption.copyWith(
                              color: color,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        if (pace != GoalPace.done) ...<Widget>[
                          const SizedBox(width: AppSpacing.sm),
                          Flexible(
                            child: Text(
                              l.goalRemaining(
                                formatGoalAmount(
                                  progress.remaining,
                                  progress.goal.metric,
                                ),
                              ),
                              overflow: TextOverflow.ellipsis,
                              style: AppTypography.caption.copyWith(
                                color: AppColors.textTertiary,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
