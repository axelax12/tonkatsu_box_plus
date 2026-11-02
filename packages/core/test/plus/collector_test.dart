import 'package:core/models/collection_item.dart';
import 'package:core/models/item_status.dart';
import 'package:core/models/media_type.dart';
import 'package:core/plus/analytics/collector_insights.dart';
import 'package:core/plus/database/copies_dao.dart';
import 'package:core/plus/models/owned_copy.dart';
import 'package:core/plus/models/play_session.dart';
import 'package:core/testing/builders.dart';
import 'package:test/test.dart';

import 'plus_test_db.dart';

void main() {
  final DateTime t0 = DateTime(2026, 3, 1);

  OwnedCopy copy({
    int id = 0,
    int itemId = 1,
    CopyFormat format = CopyFormat.physical,
    double? price,
    String? currency,
    String? loanedTo,
    DateTime? due,
  }) => OwnedCopy(
    id: id,
    itemId: itemId,
    format: format,
    pricePaid: price,
    currency: currency,
    loanedTo: loanedTo,
    loanDueAt: due,
    createdAt: t0,
    updatedAt: t0,
  );

  group('OwnedCopy', () {
    test('round-trips through the database row', () {
      final OwnedCopy original = copy(id: 3, price: 59.9, currency: ' eur ')
          .copyWith(
            edition: 'Collector',
            condition: CopyCondition.sealed,
            purchasedAt: t0,
            store: 'Shop',
          );
      final OwnedCopy back = OwnedCopy.fromDb(original.toDb());
      expect(back.edition, 'Collector');
      expect(back.condition, CopyCondition.sealed);
      expect(back.currency, 'EUR');
      expect(back.pricePaid, 59.9);
      expect(back.purchasedAt, t0);
    });

    test('loan state and overdue', () {
      expect(copy().isLoaned, isFalse);
      expect(copy(loanedTo: '  ').isLoaned, isFalse);
      final OwnedCopy lent = copy(loanedTo: 'Marco', due: t0);
      expect(lent.isLoaned, isTrue);
      expect(lent.isOverdue(t0.add(const Duration(days: 1))), isTrue);
      expect(lent.isOverdue(t0.subtract(const Duration(days: 1))), isFalse);
      expect(copy(loanedTo: 'Marco').isOverdue(t0), isFalse);
      expect(lent.copyWith(clearLoan: true).isLoaned, isFalse);
    });

    test('unknown enum values degrade gracefully', () {
      expect(CopyFormat.fromString('vinyl'), CopyFormat.physical);
      expect(CopyFormat.fromString('digital'), CopyFormat.digital);
      expect(CopyCondition.tryFromString('perfect'), isNull);
    });
  });

  group('CopiesDao', () {
    late PlusTestDb t;
    late CopiesDao dao;
    late int itemId;

    setUp(() async {
      t = await PlusTestDb.open();
      dao = CopiesDao(() async => t.db);
      itemId = await t.newItem();
    });
    tearDown(() async => t.close());

    test('save, lend, return and delete', () async {
      final OwnedCopy saved = await dao.save(copy(itemId: itemId));
      expect(await dao.getForItem(itemId), hasLength(1));
      expect(await dao.getActiveLoans(), isEmpty);

      await dao.lend(
        saved.id,
        to: ' Giulia ',
        now: t0,
        dueAt: t0.add(const Duration(days: 14)),
      );
      final List<OwnedCopy> loans = await dao.getActiveLoans();
      expect(loans.single.loanedTo, 'Giulia');
      expect(loans.single.loanedAt, t0);

      await dao.markReturned(saved.id, now: t0);
      expect(await dao.getActiveLoans(), isEmpty);

      await dao.save(saved.copyWith(edition: 'GOTY'));
      expect((await dao.getAll()).single.edition, 'GOTY');

      await dao.delete(saved.id);
      expect(await dao.getAll(), isEmpty);
    });

    test('copies go with their item', () async {
      await dao.save(copy(itemId: itemId));
      await t.db.delete(
        'collection_items',
        where: 'id = ?',
        whereArgs: <Object?>[itemId],
      );
      expect(await dao.getAll(), isEmpty);
    });
  });

  group('CollectionValue', () {
    test('totals per currency and counts loans', () {
      final CollectionValue value = CollectionValue.compute(<OwnedCopy>[
        copy(price: 60, currency: 'eur'),
        copy(price: 20, currency: 'EUR', format: CopyFormat.digital),
        copy(price: 5000, currency: 'JPY'),
        copy(price: 10),
        copy(loanedTo: 'Ada', due: t0),
        copy(price: 0, currency: 'EUR'),
      ], t0.add(const Duration(days: 1)));
      expect(value.physicalCount, 5);
      expect(value.digitalCount, 1);
      expect(value.spentByCurrency['EUR'], 80);
      expect(value.spentByCurrency['JPY'], 5000);
      expect(value.spentByCurrency[CollectionValue.unknownCurrency], 10);
      expect(value.activeLoans, 1);
      expect(value.overdueLoans, 1);
    });
  });

  group('Keepsakes', () {
    test('nothing is unlocked for an empty library', () {
      final List<KeepsakeProgress> all = Keepsakes.compute(
        items: const <CollectionItem>[],
        sessions: const <PlaySession>[],
        journalEntryCount: 0,
        copies: const <OwnedCopy>[],
      );
      expect(all, hasLength(Keepsake.values.length));
      expect(all.where((KeepsakeProgress k) => k.unlocked), isEmpty);
    });

    test('unlocks from finishes, sessions, journal and shelves', () {
      final List<CollectionItem> items = <CollectionItem>[
        createTestCollectionItem(
          id: 1,
          status: ItemStatus.completed,
          userRating: 8,
          addedAt: DateTime(2024, 1, 1),
          completedAt: DateTime(2026, 1, 1),
        ),
        createTestCollectionItem(
          id: 2,
          mediaType: MediaType.book,
          status: ItemStatus.completed,
          completedAt: DateTime(2026, 2, 1),
        ),
      ];
      final List<PlaySession> sessions = <PlaySession>[
        for (int d = 1; d <= 7; d++)
          PlaySession(
            id: d,
            itemId: 1,
            startedAt: DateTime(2026, 1, d, 20),
            endedAt: DateTime(2026, 1, d, 21),
            durationSeconds: d == 1 ? Keepsakes.marathonSeconds : 3600,
            createdAt: DateTime(2026, 1, d),
          ),
      ];
      final Map<Keepsake, KeepsakeProgress> byKind =
          <Keepsake, KeepsakeProgress>{
            for (final KeepsakeProgress p in Keepsakes.compute(
              items: items,
              sessions: sessions,
              journalEntryCount: 30,
              copies: <OwnedCopy>[copy()],
            ))
              p.keepsake: p,
          };

      expect(byKind[Keepsake.firstFinish]?.unlocked, isTrue);
      expect(byKind[Keepsake.tenFinished]?.unlocked, isFalse);
      expect(byKind[Keepsake.tenFinished]?.fraction, closeTo(0.2, 1e-9));
      expect(byKind[Keepsake.polymath]?.value, 2);
      expect(byKind[Keepsake.marathon]?.unlocked, isTrue);
      expect(byKind[Keepsake.weekStreak]?.unlocked, isTrue);
      expect(byKind[Keepsake.journalist]?.unlocked, isTrue);
      expect(byKind[Keepsake.journalist]?.fraction, 1);
      expect(byKind[Keepsake.shelfBuilder]?.value, 1);
      expect(byKind[Keepsake.backlogBuster]?.value, 1);
      expect(byKind[Keepsake.critic]?.value, 1);
      expect(byKind[Keepsake.hundredHours]?.value, 10);
    });
  });
}
