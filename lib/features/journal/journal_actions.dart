import 'package:core/plus/analytics/goal_progress.dart';
import 'package:core/plus/models/journal_entry.dart';
import 'package:core/plus/models/play_session.dart';
import 'package:core/plus/models/playthrough.dart';
import 'package:core/plus/models/resume_bookmark.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/app_localizations.dart';
import '../../shared/extensions/snackbar_extension.dart';
import '../../shared/utils/duration_formatter.dart';
import '../../shared/widgets/confirm_dialog.dart';
import '../insights/providers/insights_providers.dart';
import '../notifications/plus_home_widget.dart';
import '../notifications/plus_notifications.dart';
import 'providers/journal_providers.dart';
import 'widgets/bookmark_editor_sheet.dart';
import 'widgets/entry_editor_sheet.dart';
import 'widgets/playthrough_editor_sheet.dart';
import 'widgets/session_sheets.dart';

/// UI flows shared by the item section and the full journal screen: each one
/// opens its sheet, writes through [JournalController] and confirms.
class JournalActions {
  const JournalActions(this.ref, this.itemId, {this.itemName});

  final WidgetRef ref;
  final int itemId;

  /// Shown in the running-session notification.
  final String? itemName;

  JournalController get _controller => ref.read(journalControllerProvider);

  Future<void> startSession(BuildContext context) async {
    final S l = S.of(context);
    final PlaySession session = await _controller.startSession(itemId);
    await PlusNotifications.instance.showRunningSession(
      itemId: itemId,
      title: itemName ?? l.journalSessionRunning,
      body: l.journalSessionRunning,
      startedAt: session.startedAt,
    );
    await _refreshWidget(l, running: session);
  }

  // The widget shows one session; stopping clears it back to the goals line.
  Future<void> _refreshWidget(S l, {PlaySession? running}) async {
    const int percent = 100;
    String? goals;
    try {
      final List<GoalProgress> progress = await ref.read(
        goalProgressProvider(DateTime.now().year).future,
      );
      if (progress.isNotEmpty) {
        goals = l.widgetGoals(
          progress
              .map((GoalProgress p) => '${(p.fraction * percent).round()}%')
              .join(' · '),
        );
      }
    } on Exception {
      goals = null;
    }
    await PlusHomeWidget.update(
      idleLabel: l.widgetIdle,
      title: running == null ? null : (itemName ?? l.journalSessionRunning),
      startedAt: running?.startedAt,
      goals: goals,
    );
  }

  /// Progress typed while stopping also moves the "Where was I?" position.
  Future<void> stopSession(BuildContext context, PlaySession session) async {
    final S l = S.of(context);
    final ResumeBookmark? bookmark = await ref.read(
      itemBookmarkProvider(itemId).future,
    );
    if (!context.mounted) return;
    final SessionWrapUp? wrapUp = await showStopSessionSheet(
      context,
      initialProgress: bookmark?.position,
    );
    if (wrapUp == null) return;

    final PlaySession? stopped = await _controller.stopSession(
      session,
      note: wrapUp.note,
      progressLabel: wrapUp.progressLabel,
    );
    await PlusNotifications.instance.cancelRunningSession(itemId);
    if (context.mounted) await _refreshWidget(l);
    final String progress = wrapUp.progressLabel?.trim() ?? '';
    if (progress.isNotEmpty && progress != bookmark?.position) {
      await _controller.saveBookmark(
        (bookmark ?? ResumeBookmark(itemId: itemId, updatedAt: DateTime.now()))
            .copyWith(position: progress, updatedAt: DateTime.now()),
      );
    }
    if (stopped == null || !context.mounted) return;
    context.showSnack(
      l.journalSessionAdded(formatMinutes(stopped.countedMinutes, l)),
      type: SnackType.success,
    );
  }

  Future<void> logPastSession(BuildContext context) async {
    final SessionEditResult? result = await showManualSessionSheet(context);
    if (result is! SessionInput) return;
    await _controller.addManualSession(
      itemId: itemId,
      startedAt: result.startedAt,
      duration: result.duration,
      note: result.note,
      progressLabel: result.progressLabel,
    );
  }

  Future<void> editSession(BuildContext context, PlaySession session) async {
    final S l = S.of(context);
    final SessionEditResult? result = await showManualSessionSheet(
      context,
      existing: session,
    );
    if (result == null || !context.mounted) return;
    switch (result) {
      case SessionInput():
        final String note = result.note?.trim() ?? '';
        final String progress = result.progressLabel?.trim() ?? '';
        await _controller.updateSession(
          session.copyWith(
            startedAt: result.startedAt,
            endedAt: result.startedAt.add(result.duration),
            durationSeconds: result.duration.inSeconds,
            note: note,
            clearNote: note.isEmpty,
            progressLabel: progress,
            clearProgressLabel: progress.isEmpty,
          ),
        );
      case SessionDeleteRequested():
        final bool confirmed = await ConfirmDialog.show(
          context,
          title: l.delete,
          message: l.journalDeleteSessionConfirm,
          confirmLabel: l.delete,
        );
        if (confirmed) await _controller.deleteSession(session);
    }
  }

  Future<void> editEntry(
    BuildContext context, {
    JournalEntry? existing,
    JournalEntryKind initialKind = JournalEntryKind.note,
  }) async {
    final S l = S.of(context);
    final ResumeBookmark? bookmark = await ref.read(
      itemBookmarkProvider(itemId).future,
    );
    if (!context.mounted) return;
    final EntryEditResult? result = await showEntryEditorSheet(
      context,
      itemId: itemId,
      existing: existing,
      initialKind: initialKind,
      initialProgress: bookmark?.position,
    );
    if (result == null || !context.mounted) return;
    switch (result) {
      case EntrySaved(:final JournalEntry entry):
        await _controller.saveEntry(entry);
      case EntryDeleted():
        final JournalEntry? target = existing;
        if (target == null) return;
        final bool confirmed = await ConfirmDialog.show(
          context,
          title: l.delete,
          message: l.journalDeleteEntryConfirm,
          confirmLabel: l.delete,
        );
        if (confirmed) await _controller.deleteEntry(target);
    }
  }

  Future<void> editBookmark(BuildContext context) async {
    final ResumeBookmark? current = await ref.read(
      itemBookmarkProvider(itemId).future,
    );
    if (!context.mounted) return;
    final ResumeBookmark? edited = await showBookmarkEditorSheet(
      context,
      itemId: itemId,
      existing: current,
    );
    if (edited != null) await _controller.saveBookmark(edited);
  }

  Future<void> editPlaythrough(
    BuildContext context, {
    Playthrough? existing,
  }) async {
    final S l = S.of(context);
    final PlaythroughEditResult? result = await showPlaythroughEditorSheet(
      context,
      itemId: itemId,
      existing: existing,
    );
    if (result == null || !context.mounted) return;
    switch (result) {
      case PlaythroughSaved(:final Playthrough playthrough):
        await _controller.savePlaythrough(playthrough);
      case PlaythroughDeleted():
        final Playthrough? target = existing;
        if (target == null) return;
        final bool confirmed = await ConfirmDialog.show(
          context,
          title: l.delete,
          message: l.journalDeletePlaythroughConfirm,
          confirmLabel: l.delete,
        );
        if (confirmed) await _controller.deletePlaythrough(target);
    }
  }
}
