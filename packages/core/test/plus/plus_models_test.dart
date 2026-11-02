import 'package:core/plus/models/journal_entry.dart';
import 'package:core/plus/models/play_session.dart';
import 'package:core/plus/models/playthrough.dart';
import 'package:core/plus/models/resume_bookmark.dart';
import 'package:test/test.dart';

void main() {
  final DateTime t0 = DateTime(2026, 1, 1, 12);

  group('PlaySession', () {
    group('roundToMinutes', () {
      test('rounds half up and never goes negative', () {
        expect(PlaySession.roundToMinutes(-10), 0);
        expect(PlaySession.roundToMinutes(0), 0);
        expect(PlaySession.roundToMinutes(29), 0);
        expect(PlaySession.roundToMinutes(30), 1);
        expect(PlaySession.roundToMinutes(89), 1);
        expect(PlaySession.roundToMinutes(90), 2);
      });
    });

    group('elapsed', () {
      final PlaySession running = PlaySession(
        id: 1,
        itemId: 1,
        startedAt: t0,
        durationSeconds: 0,
        createdAt: t0,
      );

      test('is live for a running session', () {
        expect(
          running.elapsed(t0.add(const Duration(minutes: 7))),
          const Duration(minutes: 7),
        );
      });

      test('never goes negative', () {
        expect(
          running.elapsed(t0.subtract(const Duration(minutes: 1))),
          Duration.zero,
        );
      });

      test('uses the stored duration once finished', () {
        final PlaySession done = running.copyWith(
          endedAt: t0.add(const Duration(hours: 1)),
          durationSeconds: 120,
        );
        expect(done.elapsed(t0.add(const Duration(days: 9))),
            const Duration(minutes: 2));
        expect(done.countedMinutes, 2);
      });
    });

    test('survives a database round trip', () {
      final PlaySession s = PlaySession(
        id: 3,
        itemId: 4,
        playthroughId: 5,
        startedAt: t0,
        endedAt: t0.add(const Duration(minutes: 1)),
        durationSeconds: 60,
        note: 'n',
        progressLabel: 'p',
        createdAt: t0,
      );
      final PlaySession back = PlaySession.fromDb(s.toDb());
      expect(back.id, 3);
      expect(back.playthroughId, 5);
      expect(back.endedAt, s.endedAt);
      expect(back.note, 'n');
      expect(back.progressLabel, 'p');
    });

    test('copyWith clear flags drop optional fields', () {
      final PlaySession s = PlaySession(
        id: 1,
        itemId: 1,
        playthroughId: 2,
        startedAt: t0,
        durationSeconds: 0,
        note: 'n',
        progressLabel: 'p',
        createdAt: t0,
      );
      final PlaySession cleared = s.copyWith(
        clearPlaythrough: true,
        clearNote: true,
        clearProgressLabel: true,
      );
      expect(cleared.playthroughId, isNull);
      expect(cleared.note, isNull);
      expect(cleared.progressLabel, isNull);
    });
  });

  group('PlaythroughStatus.fromString', () {
    test('maps known values and falls back to in progress', () {
      expect(PlaythroughStatus.fromString('completed'),
          PlaythroughStatus.completed);
      expect(PlaythroughStatus.fromString('dropped'), PlaythroughStatus.dropped);
      expect(PlaythroughStatus.fromString('???'), PlaythroughStatus.inProgress);
      expect(PlaythroughStatus.fromString(null), PlaythroughStatus.inProgress);
    });
  });

  group('Playthrough', () {
    test('isValidRating accepts null and the 1-10 scale only', () {
      expect(Playthrough.isValidRating(null), isTrue);
      expect(Playthrough.isValidRating(1), isTrue);
      expect(Playthrough.isValidRating(10), isTrue);
      expect(Playthrough.isValidRating(0.5), isFalse);
      expect(Playthrough.isValidRating(11), isFalse);
      expect(Playthrough.isValidRating(double.nan), isFalse);
    });

    test('hasReview ignores whitespace', () {
      final Playthrough p = Playthrough(
        id: 1,
        itemId: 1,
        status: PlaythroughStatus.inProgress,
        review: '   ',
        createdAt: t0,
        updatedAt: t0,
      );
      expect(p.hasReview, isFalse);
      expect(p.copyWith(review: 'great').hasReview, isTrue);
      expect(p.copyWith(clearReview: true).hasReview, isFalse);
    });
  });

  group('JournalEntryKind.fromString', () {
    test('maps known values and falls back to note', () {
      expect(JournalEntryKind.fromString('quote'), JournalEntryKind.quote);
      expect(JournalEntryKind.fromString('nope'), JournalEntryKind.note);
      expect(JournalEntryKind.fromString(null), JournalEntryKind.note);
    });
  });

  group('JournalEntry.isEmpty', () {
    JournalEntry make({String? body, String? image}) => JournalEntry(
          id: 0,
          itemId: 1,
          kind: JournalEntryKind.note,
          body: body,
          imagePath: image,
          isSpoiler: false,
          occurredAt: t0,
          createdAt: t0,
          updatedAt: t0,
        );

    test('is empty with blank text and no image', () {
      expect(make().isEmpty, isTrue);
      expect(make(body: '  ').isEmpty, isTrue);
    });

    test('is not empty with text or an image', () {
      expect(make(body: 'x').isEmpty, isFalse);
      expect(make(image: '/a.png').isEmpty, isFalse);
    });
  });

  group('ResumeBookmark', () {
    test('isEmpty when every field is blank', () {
      expect(ResumeBookmark(itemId: 1, updatedAt: t0).isEmpty, isTrue);
      expect(
        ResumeBookmark(itemId: 1, notes: ' ', updatedAt: t0).isEmpty,
        isTrue,
      );
      expect(
        ResumeBookmark(itemId: 1, reminders: 'jump = A', updatedAt: t0)
            .isEmpty,
        isFalse,
      );
    });

    test('toDb stores blanks as null', () {
      final Map<String, dynamic> row = ResumeBookmark(
        itemId: 1,
        position: '  ',
        objective: ' boss ',
        updatedAt: t0,
      ).toDb();
      expect(row['position'], isNull);
      expect(row['objective'], 'boss');
    });
  });
}
