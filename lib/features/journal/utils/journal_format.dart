import 'package:core/plus/models/journal_entry.dart';
import 'package:core/plus/models/playthrough.dart';
import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';

const int _secondsPerMinute = 60;
const int _minutesPerHour = 60;

/// A stopwatch face: `4:07` under an hour, `1:04:07` above.
String formatClock(Duration duration) {
  final Duration safe = duration.isNegative ? Duration.zero : duration;
  final int hours = safe.inHours;
  final String minutes =
      (safe.inMinutes % _minutesPerHour).toString().padLeft(2, '0');
  final String seconds =
      (safe.inSeconds % _secondsPerMinute).toString().padLeft(2, '0');
  if (hours > 0) return '$hours:$minutes:$seconds';
  return '${safe.inMinutes}:$seconds';
}

String journalKindLabel(JournalEntryKind kind, S l) {
  switch (kind) {
    case JournalEntryKind.note:
      return l.journalKindNote;
    case JournalEntryKind.quote:
      return l.journalKindQuote;
    case JournalEntryKind.impression:
      return l.journalKindImpression;
    case JournalEntryKind.milestone:
      return l.journalKindMilestone;
    case JournalEntryKind.screenshot:
      return l.journalKindScreenshot;
  }
}

IconData journalKindIcon(JournalEntryKind kind) {
  switch (kind) {
    case JournalEntryKind.note:
      return Icons.edit_note;
    case JournalEntryKind.quote:
      return Icons.format_quote;
    case JournalEntryKind.impression:
      return Icons.auto_awesome_outlined;
    case JournalEntryKind.milestone:
      return Icons.flag_outlined;
    case JournalEntryKind.screenshot:
      return Icons.image_outlined;
  }
}

/// Kinds offered by the entry editor; screenshots arrive with image support.
const List<JournalEntryKind> kEditableJournalKinds = <JournalEntryKind>[
  JournalEntryKind.note,
  JournalEntryKind.quote,
  JournalEntryKind.impression,
  JournalEntryKind.milestone,
];

String playthroughStatusLabel(PlaythroughStatus status, S l) {
  switch (status) {
    case PlaythroughStatus.inProgress:
      return l.journalPlaythroughInProgress;
    case PlaythroughStatus.completed:
      return l.journalPlaythroughCompleted;
    case PlaythroughStatus.dropped:
      return l.journalPlaythroughDropped;
  }
}
