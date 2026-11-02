import 'package:core/plus/models/journal_entry.dart';
import 'package:core/plus/models/play_session.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tonkatsu_box/features/journal/utils/timeline.dart';

void main() {
  PlaySession session(int id, DateTime start) => PlaySession(
    id: id,
    itemId: 1,
    startedAt: start,
    endedAt: start.add(const Duration(minutes: 30)),
    durationSeconds: 1800,
    createdAt: start,
  );

  JournalEntry entry(int id, DateTime at) => JournalEntry(
    id: id,
    itemId: 1,
    kind: JournalEntryKind.note,
    body: 'x',
    isSpoiler: false,
    occurredAt: at,
    createdAt: at,
    updatedAt: at,
  );

  group('buildTimeline', () {
    test('is empty without events', () {
      expect(
        buildTimeline(
          sessions: const <PlaySession>[],
          entries: const <JournalEntry>[],
        ),
        isEmpty,
      );
    });

    test('groups by local day, newest day and event first', () {
      final List<TimelineDay> days = buildTimeline(
        sessions: <PlaySession>[
          session(1, DateTime(2026, 3, 1, 9)),
          session(2, DateTime(2026, 3, 2, 21)),
        ],
        entries: <JournalEntry>[entry(10, DateTime(2026, 3, 1, 22))],
      );

      expect(days.map((TimelineDay d) => d.date), <DateTime>[
        DateTime(2026, 3, 2),
        DateTime(2026, 3, 1),
      ]);
      expect(days.first.events.single, isA<SessionEvent>());

      final List<TimelineEvent> firstOfMarch = days.last.events;
      expect(firstOfMarch, hasLength(2));
      expect(firstOfMarch.first, isA<EntryEvent>());
      expect(firstOfMarch.last, isA<SessionEvent>());
    });
  });
}
