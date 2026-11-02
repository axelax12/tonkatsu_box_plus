import 'package:core/plus/models/journal_entry.dart';
import 'package:core/plus/models/play_session.dart';
import 'package:core/plus/models/resume_bookmark.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/app_localizations.dart';
import '../../../shared/theme/app_colors.dart';
import '../../../shared/theme/app_spacing.dart';
import '../../../shared/theme/app_typography.dart';
import '../../../shared/utils/duration_formatter.dart';
import '../journal_actions.dart';
import '../providers/journal_providers.dart';
import '../screens/item_journal_screen.dart';
import 'journal_entry_tile.dart';
import 'live_session_clock.dart';
import 'resume_card.dart';

/// The diary block on an item page: timer, "where was I?" and latest notes.
class JournalSection extends ConsumerWidget {
  const JournalSection({
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

  static const int _previewEntries = 3;

  void _openJournal(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (BuildContext _) => ItemJournalScreen(
          itemId: itemId,
          itemName: itemName,
          accentColor: accentColor,
          isEditable: isEditable,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final S l = S.of(context);
    final JournalActions actions = JournalActions(ref, itemId);
    final PlaySession? running =
        ref.watch(runningSessionProvider(itemId)).valueOrNull;
    final List<PlaySession> sessions =
        ref.watch(itemSessionsProvider(itemId)).valueOrNull ??
            const <PlaySession>[];
    final List<JournalEntry> entries =
        ref.watch(itemEntriesProvider(itemId)).valueOrNull ??
            const <JournalEntry>[];
    final ResumeBookmark? bookmark =
        ref.watch(itemBookmarkProvider(itemId)).valueOrNull;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Row(
          children: <Widget>[
            Icon(Icons.auto_stories_outlined, size: 20, color: accentColor),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Text(
                l.journalTitle,
                style: AppTypography.h3.copyWith(fontWeight: FontWeight.w600),
              ),
            ),
            TextButton(
              onPressed: () => _openJournal(context),
              style: TextButton.styleFrom(
                foregroundColor: accentColor,
                minimumSize: const Size(0, AppSpacing.buttonHeightCompact),
              ),
              child: Text(l.journalSeeAll),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        if (isEditable)
          _SessionControls(
            running: running,
            accentColor: accentColor,
            onStart: actions.startSession,
            onStop: (PlaySession s) => actions.stopSession(context, s),
            onLogPast: () => actions.logPastSession(context),
          ),
        _SessionSummary(sessions: sessions),
        const SizedBox(height: AppSpacing.md),
        ResumeCard(
          bookmark: bookmark,
          accentColor: accentColor,
          onTap: isEditable ? () => actions.editBookmark(context) : null,
        ),
        const SizedBox(height: AppSpacing.sm),
        for (final JournalEntry entry in entries.take(_previewEntries))
          JournalEntryTile(
            key: ValueKey<int>(entry.id),
            entry: entry,
            accentColor: accentColor,
            onTap: isEditable
                ? () => actions.editEntry(context, existing: entry)
                : null,
          ),
        if (isEditable)
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: () => actions.editEntry(context),
              icon: const Icon(Icons.add, size: 18),
              label: Text(l.journalAddEntry),
              style: TextButton.styleFrom(
                foregroundColor: accentColor,
                minimumSize: const Size(0, AppSpacing.buttonHeightCompact),
              ),
            ),
          ),
      ],
    );
  }
}

class _SessionControls extends StatelessWidget {
  const _SessionControls({
    required this.running,
    required this.accentColor,
    required this.onStart,
    required this.onStop,
    required this.onLogPast,
  });

  final PlaySession? running;
  final Color accentColor;
  final Future<void> Function() onStart;
  final Future<void> Function(PlaySession session) onStop;
  final VoidCallback onLogPast;

  @override
  Widget build(BuildContext context) {
    final S l = S.of(context);
    final PlaySession? session = running;

    if (session != null) {
      return Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: accentColor.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
          border: Border.all(color: accentColor.withValues(alpha: 0.4)),
        ),
        child: Row(
          children: <Widget>[
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    l.journalSessionRunning,
                    style: AppTypography.caption
                        .copyWith(color: AppColors.textSecondary),
                  ),
                  LiveSessionClock(
                    session: session,
                    style: AppTypography.h1.copyWith(color: accentColor),
                  ),
                ],
              ),
            ),
            FilledButton.icon(
              onPressed: () => onStop(session),
              icon: const Icon(Icons.stop_rounded),
              label: Text(l.journalStopSession),
              style: FilledButton.styleFrom(
                backgroundColor: accentColor,
                minimumSize: const Size(0, AppSpacing.buttonHeight),
              ),
            ),
          ],
        ),
      );
    }

    return Row(
      children: <Widget>[
        Expanded(
          child: FilledButton.icon(
            onPressed: onStart,
            icon: const Icon(Icons.play_arrow_rounded),
            label: Text(l.journalStartSession),
            style: FilledButton.styleFrom(backgroundColor: accentColor),
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: OutlinedButton.icon(
            onPressed: onLogPast,
            icon: const Icon(Icons.history, size: 18),
            label: Text(
              l.journalLogPastSession,
              overflow: TextOverflow.ellipsis,
            ),
            style: OutlinedButton.styleFrom(foregroundColor: accentColor),
          ),
        ),
      ],
    );
  }
}

class _SessionSummary extends StatelessWidget {
  const _SessionSummary({required this.sessions});

  final List<PlaySession> sessions;

  @override
  Widget build(BuildContext context) {
    final List<PlaySession> finished =
        sessions.where((PlaySession s) => !s.isRunning).toList();
    if (finished.isEmpty) return const SizedBox.shrink();
    final S l = S.of(context);
    final int seconds = finished.fold<int>(
      0,
      (int sum, PlaySession s) => sum + s.durationSeconds,
    );
    final String tracked = l.journalTrackedTime(
      formatMinutes(PlaySession.roundToMinutes(seconds), l),
    );
    final String last = l.journalLastSession(
      MaterialLocalizations.of(context)
          .formatMediumDate(finished.first.startedAt),
    );
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.sm),
      child: Text(
        '$tracked · ${l.journalSessionCount(finished.length)} · $last',
        style: AppTypography.bodySmall.copyWith(color: AppColors.textSecondary),
      ),
    );
  }
}
