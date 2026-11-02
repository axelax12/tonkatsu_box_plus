import 'package:core/models/collection_item.dart';
import 'package:core/plus/analytics/backlog_health.dart';
import 'package:core/plus/analytics/goal_progress.dart';
import 'package:core/plus/analytics/release_reminders.dart';
import 'package:core/plus/models/smart_list.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/app_localizations.dart';
import '../../../shared/theme/app_colors.dart';
import '../../../shared/theme/app_spacing.dart';
import '../../../shared/theme/app_typography.dart';
import '../../insights/providers/insights_providers.dart';
import '../../insights/screens/backlog_health_screen.dart';
import '../../insights/screens/goals_screen.dart';
import '../../insights/utils/insights_format.dart';
import '../../insights/widgets/goal_ring.dart';
import '../../paths/providers/paths_providers.dart';
import '../../paths/screens/paths_screen.dart';
import '../../personalization/widgets/personalization_sub_screen.dart';
import '../../smart_lists/providers/smart_list_providers.dart';
import '../../smart_lists/screens/smart_list_screen.dart';
import '../../together/screens/together_screen.dart';
import '../providers/today_providers.dart';
import '../widgets/cover_strip.dart';
import '../widgets/customize_sheet.dart';
import '../widgets/resume_hero.dart';

/// The phone's front page: what is in progress, what comes next, how the
/// year is going. Sections are the user's to order and hide.
class TodayView extends ConsumerWidget {
  const TodayView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final S l = S.of(context);
    final List<TodaySection> sections = ref.watch(
      todayLayoutProvider.select((TodayLayout t) => t.visible),
    );
    return ListView(
      padding: const EdgeInsets.only(bottom: AppSpacing.xl),
      children: <Widget>[
        for (final TodaySection s in sections)
          KeyedSubtree(key: ValueKey<TodaySection>(s), child: _section(s)),
        Center(
          child: TextButton.icon(
            onPressed: () => showTodayCustomizeSheet(context),
            icon: const Icon(Icons.tune),
            label: Text(l.todayCustomize),
          ),
        ),
      ],
    );
  }

  static Widget _section(TodaySection section) => switch (section) {
    TodaySection.resume => const _ResumeSection(),
    TodaySection.goals => const _GoalsSection(),
    TodaySection.upNext => const _UpNextSection(),
    TodaySection.releases => const _ReleasesSection(),
    TodaySection.backlog => const _BacklogSection(),
    TodaySection.lists => const _ListsSection(),
  };
}

class _Hint extends StatelessWidget {
  const _Hint(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
      child: Text(
        text,
        style: AppTypography.bodySmall.copyWith(color: AppColors.textSecondary),
      ),
    );
  }
}

class _ResumeSection extends ConsumerWidget {
  const _ResumeSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final S l = S.of(context);
    final List<CollectionItem> active =
        ref.watch(inProgressItemsProvider).valueOrNull ??
        const <CollectionItem>[];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        TodaySectionHeader(title: l.todayResume),
        if (active.isEmpty)
          _Hint(l.todayNothingInProgress)
        else ...<Widget>[
          ResumeHero(key: ValueKey<int>(active.first.id), item: active.first),
          if (active.length > 1) ...<Widget>[
            const SizedBox(height: AppSpacing.md),
            CoverStrip(
              entries: <CoverStripEntry>[
                for (final CollectionItem i in active.skip(1))
                  CoverStripEntry(item: i),
              ],
            ),
          ],
        ],
      ],
    );
  }
}

class _GoalsSection extends ConsumerWidget {
  const _GoalsSection();

