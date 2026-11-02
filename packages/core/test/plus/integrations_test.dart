import 'package:core/plus/database/integrations_dao.dart';
import 'package:core/plus/models/price_snapshot.dart';
import 'package:test/test.dart';

import 'plus_test_db.dart';

void main() {
  final DateTime t0 = DateTime(2026, 2, 2);

  PriceSnapshot snap({
    int itemId = 1,
    double? price,
    double? low,
    double? alerted,
  }) => PriceSnapshot(
    itemId: itemId,
    itadId: 'uuid',
    price: price,
    lowPrice: low,
    alertedLow: alerted,
    currency: 'EUR',
    checkedAt: t0,
  );

  group('PriceSnapshot', () {
    test('detects the historic low within a cent', () {
      expect(snap(price: 9.99, low: 9.99).isAtHistoricLow, isTrue);
      expect(snap(price: 10, low: 9.99).isAtHistoricLow, isTrue);
      expect(snap(price: 10.5, low: 9.99).isAtHistoricLow, isFalse);
      expect(snap(price: 0, low: 0).isAtHistoricLow, isFalse);
      expect(snap(low: 5).isAtHistoricLow, isFalse);
    });

    test('alerts once per new low', () {
      expect(snap(price: 9.99, low: 9.99).shouldAlert, isTrue);
      expect(snap(price: 9.99, low: 9.99, alerted: 9.99).shouldAlert, isFalse);
      expect(snap(price: 7.99, low: 7.99, alerted: 9.99).shouldAlert, isTrue);
      expect(snap(price: 20, low: 9.99).shouldAlert, isFalse);
    });

    test('round-trips through a row', () {
      final PriceSnapshot back = PriceSnapshot.fromDb(
        snap(price: 9.99, low: 4.99, alerted: 4.99).toDb(),
      );
      expect(back.price, 9.99);
      expect(back.lowPrice, 4.99);
      expect(back.alertedLow, 4.99);
      expect(back.copyWith(alertedLow: 3).alertedLow, 3);
    });
  });

  group('IntegrationsDao', () {
    late PlusTestDb t;
    late IntegrationsDao dao;

    setUp(() async {
      t = await PlusTestDb.open();
      dao = IntegrationsDao(() async => t.db);
    });
    tearDown(() async => t.close());

    test('remembers Steam links, misses included', () async {
      await dao.saveSteamApps(<int, String?>{1: '570', 2: null}, now: t0);
      expect(await dao.getSteamApps(<int>[1, 2, 3]), <int, String?>{
        1: '570',
        2: null,
      });
      expect(await dao.getSteamApps(<int>[]), isEmpty);
    });

    test('stores the last achievement sync', () async {
      expect(await dao.getSteamSync('570'), isNull);
      await dao.saveSteamSync('570', earned: 3, total: 10, now: t0);
      final SteamSync? sync = await dao.getSteamSync('570');
      expect(sync?.earned, 3);
      expect(sync?.total, 10);
      expect(sync?.syncedAt, t0);
    });

    test('prices replace per item and go with their item', () async {
      final int itemId = await t.newItem();
      await dao.savePrices(<PriceSnapshot>[snap(itemId: itemId, price: 20)]);
      await dao.savePrices(<PriceSnapshot>[snap(itemId: itemId, price: 15)]);
      expect((await dao.getPrice(itemId))?.price, 15);
      expect(await dao.getAllPrices(), hasLength(1));

      await t.db.delete(
        'collection_items',
        where: 'id = ?',
        whereArgs: <Object?>[itemId],
      );
      expect(await dao.getPrice(itemId), isNull);
    });
  });
}
