import 'package:sqflite_common/sqlite_api.dart';

import '../models/price_snapshot.dart';

typedef SteamSync = ({int earned, int total, DateTime syncedAt});

class IntegrationsDao {
  const IntegrationsDao(this._getDatabase);

  final Future<Database> Function() _getDatabase;

  static const String _apps = 'plus_steam_apps';
  static const String _sync = 'plus_steam_sync';
  static const String _prices = 'plus_prices';

  /// Only games already looked up appear; a null value means "no Steam page".
  Future<Map<int, String?>> getSteamApps(List<int> igdbIds) async {
    if (igdbIds.isEmpty) return <int, String?>{};
    final Database db = await _getDatabase();
    final String marks = List<String>.filled(igdbIds.length, '?').join(', ');
    final List<Map<String, dynamic>> rows = await db.query(
      _apps,
      where: 'igdb_game_id IN ($marks)',
      whereArgs: igdbIds,
    );
    return <int, String?>{
      for (final Map<String, dynamic> r in rows)
        r['igdb_game_id'] as int: r['app_id'] as String?,
    };
  }

  Future<void> saveSteamApps(
    Map<int, String?> links, {
    required DateTime now,
  }) async {
    if (links.isEmpty) return;
    final Database db = await _getDatabase();
    final Batch batch = db.batch();
    links.forEach((int igdbId, String? appId) {
      batch.insert(_apps, <String, Object?>{
        'igdb_game_id': igdbId,
        'app_id': appId,
        'checked_at': now.millisecondsSinceEpoch,
      }, conflictAlgorithm: ConflictAlgorithm.replace);
    });
    await batch.commit(noResult: true);
  }

  Future<SteamSync?> getSteamSync(String appId) async {
    final Database db = await _getDatabase();
    final List<Map<String, dynamic>> rows = await db.query(
      _sync,
      where: 'app_id = ?',
      whereArgs: <Object?>[appId],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    final Map<String, dynamic> r = rows.first;
    return (
      earned: r['earned'] as int,
      total: r['total'] as int,
      syncedAt: DateTime.fromMillisecondsSinceEpoch(r['synced_at'] as int),
    );
  }

  Future<void> saveSteamSync(
    String appId, {
    required int earned,
    required int total,
    required DateTime now,
  }) async {
    final Database db = await _getDatabase();
    await db.insert(_sync, <String, Object?>{
      'app_id': appId,
      'earned': earned,
      'total': total,
      'synced_at': now.millisecondsSinceEpoch,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<PriceSnapshot?> getPrice(int itemId) async {
    final Database db = await _getDatabase();
    final List<Map<String, dynamic>> rows = await db.query(
      _prices,
      where: 'item_id = ?',
      whereArgs: <Object?>[itemId],
      limit: 1,
    );
    return rows.isEmpty ? null : PriceSnapshot.fromDb(rows.first);
  }

  Future<List<PriceSnapshot>> getAllPrices() async {
    final Database db = await _getDatabase();
    final List<Map<String, dynamic>> rows = await db.query(_prices);
    return rows.map(PriceSnapshot.fromDb).toList();
  }

  Future<void> savePrices(List<PriceSnapshot> snapshots) async {
    if (snapshots.isEmpty) return;
    final Database db = await _getDatabase();
    final Batch batch = db.batch();
    for (final PriceSnapshot s in snapshots) {
      batch.insert(
        _prices,
        s.toDb(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    await batch.commit(noResult: true);
  }
}
