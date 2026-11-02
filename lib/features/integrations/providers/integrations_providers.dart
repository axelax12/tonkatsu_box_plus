import 'dart:ui' as ui;

import 'package:core/models/collection_item.dart';
import 'package:core/models/item_status.dart';
import 'package:core/models/media_type.dart';
import 'package:core/models/tracker_achievement.dart';
import 'package:core/models/tracker_profile.dart';
import 'package:core/plus/database/integrations_dao.dart';
import 'package:core/plus/models/price_snapshot.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logging/logging.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/api/igdb_api.dart';
import '../../../core/database/database_service.dart';
import '../../insights/providers/insights_providers.dart';
import '../../settings/providers/settings_provider.dart';
import '../itad_api.dart';
import '../steam_achievements_api.dart';

final Logger _log = Logger('Integrations');

const String kItadKeyPref = 'plus_itad_api_key';
const String kItadCountryPref = 'plus_itad_country';

final Provider<IntegrationsDao> integrationsDaoProvider =
    Provider<IntegrationsDao>((Ref ref) {
      final DatabaseService db = ref.watch(databaseServiceProvider);
      return IntegrationsDao(() => db.database);
    });

final Provider<SteamAchievementsApi> steamAchievementsApiProvider =
    Provider<SteamAchievementsApi>((Ref ref) => SteamAchievementsApi());

final Provider<ItadApi> itadApiProvider = Provider<ItadApi>(
  (Ref ref) => ItadApi(),
);

typedef SteamCredentials = ({String apiKey, String steamId});

typedef ItadSettings = ({String apiKey, String country});

/// Read on demand: upstream's Steam import owns these keys.
final Provider<SteamCredentials?> steamCredentialsProvider =
    Provider<SteamCredentials?>((Ref ref) {
      ref.watch(credentialsRevisionProvider);
      final SharedPreferences prefs = ref.read(sharedPreferencesProvider);
      final String key =
          prefs.getString(SettingsKeys.steamApiKey)?.trim() ?? '';
      final String id = prefs.getString(SettingsKeys.steamId)?.trim() ?? '';
      return key.isEmpty || id.isEmpty ? null : (apiKey: key, steamId: id);
    });

final Provider<ItadSettings?> itadSettingsProvider = Provider<ItadSettings?>((
  Ref ref,
) {
  ref.watch(credentialsRevisionProvider);
  final SharedPreferences prefs = ref.read(sharedPreferencesProvider);
  final String key = prefs.getString(kItadKeyPref)?.trim() ?? '';
  if (key.isEmpty) return null;
  return (apiKey: key, country: itadCountry(prefs));
});

String itadCountry(SharedPreferences prefs) {
  final String saved = prefs.getString(kItadCountryPref)?.trim() ?? '';
  if (saved.length == 2) return saved.toUpperCase();
  final String? device = ui.PlatformDispatcher.instance.locale.countryCode;
  return (device == null || device.length != 2) ? 'US' : device.toUpperCase();
}

/// Bumped after credentials are saved so the providers above re-read prefs.
final StateProvider<int> credentialsRevisionProvider = StateProvider<int>(
  (Ref ref) => 0,
);

final FutureProviderFamily<String?, int> steamAppProvider =
    FutureProvider.family<String?, int>((Ref ref, int igdbId) async {
      final IntegrationsDao dao = ref.watch(integrationsDaoProvider);
      final Map<int, String?> cached = await dao.getSteamApps(<int>[igdbId]);
      if (cached.containsKey(igdbId)) return cached[igdbId];
      try {
        final Map<int, String> found = await ref
            .read(igdbApiProvider)
            .steamAppIdsFor(<int>[igdbId]);
        await dao.saveSteamApps(<int, String?>{
          igdbId: found[igdbId],
        }, now: DateTime.now());
        return found[igdbId];
      } on Exception catch (e, stack) {
        _log.info('Steam link lookup failed for $igdbId', e, stack);
        return null;
      }
    });

