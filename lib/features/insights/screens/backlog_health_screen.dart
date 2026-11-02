import 'package:core/models/collection_item.dart';
import 'package:core/models/media_type.dart';
import 'package:core/plus/analytics/backlog_health.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/app_localizations.dart';
import '../../../shared/constants/media_type_theme.dart';
import '../../../shared/constants/media_type_ui.dart';
import '../../../shared/theme/app_colors.dart';
import '../../../shared/theme/app_spacing.dart';
import '../../../shared/theme/app_typography.dart';
import '../../../shared/utils/duration_formatter.dart';
import '../providers/insights_providers.dart';
import '../utils/insights_format.dart';
import '../widgets/item_cover_row.dart';
import '../widgets/stat_tile.dart';

class BacklogHealthScreen extends ConsumerWidget {
  const BacklogHealthScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final S l = S.of(context);
    final AsyncValue<BacklogHealth> async = ref.watch(backlogHealthProvider);

    return async.when(
      loading: () => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const CircularProgressIndicator(),
            const SizedBox(height: AppSpacing.md),
            Text(l.backlogFetchingTimes, style: AppTypography.bodySmall),
          ],
        ),
      ),
      error: (Object e, StackTrace _) => Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Text('$e', textAlign: TextAlign.center),
        ),
      ),
      data: (BacklogHealth health) => health.isEmpty
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.xl),
                child: Text(
                  l.backlogEmpty,
                  textAlign: TextAlign.center,
                  style: AppTypography.body.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
            )
          : RefreshIndicator(
              onRefresh: () => ref.refresh(backlogHealthProvider.future),
              child: _BacklogBody(health: health),
            ),
    );
  }
}

class _BacklogBody extends StatelessWidget {
  const _BacklogBody({required this.health});

  final BacklogHealth health;

  @override
  Widget build(BuildContext context) {
    final S l = S.of(context);
    final bool shrinking = health.isShrinking;
    final Color trendColor = shrinking ? AppColors.success : AppColors.warning;
    final double? months = health.monthsToClearByPace;
    final double? weeks = health.weeksToClearByTime;
    final List<MapEntry<MediaType, int>> types =
        health.countByType.entries.toList()
          ..sort((MapEntry<MediaType, int> a, MapEntry<MediaType, int> b) =>
              b.value.compareTo(a.value));

    return ListView(
      padding: const EdgeInsets.all(AppSpacing.md),
      children: <Widget>[
        StatTileGrid(
          tiles: <Widget>[
            StatTile(
              icon: Icons.inventory_2_outlined,
              value: '${health.backlogCount}',
              label: l.backlogWaiting,
            ),
            StatTile(
              icon: Icons.hourglass_bottom,
              value: l.backlogDays(health.averageAgeDays.round()),
              label: l.backlogAverageAge,
            ),
            StatTile(
              icon: Icons.check_circle_outline,
              value: formatSpan(health.completedPerMonth),
              label: l.backlogFinishedPerMonth,
              color: AppColors.success,
            ),
            StatTile(
              icon: Icons.add_circle_outline,
              value: formatSpan(health.addedPerMonth),
              label: l.backlogAddedPerMonth,
            ),
          ],
        ),
        Container(
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            color: trendColor.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
          ),
          child: Row(
            children: <Widget>[
              Icon(
                shrinking ? Icons.trending_down : Icons.trending_up,
                color: trendColor,
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  shrinking ? l.backlogShrinking : l.backlogGrowing,
                  style: AppTypography.body.copyWith(color: trendColor),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        Text(l.backlogEstimate, style: AppTypography.h3),
        const SizedBox(height: AppSpacing.sm),
        StatTileGrid(
          tiles: <Widget>[
            StatTile(
              icon: Icons.schedule,
              value: formatMinutes(health.estimatedMinutes, l),
              label: l.backlogEstimate,
            ),
            StatTile(
              icon: Icons.speed,
              value: weeks != null
                  ? l.backlogWeeks(formatSpan(weeks))
                  : (months != null
                      ? l.backlogMonths(formatSpan(months))
                      : l.backlogNever),
              label: l.backlogAtYourPace,
            ),
          ],
        ),
        Text(
          l.backlogEstimateNote(health.unknownCount),
          style: AppTypography.caption,
        ),
        if (weeks == null)
          Padding(
            padding: const EdgeInsets.only(top: AppSpacing.xs),
            child: Text(l.backlogNoSessions, style: AppTypography.caption),
          ),
        const SizedBox(height: AppSpacing.lg),
        Text(l.backlogByType, style: AppTypography.h3),
        const SizedBox(height: AppSpacing.sm),
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          children: <Widget>[
            for (final MapEntry<MediaType, int> e in types)
              Chip(
                key: ValueKey<MediaType>(e.key),
                avatar: Icon(
                  MediaTypeTheme.iconFor(e.key),
                  size: 16,
                  color: MediaTypeTheme.colorFor(e.key),
                ),
                label: Text('${e.key.localizedPluralLabel(l)} · ${e.value}'),
              ),
          ],
        ),
        const SizedBox(height: AppSpacing.lg),
        Text(l.backlogOldest, style: AppTypography.h3),
        const SizedBox(height: AppSpacing.sm),
        for (final CollectionItem item in health.oldest)
          ItemCoverRow(
            key: ValueKey<int>(item.id),
            item: item,
            caption: l.backlogDays(
              DateTime.now().difference(item.addedAt).inDays,
            ),
          ),
      ],
    );
  }
}
