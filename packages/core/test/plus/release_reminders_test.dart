import 'package:core/models/collection_item.dart';
import 'package:core/models/item_status.dart';
import 'package:core/plus/analytics/release_reminders.dart';
import 'package:core/testing/builders.dart';
import 'package:test/test.dart';

void main() {
  final DateTime now = DateTime(2026, 11, 2, 15);

  CollectionItem game(int id, DateTime? release, ItemStatus status) =>
      createTestCollectionItem(
        id: id,
        status: status,
        game: createTestGame(id: id, name: 'G$id', releaseDate: release),
      );

  group('ReleaseReminders.plan', () {
    test('keeps future releases on the backlog, soonest first', () {
      final List<ReleaseReminder> plan = ReleaseReminders.plan(<CollectionItem>[
        game(1, DateTime(2026, 12, 5), ItemStatus.planned),
        game(2, DateTime(2026, 11, 20), ItemStatus.notStarted),
        game(3, DateTime(2026, 11, 2, 23), ItemStatus.planned),
        game(4, DateTime(2026, 12, 1), ItemStatus.inProgress),
        game(5, null, ItemStatus.planned),
        game(6, DateTime(2028, 1, 1), ItemStatus.planned),
        game(7, DateTime(2026, 1, 1), ItemStatus.planned),
      ], now);
      expect(plan.map((ReleaseReminder r) => r.itemId), <int>[2, 1]);
      expect(plan.first.releaseDay, DateTime(2026, 11, 20));
      expect(plan.first.title, 'G2');
    });

    test('caps the count and signs the plan', () {
      final List<CollectionItem> items = <CollectionItem>[
        for (int i = 1; i <= 5; i++)
          game(i, DateTime(2027, 1, i), ItemStatus.planned),
      ];
      final List<ReleaseReminder> plan = ReleaseReminders.plan(
        items,
        now,
        limit: 3,
      );
      expect(plan, hasLength(3));
      expect(
        ReleaseReminders.signature(plan),
        isNot(ReleaseReminders.signature(plan.sublist(1))),
      );
      expect(ReleaseReminders.signature(const <ReleaseReminder>[]), isEmpty);
    });
  });
}