final FutureProviderFamily<List<TrackerAchievement>, String>
steamAchievementsProvider =
    FutureProvider.family<List<TrackerAchievement>, String>(
      (Ref ref, String appId) => ref
          .watch(trackerDaoProvider)
          .getAchievements(TrackerType.steam, appId),
    );

final FutureProviderFamily<SteamSync?, String> steamSyncProvider =
    FutureProvider.family<SteamSync?, String>(
      (Ref ref, String appId) =>
          ref.watch(integrationsDaoProvider).getSteamSync(appId),
    );

final Provider<SteamAchievementsService> steamAchievementsServiceProvider =
    Provider<SteamAchievementsService>(SteamAchievementsService.new);

class SteamAchievementsService {
  SteamAchievementsService(this._ref);

  final Ref _ref;

  /// Throws [SteamAchievementsException]; the caller explains it to the user.
  Future<void> sync(String appId) async {
    final SteamCredentials? creds = _ref.read(steamCredentialsProvider);
    if (creds == null) {
      throw const SteamAchievementsException(SteamAchievementsReason.badKey);
    }
    final List<SteamAchievement> fetched = await _ref
        .read(steamAchievementsApiProvider)
        .fetch(apiKey: creds.apiKey, steamId: creds.steamId, appId: appId);
    final List<TrackerAchievement> rows = <TrackerAchievement>[
      for (final SteamAchievement a in fetched)
        TrackerAchievement(
          id: 0,
          trackerType: TrackerType.steam,
          trackerGameId: appId,
          achievementId: a.apiName,
          title: a.title,
          description: a.description,
          badgeName: a.achieved ? a.icon : (a.iconGray ?? a.icon),
          type: a.hidden ? 'hidden' : null,
          displayOrder: a.order,
          earned: a.achieved,
          earnedAt: a.unlockTime,
        ),
    ];
    await _ref
        .read(trackerDaoProvider)
        .replaceAchievements(TrackerType.steam, appId, rows);
    await _ref
        .read(integrationsDaoProvider)
        .saveSteamSync(
          appId,
          earned: fetched.where((SteamAchievement a) => a.achieved).length,
          total: fetched.length,
          now: DateTime.now(),
        );
    _ref.invalidate(steamAchievementsProvider(appId));
    _ref.invalidate(steamSyncProvider(appId));
  }
}

final FutureProviderFamily<PriceSnapshot?, int> itemPriceProvider =
    FutureProvider.family<PriceSnapshot?, int>(
      (Ref ref, int itemId) =>
          ref.watch(integrationsDaoProvider).getPrice(itemId),
    );

final FutureProvider<List<PriceSnapshot>> allPricesProvider =
    FutureProvider<List<PriceSnapshot>>(
      (Ref ref) => ref.watch(integrationsDaoProvider).getAllPrices(),
    );

/// Games whose price is worth watching: the ones planned, i.e. wanted.
bool isWatchedForDeals(CollectionItem item) =>
    item.mediaType == MediaType.game && item.status == ItemStatus.planned;

typedef DealAlert = ({CollectionItem item, PriceSnapshot snapshot});

final Provider<DealsService> dealsServiceProvider = Provider<DealsService>(
  DealsService.new,
);

class DealsService {
  DealsService(this._ref);

  final Ref _ref;

