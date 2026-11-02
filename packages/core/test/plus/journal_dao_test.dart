import 'package:core/plus/database/journal_dao.dart';
import 'package:core/plus/models/journal_entry.dart';
import 'package:core/plus/models/play_session.dart';
import 'package:core/plus/models/playthrough.dart';
import 'package:core/plus/models/resume_bookmark.dart';
import 'package:test/test.dart';

import 'plus_test_db.dart';

void main() {
  late PlusTestDb t;
  late JournalDao dao;
  late int itemId;
  final DateTime t0 = DateTime(2026, 3, 10, 20);

  setUp(() async {
    t = await PlusTestDb.open();
    dao = JournalDao(() async => t.db);
    itemId = await t.newItem();
  });
  tearDown(() async => t.close());

  JournalEntry entry({
    required DateTime occurredAt,
    JournalEntryKind kind = JournalEntryKind.note,
    String? body = 'text',
  }) {
    return JournalEntry(
      id: 0,
      itemId: itemId,
      kind: kind,
      body: body,
      isSpoiler: false,
      occurredAt: occurredAt,
      createdAt: occurredAt,
      updatedAt: occurredAt,
    );
  }

  group('JournalDao', () {
    group('startSession', () {
      test('creates a running session', () async {
        final PlaySession s = await dao.startSession(itemId, now: t0);
        expect(s.id, isNot(0));
        expect(s.isRunning, isTrue);
        expect((await dao.getRunningSession(itemId))?.id, s.id);
      });

      test('returns the running session instead of opening a second one',
          () async {
        final PlaySession first = await dao.startSession(itemId, now: t0);
        final PlaySession second = await dao.startSession(
          itemId,
          now: t0.add(const Duration(minutes: 5)),
        );
        expect(second.id, first.id);
        expect(await dao.getRunningSessions(), hasLength(1));
      });
    });

    group('stopSession', () {
      test('stores the end time and the duration', () async {
        final PlaySession s = await dao.startSession(itemId, now: t0);
        final PlaySession? stopped = await dao.stopSession(
          s.id,
          now: t0.add(const Duration(minutes: 90)),
          note: '  boss down  ',
          progressLabel: 'Chapter 4',
        );
        expect(stopped?.isRunning, isFalse);
        expect(stopped?.durationSeconds, 90 * 60);
        expect(stopped?.note, 'boss down');
        expect(stopped?.progressLabel, 'Chapter 4');
        expect((await dao.getSession(s.id))?.durationSeconds, 90 * 60);
      });

      test('returns null the second time so time is never counted twice',
          () async {
        final PlaySession s = await dao.startSession(itemId, now: t0);
        await dao.stopSession(s.id, now: t0.add(const Duration(minutes: 1)));
        expect(
          await dao.stopSession(s.id, now: t0.add(const Duration(hours: 1))),
          isNull,
        );
      });

      test('clamps a clock that went backwards to zero', () async {
        final PlaySession s = await dao.startSession(itemId, now: t0);
        final PlaySession? stopped = await dao.stopSession(
          s.id,
          now: t0.subtract(const Duration(minutes: 3)),
        );
        expect(stopped?.durationSeconds, 0);
        expect(stopped?.endedAt, t0);
      });

      test('returns null for an unknown session', () async {
        expect(await dao.stopSession(999, now: t0), isNull);
      });
    });

    group('addManualSession', () {
      test('stores a finished session', () async {
        final PlaySession s = await dao.addManualSession(
          itemId: itemId,
          startedAt: t0,
          duration: const Duration(hours: 2),
          now: t0,
          note: '',
        );
        expect(s.isRunning, isFalse);
        expect(s.durationSeconds, 7200);
        expect(s.note, isNull);
        expect(await dao.getRunningSessions(), isEmpty);
      });

      test('treats a negative duration as zero', () async {
        final PlaySession s = await dao.addManualSession(
          itemId: itemId,
          startedAt: t0,
          duration: const Duration(minutes: -5),
          now: t0,
        );
        expect(s.durationSeconds, 0);
      });
    });

    group('updateSession / deleteSession', () {
      test('update returns the previous row', () async {
        final PlaySession s = await dao.addManualSession(
          itemId: itemId,
          startedAt: t0,
          duration: const Duration(minutes: 30),
          now: t0,
        );
        final PlaySession? before =
            await dao.updateSession(s.copyWith(durationSeconds: 3600));
        expect(before?.durationSeconds, 1800);
        expect((await dao.getSession(s.id))?.durationSeconds, 3600);
      });

      test('update of a missing row returns null', () async {
        final PlaySession ghost = PlaySession(
          id: 404,
          itemId: itemId,
          startedAt: t0,
          durationSeconds: 1,
          createdAt: t0,
        );
        expect(await dao.updateSession(ghost), isNull);
      });

      test('delete returns the removed row, then null', () async {
        final PlaySession s = await dao.addManualSession(
          itemId: itemId,
          startedAt: t0,
          duration: const Duration(minutes: 10),
          now: t0,
        );
        expect((await dao.deleteSession(s.id))?.durationSeconds, 600);
        expect(await dao.deleteSession(s.id), isNull);
        expect(await dao.getSessionsForItem(itemId), isEmpty);
      });
    });

    group('queries', () {
      test('getSessionsBetween keeps finished sessions in range', () async {
        await dao.addManualSession(
          itemId: itemId,
          startedAt: t0.subtract(const Duration(days: 2)),
          duration: const Duration(minutes: 10),
          now: t0,
        );
        final PlaySession inRange = await dao.addManualSession(
          itemId: itemId,
          startedAt: t0,
          duration: const Duration(minutes: 10),
          now: t0,
        );
        await dao.startSession(itemId, now: t0.add(const Duration(hours: 1)));

        final List<PlaySession> found = await dao.getSessionsBetween(
          t0.subtract(const Duration(days: 1)),
          t0.add(const Duration(days: 1)),
        );
        expect(found.map((PlaySession s) => s.id), <int>[inRange.id]);
      });

      test('getTotalSecondsForItem ignores the running session', () async {
        await dao.addManualSession(
          itemId: itemId,
          startedAt: t0,
          duration: const Duration(minutes: 10),
          now: t0,
        );
        await dao.addManualSession(
          itemId: itemId,
          startedAt: t0,
          duration: const Duration(minutes: 5),
          now: t0,
        );
        await dao.startSession(itemId, now: t0);
        expect(await dao.getTotalSecondsForItem(itemId), 900);
      });

      test('getTotalSecondsForItem is zero without sessions', () async {
        expect(await dao.getTotalSecondsForItem(itemId), 0);
      });
    });

    group('playthroughs', () {
      Playthrough run(String label, DateTime? startedAt) => Playthrough(
            id: 0,
            itemId: itemId,
            label: label,
            status: PlaythroughStatus.inProgress,
            startedAt: startedAt,
            createdAt: t0,
            updatedAt: t0,
          );

      test('insert, list in start order, update and delete', () async {
        final Playthrough second =
            await dao.insertPlaythrough(run('NG+', DateTime(2026, 5)));
        final Playthrough first =
            await dao.insertPlaythrough(run('First', DateTime(2025, 1)));

        expect(
          (await dao.getPlaythroughs(itemId)).map((Playthrough p) => p.id),
          <int>[first.id, second.id],
        );

        await dao.updatePlaythrough(
          first.copyWith(status: PlaythroughStatus.completed, rating: 9),
        );
        final Playthrough reloaded = (await dao.getPlaythroughs(itemId)).first;
        expect(reloaded.status, PlaythroughStatus.completed);
        expect(reloaded.rating, 9);

        await dao.deletePlaythrough(first.id);
        expect(await dao.getPlaythroughs(itemId), hasLength(1));
      });
    });

    group('entries', () {
      test('per item, newest first', () async {
        final JournalEntry old = await dao.insertEntry(entry(occurredAt: t0));
        final JournalEntry recent = await dao.insertEntry(
          entry(occurredAt: t0.add(const Duration(days: 1))),
        );
        expect(
          (await dao.getEntriesForItem(itemId)).map((JournalEntry e) => e.id),
          <int>[recent.id, old.id],
        );
      });

      test('getRecentEntries pages back with before', () async {
        for (int i = 0; i < 3; i++) {
          await dao.insertEntry(entry(occurredAt: t0.add(Duration(days: i))));
        }
        final List<JournalEntry> page1 = await dao.getRecentEntries(limit: 2);
        expect(page1, hasLength(2));
        final List<JournalEntry> page2 = await dao.getRecentEntries(
          limit: 2,
          before: page1.last.occurredAt,
        );
        expect(page2.single.occurredAt, t0);
      });

      test('getEntriesBetween is half-open', () async {
        await dao.insertEntry(entry(occurredAt: t0));
        await dao.insertEntry(
          entry(occurredAt: t0.add(const Duration(days: 1))),
        );
        final List<JournalEntry> found = await dao.getEntriesBetween(
          t0,
          t0.add(const Duration(days: 1)),
        );
        expect(found.single.occurredAt, t0);
      });

      test('update and delete', () async {
        final JournalEntry e = await dao.insertEntry(entry(occurredAt: t0));
        await dao.updateEntry(
          e.copyWith(body: 'changed', kind: JournalEntryKind.quote),
        );
        final JournalEntry reloaded = (await dao.getEntriesForItem(itemId)).single;
        expect(reloaded.body, 'changed');
        expect(reloaded.kind, JournalEntryKind.quote);

        await dao.deleteEntry(e.id);
        expect(await dao.getEntriesForItem(itemId), isEmpty);
      });
    });

    group('bookmarks', () {
      test('save, read back trimmed, replace', () async {
        await dao.saveBookmark(
          ResumeBookmark(
            itemId: itemId,
            position: '  Act II  ',
            updatedAt: t0,
          ),
        );
        expect((await dao.getBookmark(itemId))?.position, 'Act II');

        await dao.saveBookmark(
          ResumeBookmark(itemId: itemId, objective: 'Find the key', updatedAt: t0),
        );
        final ResumeBookmark? replaced = await dao.getBookmark(itemId);
        expect(replaced?.position, isNull);
        expect(replaced?.objective, 'Find the key');
      });

      test('an all-blank bookmark deletes the row', () async {
        await dao.saveBookmark(
          ResumeBookmark(itemId: itemId, notes: 'x', updatedAt: t0),
        );
        await dao.saveBookmark(
          ResumeBookmark(itemId: itemId, notes: '   ', updatedAt: t0),
        );
        expect(await dao.getBookmark(itemId), isNull);
      });
    });
  });
}
