import 'package:core/plus/models/journal_entry.dart';
import 'package:core/plus/models/play_session.dart';
import 'package:core/plus/models/playthrough.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/app_localizations.dart';
import '../../../shared/theme/app_colors.dart';
import '../../../shared/theme/app_spacing.dart';
import '../../../shared/theme/app_typography.dart';
import '../../../shared/utils/duration_formatter.dart';
import '../journal_actions.dart';
import '../providers/journal_providers.dart';
import '../utils/journal_format.dart';
import '../utils/timeline.dart';
import '../widgets/journal_entry_tile.dart';
import '../widgets/live_session_clock.dart';

class ItemJournalScreen extends ConsumerWidget {
  const ItemJournalScreen({
    required this.itemId,
    required this.itemName,
    required this.accentColor,
    required this.isEditable,
    super.key,
  });

  final int itemId;
  final String itemName;
  final Color accentColor;
  final bool isEditable;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final S l = S.of(context);
    final JournalActions actions = JournalActions(ref, itemId);

    return DefaultTabController(
      length: 2,
      child: Builder(
        builder: (BuildContext tabContext) => Scaffold(
          appBar: AppBar(
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(l.journalTitle),
                Text(
                  itemName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.caption.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
            bottom: TabBar(
              indicatorColor: accentColor,
              labelColor: accentColor,
              tabs: <Widget>[
                Tab(text: l.journalTimeline),
                Tab(text: l.journalPlaythroughs),
              ],
            ),
          ),
          floatingActionButton: isEditable
              ? FloatingActionButton(
                  backgroundColor: accentColor,
                  onPressed: () {
                    final int tab = DefaultTabController.of(tabContext).index;
                    if (tab == 0) {
                      actions.editEntry(tabContext);
                    } else {
                      actions.editPlaythrough(tabContext);
                    }
                  },
                  child: const Icon(Icons.add),
                )
              : null,
          body: TabBarView(
            children: <Widget>[
              _TimelineTab(
                itemId: itemId,
                accentColor: accentColor,
                isEditable: isEditable,
              ),
              _PlaythroughsTab(
                itemId: itemId,
                accentColor: accentColor,
                isEditable: isEditable,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TimelineTab extends ConsumerWidget {
  const _TimelineTab({
    required this.itemId,
    required this.accentColor,
    required this.isEditable,
  });

  final int itemId;
  final Color accentColor;
  final bool isEditable;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final S l = S.of(context);
    final JournalActions actions = JournalActions(ref, itemId);
    final AsyncValue<List<PlaySession>> sessions = ref.watch(
      itemSessionsProvider(itemId),
    );
    final AsyncValue<List<JournalEntry>> entries = ref.watch(
      itemEntriesProvider(itemId),
    );

    if (!sessions.hasValue || !entries.hasValue) {
      return const Center(child: CircularProgressIndicator());
    }

    final List<TimelineDay> days = buildTimeline(
      sessions: sessions.valueOrNull ?? const <PlaySession>[],
      entries: entries.valueOrNull ?? const <JournalEntry>[],
    );
    if (days.isEmpty) {
      return _EmptyState(message: l.journalEmpty);
    }

    final MaterialLocalizations material = MaterialLocalizations.of(context);
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.sm,
        AppSpacing.md,
        AppSpacing.xl * 2,
      ),
      itemCount: days.length,
      itemBuilder: (BuildContext context, int index) {
        final TimelineDay day = days[index];
        return Column(
          key: ValueKey<DateTime>(day.date),
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.only(
                top: AppSpacing.md,
                bottom: AppSpacing.xs,
              ),
              child: Text(
                material.formatFullDate(day.date),
                style: AppTypography.bodySmall.copyWith(
                  color: accentColor,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            for (final TimelineEvent event in day.events)
              switch (event) {
                SessionEvent(:final PlaySession session) => _SessionTile(
                  key: ValueKey<String>('s${session.id}'),
                  session: session,
                  accentColor: accentColor,
                  onTap: isEditable && !session.isRunning
                      ? () => actions.editSession(context, session)
                      : null,
                ),
                EntryEvent(:final JournalEntry entry) => JournalEntryTile(
                  key: ValueKey<String>('e${entry.id}'),
                  entry: entry,
                  accentColor: accentColor,
                  onTap: isEditable
                      ? () => actions.editEntry(context, existing: entry)
                      : null,
                ),
              },
          ],
        );
      },
    );
  }
}

class _SessionTile extends StatelessWidget {
  const _SessionTile({
    required this.session,
    required this.accentColor,
    this.onTap,
    super.key,
  });

  final PlaySession session;
  final Color accentColor;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final S l = S.of(context);
    final MaterialLocalizations material = MaterialLocalizations.of(context);
    final String start = material.formatTimeOfDay(
      TimeOfDay.fromDateTime(session.startedAt),
    );
    final String? note = session.note;
    final String? progress = session.progressLabel;

    return InkWell(
      borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Icon(Icons.timer_outlined, size: 20, color: accentColor),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    <String>[
                      start,
                      if (progress != null && progress.isNotEmpty) progress,
                    ].join(' · '),
                    style: AppTypography.caption.copyWith(
                      color: AppColors.textTertiary,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  if (session.isRunning)
                    LiveSessionClock(
                      session: session,
                      style: AppTypography.body.copyWith(
                        color: accentColor,
                        fontWeight: FontWeight.w600,
                      ),
                    )
                  else
                    Text(
                      formatMinutes(session.countedMinutes, l),
                      style: AppTypography.body.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  if (note != null && note.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: AppSpacing.xs),
                      child: Text(note, style: AppTypography.bodySmall),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PlaythroughsTab extends ConsumerWidget {
  const _PlaythroughsTab({
    required this.itemId,
    required this.accentColor,
    required this.isEditable,
  });

  final int itemId;
  final Color accentColor;
  final bool isEditable;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final S l = S.of(context);
    final JournalActions actions = JournalActions(ref, itemId);
    final AsyncValue<List<Playthrough>> runs = ref.watch(
      itemPlaythroughsProvider(itemId),
    );
    final List<Playthrough> list = runs.valueOrNull ?? const <Playthrough>[];

    if (!runs.hasValue) {
      return const Center(child: CircularProgressIndicator());
    }
    if (list.isEmpty) {
      return _EmptyState(message: l.journalAddPlaythrough);
    }

    final MaterialLocalizations material = MaterialLocalizations.of(context);
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.md,
        AppSpacing.md,
        AppSpacing.xl * 2,
      ),
      itemCount: list.length,
      separatorBuilder: (BuildContext _, int __) =>
          const SizedBox(height: AppSpacing.sm),
      itemBuilder: (BuildContext context, int index) {
        final Playthrough run = list[index];
        final String title = (run.label?.isNotEmpty ?? false)
            ? run.label ?? ''
            : l.journalPlaythroughUntitled(index + 1);
        final DateTime? started = run.startedAt;
        final DateTime? finished = run.finishedAt;
        final double? rating = run.rating;
        final String dates = <String>[
          if (started != null) material.formatMediumDate(started),
          if (finished != null) material.formatMediumDate(finished),
        ].join(' → ');
        final String? review = run.review;

        return Material(
          key: ValueKey<int>(run.id),
          color: AppColors.surfaceLight,
          borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
          child: InkWell(
            borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
            onTap: isEditable
                ? () => actions.editPlaythrough(context, existing: run)
                : null,
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      Expanded(
                        child: Text(
                          title,
                          style: AppTypography.body.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      if (rating != null)
                        Text(
                          '★ ${rating.toStringAsFixed(0)}',
                          style: AppTypography.body.copyWith(
                            color: accentColor,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    <String>[
                      playthroughStatusLabel(run.status, l),
                      if (dates.isNotEmpty) dates,
                    ].join(' · '),
                    style: AppTypography.caption.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                  if (review != null && review.trim().isNotEmpty) ...<Widget>[
                    const SizedBox(height: AppSpacing.sm),
                    Text(review, style: AppTypography.bodySmall),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Text(
          message,
          textAlign: TextAlign.center,
          style: AppTypography.body.copyWith(color: AppColors.textSecondary),
        ),
      ),
    );
  }
}
