import 'package:core/models/collection_item.dart';
import 'package:core/models/media_type.dart';
import 'package:core/plus/analytics/year_review.dart';
import 'package:core/plus/models/journal_entry.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:logging/logging.dart';

import '../../../l10n/app_localizations.dart';
import '../../../shared/constants/media_type_theme.dart';
import '../../../shared/constants/media_type_ui.dart';
import '../../../shared/extensions/snackbar_extension.dart';
import '../../../shared/services/png_export_service.dart';
import '../../../shared/theme/app_colors.dart';
import '../../../shared/theme/app_spacing.dart';
import '../../../shared/theme/app_typography.dart';
import '../../../shared/utils/duration_formatter.dart';
import '../providers/insights_providers.dart';
import '../widgets/item_cover_row.dart';
import '../widgets/stat_tile.dart';
import '../widgets/year_switcher.dart';

class YearReviewScreen extends ConsumerStatefulWidget {
  const YearReviewScreen({super.key});

  @override
  ConsumerState<YearReviewScreen> createState() => _YearReviewScreenState();
}

class _YearReviewScreenState extends ConsumerState<YearReviewScreen> {
  static final Logger _log = Logger('YearReviewScreen');
  static const double _cardMaxWidth = 420;
  static const Duration _imageSettle = Duration(milliseconds: 150);

  final GlobalKey _cardKey = GlobalKey();
  int _year = DateTime.now().year;
  bool _sharing = false;

  Future<void> _share() async {
    final S l = S.of(context);
    setState(() => _sharing = true);
    // Covers are network images; give them a frame to land in the capture.
    await WidgetsBinding.instance.endOfFrame;
    await Future<void>.delayed(_imageSettle);
    final BulkExportResult result;
    try {
      result = await saveBoundaryAsPng(
        repaintKey: _cardKey,
        suggestedFileName: '${sanitizeFileName(l.yearShareTitle(_year))}.png',
        saveDialogTitle: l.yearShare,
      );
    } finally {
      if (mounted) setState(() => _sharing = false);
    }
    if (!mounted) return;
    switch (result.status) {
      case BulkExportStatus.saved:
        context.showSnack(l.imageSaved, type: SnackType.success);
      case BulkExportStatus.cancelled:
        break;
      case BulkExportStatus.failed:
        _log.warning('Failed to export the year review', result.error);
        context.showSnack(l.statsExportFailed, type: SnackType.error);
    }
  }

  @override
  Widget build(BuildContext context) {
    final S l = S.of(context);
    final AsyncValue<YearReview> async = ref.watch(yearReviewProvider(_year));
    final YearReview? review = async.valueOrNull;

    return ListView(
      padding: const EdgeInsets.all(AppSpacing.md),
      children: <Widget>[
        YearSwitcher(
          year: _year,
          onChanged: (int year) => setState(() => _year = year),
        ),
        const SizedBox(height: AppSpacing.sm),
        if (review == null)
          const Padding(
            padding: EdgeInsets.all(AppSpacing.xl),
            child: Center(child: CircularProgressIndicator()),
          )
        else if (review.isEmpty)
          Padding(
            padding: const EdgeInsets.all(AppSpacing.xl),
            child: Text(
              l.yearEmpty(_year),
              textAlign: TextAlign.center,
              style: AppTypography.body.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          )
        else ...<Widget>[
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: _cardMaxWidth),
              child: RepaintBoundary(
                key: _cardKey,
                child: _ReviewCard(review: review),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          FilledButton.icon(
            onPressed: _sharing ? null : _share,
            icon: const Icon(Icons.ios_share),
            label: Text(l.yearShare),
          ),
        ],
      ],
    );
  }
}

class _ReviewCard extends StatelessWidget {
  const _ReviewCard({required this.review});

  final YearReview review;

  static const double _barHeight = 56;
  static const int _secondsPerMinute = 60;