  /// Refreshes prices for [items] and returns the ones at a new all-time low;
  /// the caller turns those into notifications.
  Future<List<DealAlert>> refresh(List<CollectionItem> items) async {
    final ItadSettings? settings = _ref.read(itadSettingsProvider);
    if (settings == null || items.isEmpty) return <DealAlert>[];
    final IntegrationsDao dao = _ref.read(integrationsDaoProvider);
    final ItadApi api = _ref.read(itadApiProvider);
    final DateTime now = DateTime.now();

    final Map<int, PriceSnapshot> previous = <int, PriceSnapshot>{
      for (final PriceSnapshot s in await dao.getAllPrices()) s.itemId: s,
    };
    final Map<int, String> itadByItem = <int, String>{
      for (final PriceSnapshot s in previous.values)
        if (s.itadId case final String id) s.itemId: id,
    };

    final List<CollectionItem> unresolved = items
        .where((CollectionItem i) => !itadByItem.containsKey(i.id))
        .toList();
    if (unresolved.isNotEmpty) {
      final Map<int, String> steamByIgdb = await _steamApps(unresolved);
      final Map<String, String> bySteam = await api.lookupSteamApps(
        steamByIgdb.values.toSet().toList(),
        apiKey: settings.apiKey,
      );
      for (final CollectionItem item in unresolved) {
        final String? viaSteam = bySteam[steamByIgdb[item.externalId]];
        final String? id =
            viaSteam ??
            await api.lookupTitle(item.itemName, apiKey: settings.apiKey);
        if (id != null) itadByItem[item.id] = id;
      }
    }

    final List<String> ids = <String>{
      for (final CollectionItem i in items)
        if (itadByItem[i.id] case final String id) id,
    }.toList();
    final Map<String, ItadPrice> byId = <String, ItadPrice>{
      for (final ItadPrice p in await api.prices(
        ids,
        apiKey: settings.apiKey,
        country: settings.country,
      ))
        p.id: p,
    };

    final List<PriceSnapshot> snapshots = <PriceSnapshot>[];
    final List<DealAlert> alerts = <DealAlert>[];
    for (final CollectionItem item in items) {
      final String? itadId = itadByItem[item.id];
      final ItadPrice? p = itadId == null ? null : byId[itadId];
      PriceSnapshot snapshot = PriceSnapshot(
        itemId: item.id,
        itadId: itadId,
        price: p?.price,
        regular: p?.regular,
        cut: p?.cut,
        currency: p?.currency,
        shop: p?.shop,
        url: p?.url,
        lowPrice: p?.lowPrice,
        alertedLow: previous[item.id]?.alertedLow,
        checkedAt: now,
      );
      if (snapshot.shouldAlert) {
        snapshot = snapshot.copyWith(alertedLow: snapshot.price);
        alerts.add((item: item, snapshot: snapshot));
      }
      snapshots.add(snapshot);
    }
    await dao.savePrices(snapshots);
    _ref.invalidate(allPricesProvider);
    for (final CollectionItem item in items) {
      _ref.invalidate(itemPriceProvider(item.id));
    }
    return alerts;
  }

  Future<Map<int, String>> _steamApps(List<CollectionItem> items) async {
    final IntegrationsDao dao = _ref.read(integrationsDaoProvider);
    final List<int> igdbIds = <int>{
      for (final CollectionItem i in items) i.externalId,
    }.toList();
    final Map<int, String?> cached = await dao.getSteamApps(igdbIds);
    final List<int> missing = igdbIds
        .where((int id) => !cached.containsKey(id))
        .toList();
    if (missing.isNotEmpty) {
      try {
        final Map<int, String> found = await _ref
            .read(igdbApiProvider)
            .steamAppIdsFor(missing);
        final Map<int, String?> links = <int, String?>{
          for (final int id in missing) id: found[id],
        };
        await dao.saveSteamApps(links, now: DateTime.now());
        cached.addAll(links);
      } on Exception catch (e, stack) {
        _log.info('Steam links unavailable, using titles', e, stack);
      }
    }
    return <int, String>{
      for (final MapEntry<int, String?> e in cached.entries)
        if (e.value case final String appId) e.key: appId,
    };
  }
}

/// All planned games in the library, for the deals list and its refresh.
final FutureProvider<List<CollectionItem>> watchedGamesProvider =
    FutureProvider<List<CollectionItem>>((Ref ref) async {
      final List<CollectionItem> items = await ref.watch(
        libraryItemsProvider.future,
      );
      return items.where(isWatchedForDeals).toList();
    });
