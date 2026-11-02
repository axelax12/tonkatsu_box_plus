import 'package:core/models/collection_item.dart';
import 'package:core/plus/analytics/collector_insights.dart';
import 'package:core/plus/analytics/time_estimator.dart';
import 'package:core/plus/database/copies_dao.dart';
import 'package:core/plus/models/owned_copy.dart';
import 'package:core/plus/models/play_session.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/database/database_service.dart';
import '../../insights/providers/insights_providers.dart';
import '../../journal/providers/journal_providers.dart';
import '../../settings/providers/settings_provider.dart';

final Provider<CopiesDao> copiesDaoProvider = Provider<CopiesDao>((Ref ref) {
  final DatabaseService db = ref.watch(databaseServiceProvider);
  return CopiesDao(() => db.database);
});

final FutureProviderFamily<List<OwnedCopy>, int> itemCopiesProvider =
    FutureProvider.family<List<OwnedCopy>, int>(
      (Ref ref, int itemId) => ref.watch(copiesDaoProvider).getForItem(itemId),
    );

final FutureProvider<List<OwnedCopy>> allCopiesProvider =
    FutureProvider<List<OwnedCopy>>(
      (Ref ref) => ref.watch(copiesDaoProvider).getAll(),
    );

final FutureProvider<List<OwnedCopy>> activeLoansProvider =
    FutureProvider<List<OwnedCopy>>((Ref ref) {
      ref.watch(allCopiesProvider);
      return ref.read(copiesDaoProvider).getActiveLoans();
    });

final FutureProvider<CollectionValue> collectionValueProvider =
    FutureProvider<CollectionValue>((Ref ref) async {
      final List<OwnedCopy> copies = await ref.watch(allCopiesProvider.future);
      return CollectionValue.compute(copies, DateTime.now());
    });

final FutureProvider<List<KeepsakeProgress>> keepsakesProvider =
    FutureProvider<List<KeepsakeProgress>>((Ref ref) async {
      final List<CollectionItem> items = await ref.watch(
        libraryItemsProvider.future,
      );
      final List<OwnedCopy> copies = await ref.watch(allCopiesProvider.future);
      ref.watch(allRunningSessionsProvider);
      final DateTime now = DateTime.now();
      final List<PlaySession> sessions = await ref
          .read(journalDaoProvider)
          .getSessionsBetween(DateTime(1970), now.add(const Duration(days: 1)));
      final int entries = await ref.read(journalDaoProvider).countEntries();
      return Keepsakes.compute(
        items: items,
        sessions: sessions,
        journalEntryCount: entries,
        copies: copies,
      );
    });

enum RoomTheme { wood, midnight, neon }

enum RoomSource { owned, favorites, finishedThisYear }

const String _roomThemeKey = 'plus_room_theme';
const String _roomSourceKey = 'plus_room_source';

final NotifierProvider<RoomThemeNotifier, RoomTheme> roomThemeProvider =
    NotifierProvider<RoomThemeNotifier, RoomTheme>(RoomThemeNotifier.new);

class RoomThemeNotifier extends Notifier<RoomTheme> {
  @override
  RoomTheme build() {
    final String? saved = ref
        .read(sharedPreferencesProvider)
        .getString(_roomThemeKey);
    return RoomTheme.values
            .where((RoomTheme t) => t.name == saved)
            .firstOrNull ??
        RoomTheme.wood;
  }

  Future<void> set(RoomTheme theme) async {
    state = theme;
    final SharedPreferences prefs = ref.read(sharedPreferencesProvider);
    await prefs.setString(_roomThemeKey, theme.name);
  }
}

final NotifierProvider<RoomSourceNotifier, RoomSource> roomSourceProvider =
    NotifierProvider<RoomSourceNotifier, RoomSource>(RoomSourceNotifier.new);

class RoomSourceNotifier extends Notifier<RoomSource> {
  @override
  RoomSource build() {
    final String? saved = ref
        .read(sharedPreferencesProvider)
        .getString(_roomSourceKey);
    return RoomSource.values
            .where((RoomSource s) => s.name == saved)
            .firstOrNull ??
        RoomSource.owned;
  }

  Future<void> set(RoomSource source) async {
    state = source;
    final SharedPreferences prefs = ref.read(sharedPreferencesProvider);
    await prefs.setString(_roomSourceKey, source.name);
  }
}

/// What stands on the shelves for the chosen source, newest first.
final FutureProvider<List<CollectionItem>>
roomItemsProvider = FutureProvider<List<CollectionItem>>((Ref ref) async {
  final RoomSource source = ref.watch(roomSourceProvider);
  final List<CollectionItem> items = await ref.watch(
    libraryItemsProvider.future,
  );
  final List<CollectionItem> result;
  switch (source) {
    case RoomSource.owned:
      final List<OwnedCopy> copies = await ref.watch(allCopiesProvider.future);
      final Set<int> owned = <int>{
        for (final OwnedCopy c in copies)
          if (c.format == CopyFormat.physical) c.itemId,
      };
      result = items.where((CollectionItem i) => owned.contains(i.id)).toList();
    case RoomSource.favorites:
      result = items.where((CollectionItem i) => i.isFavorite).toList();
    case RoomSource.finishedThisYear:
      final int year = DateTime.now().year;
      result = items
          .where(
            (CollectionItem i) =>
                isFinishedStatus(i.status) && i.completedAt?.year == year,
          )
          .toList();
  }
  return result..sort(
    (CollectionItem a, CollectionItem b) => b.addedAt.compareTo(a.addedAt),
  );
});

final Provider<CopiesController> copiesControllerProvider =
    Provider<CopiesController>(CopiesController.new);

class CopiesController {
  CopiesController(this._ref);

  final Ref _ref;

  CopiesDao get _dao => _ref.read(copiesDaoProvider);

  Future<void> save(OwnedCopy copy) async {
    await _dao.save(copy);
    _refresh(copy.itemId);
  }

  Future<void> delete(OwnedCopy copy) async {
    await _dao.delete(copy.id);
    _refresh(copy.itemId);
  }

  Future<void> lend(
    OwnedCopy copy, {
    required String to,
    DateTime? dueAt,
  }) async {
    await _dao.lend(copy.id, to: to, now: DateTime.now(), dueAt: dueAt);
    _refresh(copy.itemId);
  }

  Future<void> markReturned(OwnedCopy copy) async {
    await _dao.markReturned(copy.id, now: DateTime.now());
    _refresh(copy.itemId);
  }

  void _refresh(int itemId) {
    _ref.invalidate(itemCopiesProvider(itemId));
    _ref.invalidate(allCopiesProvider);
  }
}