  static const double _ringSize = 76;
  static const double _ringStroke = 7;
  static const int _percent = 100;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final S l = S.of(context);
    final int year = DateTime.now().year;
    final List<GoalProgress> goals =
        ref.watch(goalProgressProvider(year)).valueOrNull ??
        const <GoalProgress>[];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        TodaySectionHeader(
          title: '${l.todayGoals} $year',
          actionLabel: l.todaySeeAll,
          onAction: () => pushPersonalizationSection(
            context,
            title: l.insightsGoalsTitle,
            child: const GoalsScreen(),
          ),
        ),
        if (goals.isEmpty)
          _Hint(l.goalNoneYet(year))
        else
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
            child: Row(
              children: <Widget>[
                for (final GoalProgress p in goals)
                  Padding(
                    key: ValueKey<int>(p.goal.id),
                    padding: const EdgeInsets.only(right: AppSpacing.md),
                    child: SizedBox(
                      width: _ringSize + AppSpacing.lg,
                      child: Column(
                        children: <Widget>[
                          GoalRing(
                            fraction: p.fraction,
                            expectedFraction: p.goal.target == 0
                                ? null
                                : p.expected / p.goal.target,
                            color: goalPaceColor(p.pace),
                            size: _ringSize,
                            strokeWidth: _ringStroke,
                            child: Text(
                              '${(p.fraction * _percent).round()}%',
                              style: AppTypography.bodySmall.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          const SizedBox(height: AppSpacing.xs),
                          Text(
                            goalTitle(p.goal, l),
                            maxLines: 2,
                            textAlign: TextAlign.center,
                            overflow: TextOverflow.ellipsis,
                            style: AppTypography.caption,
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
      ],
    );
  }
}

class _UpNextSection extends ConsumerWidget {
  const _UpNextSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final S l = S.of(context);
    final List<UpNext> next =
        ref.watch(upNextProvider).valueOrNull ?? const <UpNext>[];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        TodaySectionHeader(
          title: l.todayUpNext,
          actionLabel: l.todaySeeAll,
          onAction: () => pushPersonalizationSection(
            context,
            title: l.pathsTitle,
            child: const PathsScreen(),
          ),
        ),
        if (next.isEmpty)
          _Hint(l.todayNoUpNext)
        else
          CoverStrip(
            entries: <CoverStripEntry>[
              for (final UpNext n in next)
                if (n.stop.item case final CollectionItem item)
                  CoverStripEntry(
                    item: item,
                    caption: l.todayInPath(n.path.name),
                  ),
            ],
          ),
      ],
    );
  }
}

class _ReleasesSection extends ConsumerWidget {
  const _ReleasesSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final S l = S.of(context);
    final MaterialLocalizations material = MaterialLocalizations.of(context);
    final List<ReleaseReminder> releases =
        ref.watch(upcomingReleasesProvider).valueOrNull ??
        const <ReleaseReminder>[];
    final Map<int, CollectionItem> byId =
        ref.watch(libraryByIdProvider).valueOrNull ??
        const <int, CollectionItem>{};
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        TodaySectionHeader(title: l.todayReleases),
        if (releases.isEmpty)
          _Hint(l.todayNoReleases)
        else
          CoverStrip(
            entries: <CoverStripEntry>[
              for (final ReleaseReminder r in releases)
                if (byId[r.itemId] case final CollectionItem item)
                  CoverStripEntry(
                    item: item,
                    caption: material.formatMediumDate(r.releaseDay),
                  ),
            ],
          ),
      ],
    );
  }
}

class _BacklogSection extends ConsumerWidget {
  const _BacklogSection();

  static const int _minutesPerHour = 60;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final S l = S.of(context);
    final BacklogHealth? health = ref.watch(backlogHealthProvider).valueOrNull;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        TodaySectionHeader(
          title: l.todayBacklog,
          actionLabel: l.todaySeeAll,
          onAction: () => pushPersonalizationSection(
            context,
            title: l.insightsBacklogTitle,
            child: const BacklogHealthScreen(),
          ),
        ),
        if (health != null)
          _Hint(
            l.todayBacklogLine(
              health.backlogCount,
              (health.estimatedMinutes / _minutesPerHour).round(),
            ),
          ),
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.md,
            AppSpacing.sm,
            AppSpacing.md,
            0,
          ),
          child: OutlinedButton.icon(
            onPressed: () => pushPersonalizationSection(
              context,
              title: l.togetherTitle,
              child: const TogetherScreen(),
            ),
            icon: const Icon(Icons.casino_outlined),
            label: Text(l.todayPickForMe),
          ),
        ),
      ],
    );
  }
}

class _ListsSection extends ConsumerWidget {
  const _ListsSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final S l = S.of(context);
    final List<SmartList> lists =
        ref.watch(smartListsProvider).valueOrNull ?? const <SmartList>[];
    if (lists.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        TodaySectionHeader(title: l.todayLists),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
          child: Row(
            children: <Widget>[
              for (final SmartList list in lists)
                Padding(
                  key: ValueKey<int>(list.id),
                  padding: const EdgeInsets.only(right: AppSpacing.sm),
                  child: ActionChip(
                    avatar: const Icon(Icons.filter_list_alt, size: 16),
                    label: Text(list.name),
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (BuildContext _) =>
                            SmartListScreen(listId: list.id),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}
