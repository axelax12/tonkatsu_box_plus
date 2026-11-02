import 'package:core/plus/models/journal_entry.dart';
import 'package:core/plus/models/play_session.dart';

sealed class TimelineEvent {
  const TimelineEvent();

  DateTime get at;
}

class SessionEvent extends TimelineEvent {
  const SessionEvent(this.session);

  final PlaySession session;

  @override
  DateTime get at => session.startedAt;
}

class EntryEvent extends TimelineEvent {
  const EntryEvent(this.entry);

  final JournalEntry entry;

  @override
  DateTime get at => entry.occurredAt;
}

class TimelineDay {
  const TimelineDay({required this.date, required this.events});

  /// Local midnight of the day.
  final DateTime date;

  /// Newest first.
  final List<TimelineEvent> events;
}

/// Sessions and entries merged into local calendar days, newest day first.
List<TimelineDay> buildTimeline({
  required List<PlaySession> sessions,
  required List<JournalEntry> entries,
}) {
  final List<TimelineEvent> events = <TimelineEvent>[
    for (final PlaySession s in sessions) SessionEvent(s),
    for (final JournalEntry e in entries) EntryEvent(e),
  ]..sort((TimelineEvent a, TimelineEvent b) => b.at.compareTo(a.at));

  final List<TimelineDay> days = <TimelineDay>[];
  for (final TimelineEvent event in events) {
    final DateTime local = event.at.toLocal();
    final DateTime day = DateTime(local.year, local.month, local.day);
    if (days.isEmpty || days.last.date != day) {
      days.add(TimelineDay(date: day, events: <TimelineEvent>[event]));
    } else {
      days.last.events.add(event);
    }
  }
  return days;
}