  @override
  Widget build(BuildContext context) {
    final S l = S.of(context);
    final MaterialLocalizations material = MaterialLocalizations.of(context);
    final int? busiest = review.busiestMonth;
    final CollectionItem? mostPlayed = review.mostPlayed;
    final List<MapEntry<MediaType, int>> types =
        review.completedByType.entries.toList()..sort(
          (MapEntry<MediaType, int> a, MapEntry<MediaType, int> b) =>
              b.value.compareTo(a.value),
        );

    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppSpacing.radiusXl),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[
            AppColors.brand.withValues(alpha: 0.35),
            AppColors.surface,
            AppColors.surfaceLight,
          ],
        ),
        border: Border.all(color: AppColors.surfaceBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text(
            l.yearShareTitle(review.year),
            style: AppTypography.h1.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: AppSpacing.md),
          StatTileGrid(
            tiles: <Widget>[
              StatTile(
                icon: Icons.emoji_events_outlined,
                value: '${review.completed.length}',
                label: l.yearCompleted,
                color: AppColors.brand,
              ),
              StatTile(
                icon: Icons.timer_outlined,
                value: formatMinutes(
                  review.sessionSeconds ~/ _secondsPerMinute,
                  l,
                ),
                label: l.yearHours,
              ),
              StatTile(
                icon: Icons.calendar_month_outlined,
                value: '${review.activeDays}',
                label: l.yearActiveDays,
              ),
              StatTile(
                icon: Icons.local_fire_department_outlined,
                value: '${review.longestStreakDays}',
                label: l.yearLongestStreak,
              ),
            ],
          ),
          if (types.isNotEmpty) ...<Widget>[
            const SizedBox(height: AppSpacing.sm),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.xs,
              children: <Widget>[
                for (final MapEntry<MediaType, int> e in types)
                  Row(
                    key: ValueKey<MediaType>(e.key),
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Icon(
                        MediaTypeTheme.iconFor(e.key),
                        size: 16,
                        color: MediaTypeTheme.colorFor(e.key),
                      ),
                      const SizedBox(width: AppSpacing.xs),
                      Text(
                        '${e.value} ${e.key.localizedPluralLabel(l)}',
                        style: AppTypography.bodySmall,
                      ),
                    ],
                  ),
              ],
            ),
          ],
          const SizedBox(height: AppSpacing.lg),
          Text(l.yearMonthByMonth, style: AppTypography.h3),
          const SizedBox(height: AppSpacing.sm),
          _MonthBars(
            values: review.secondsByMonth,
            fallback: review.completedByMonth,
            height: _barHeight,
          ),
          if (busiest != null) ...<Widget>[
            const SizedBox(height: AppSpacing.xs),
            Text(
              '${l.yearBusiestMonth}: '
              '${material.formatMonthYear(DateTime(review.year, busiest))}',
              style: AppTypography.caption,
            ),
          ],
          if (mostPlayed != null) ...<Widget>[
            const SizedBox(height: AppSpacing.lg),
            Text(l.yearMostPlayed, style: AppTypography.h3),
            ItemCoverRow(
              item: mostPlayed,
              caption: formatMinutes(
                review.mostPlayedSeconds ~/ _secondsPerMinute,
                l,
              ),
            ),
          ],
          if (review.topRated.isNotEmpty) ...<Widget>[
            const SizedBox(height: AppSpacing.lg),
            Text(l.yearTopRated, style: AppTypography.h3),
            for (final CollectionItem item in review.topRated)
              ItemCoverRow(
                key: ValueKey<int>(item.id),
                item: item,
                trailing: Text(
                  '★ ${(item.userRating ?? 0).toStringAsFixed(0)}',
                  style: AppTypography.body.copyWith(
                    color: AppColors.brand,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
          ],
          if (review.highlights.isNotEmpty) ...<Widget>[
            const SizedBox(height: AppSpacing.lg),
            Text(l.yearHighlights, style: AppTypography.h3),
            const SizedBox(height: AppSpacing.sm),
            for (final JournalEntry entry in review.highlights)
              Padding(
                key: ValueKey<int>(entry.id),
                padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                child: Text(
                  '“${entry.body ?? ''}”',
                  style: AppTypography.body.copyWith(
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),
          ],
        ],
      ),
    );
  }
}

/// Twelve bars of logged time; months without sessions fall back to the
/// number of completions so a year without a timer still has a shape.
class _MonthBars extends StatelessWidget {
  const _MonthBars({
    required this.values,
    required this.fallback,
    required this.height,
  });

  final List<int> values;
  final List<int> fallback;
  final double height;

  static const double _minBar = 2;

  @override
  Widget build(BuildContext context) {
    final bool useTime = values.any((int v) => v > 0);
    final List<int> data = useTime ? values : fallback;
    final int max = data.fold<int>(0, (int m, int v) => v > m ? v : m);
    final DateFormat initial = DateFormat(
      'MMMMM',
      Localizations.localeOf(context).toLanguageTag(),
    );
    return SizedBox(
      height: height + AppSpacing.md,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: <Widget>[
          for (int i = 0; i < data.length; i++)
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: <Widget>[
                    Container(
                      height: max == 0
                          ? _minBar
                          : _minBar + (height - _minBar) * data[i] / max,
                      decoration: BoxDecoration(
                        color: data[i] > 0
                            ? AppColors.brand
                            : AppColors.surfaceBorder,
                        borderRadius: BorderRadius.circular(
                          AppSpacing.radiusXxs,
                        ),
                      ),
                    ),
                    Text(
                      initial.format(DateTime(2000, i + 1)),
                      style: AppTypography.caption,
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
