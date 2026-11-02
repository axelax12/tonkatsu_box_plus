import 'package:core/models/collection_item.dart';
import 'package:core/models/item_status.dart';
import 'package:core/plus/analytics/path_walk.dart';
import 'package:core/plus/analytics/release_reminders.dart';
import 'package:core/plus/models/media_path.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../shared/constants/platform_features.dart';
import '../../insights/providers/insights_providers.dart';
import '../../paths/providers/paths_providers.dart';
import '../../settings/providers/settings_provider.dart';

enum TodaySection { resume, goals, upNext, releases, backlog, lists }

/// Which sections the home shows and in what order; unknown names from an
/// older or newer build are dropped and missing ones appended.
class TodayLayout {
  const TodayLayout({required this.order, required this.hidden});

  factory TodayLayout.decode(String? raw) {
    final List<TodaySection> order = <TodaySection>[];
    final Set<TodaySection> hidden = <TodaySection>{};
    for (final String part in (raw ?? '').split(',')) {
      final bool off = part.startsWith(_hiddenMark);
      final String name = off ? part.substring(_hiddenMark.length) : part;
      final TodaySection? section = TodaySection.values
          .where((TodaySection s) => s.name == name)
          .firstOrNull;
      if (section == null || order.contains(section)) continue;
      order.add(section);
      if (off) hidden.add(section);
    }
    for (final TodaySection s in TodaySection.values) {
      if (!order.contains(s)) order.add(s);
    }
    return TodayLayout(order: order, hidden: hidden);
  }

  static const String _hiddenMark = '-';

  final List<TodaySection> order;
  final Set<TodaySection> hidden;

  List<TodaySection> get visible => <TodaySection>[
    for (final TodaySection s in order)
      if (!hidden.contains(s)) s,
  ];

  String encode() => <String>[
    for (final TodaySection s in order)
      hidden.contains(s) ? '$_hiddenMark${s.name}' : s.name,
  ].join(',');
}

class TodayLayoutNotifier extends Notifier<TodayLayout> {
  static const String prefsKey = 'plus_today_layout';

  SharedPreferences get _prefs => ref.read(sharedPreferencesProvider);

  @override
  TodayLayout build() => TodayLayout.decode(_prefs.getString(prefsKey));

  Future<void> _save(TodayLayout layout) async {
    state = layout;
    await _prefs.setString(prefsKey, layout.encode());
  }

  Future<void> move(int from, int to) {
    final List<TodaySection> order = List<TodaySection>.of(state.order);
    final TodaySection moved = order.removeAt(from);
    order.insert(to, moved);
    return _save(TodayLayout(order: order, hidden: state.hidden));
  }

  Future<void> setVisible(TodaySection section, {required bool visible}) {
    final Set<TodaySection> hidden = Set<TodaySection>.of(state.hidden);
    if (visible) {
      hidden.remove(section);
    } else {
      hidden.add(section);
    }
    return _save(TodayLayout(order: state.order, hidden: hidden));
  }
}

final NotifierProvider<TodayLayoutNotifier, TodayLayout> todayLayoutProvider =
    NotifierProvider<TodayLayoutNotifier, TodayLayout>(TodayLayoutNotifier.new);

enum HomeMode { today, library }

/// The home opens on Today on the phone; elsewhere the library stays first.
class HomeModeNotifier extends Notifier<HomeMode> {
  static const String prefsKey = 'plus_home_mode';

  @override
  HomeMode build() {
    final String? stored = ref
        .read(sharedPreferencesProvider)
        .getString(prefsKey);
    for (final HomeMode m in HomeMode.values) {
      if (m.name == stored) return m;
    }
    return kIsMobile ? HomeMode.today : HomeMode.library;
  }

  Future<void> select(HomeMode mode) async {
    state = mode;
    await ref.read(sharedPreferencesProvider).setString(prefsKey, mode.name);
  }
}

final NotifierProvider<HomeModeNotifier, HomeMode> homeModeProvider =
    NotifierProvider<HomeModeNotifier, HomeMode>(HomeModeNotifier.new);

/// Works being played, watched or read, the most recently touched first.
final FutureProvider<List<CollectionItem>> inProgressItemsProvider =
    FutureProvider<List<CollectionItem>>((Ref ref) async {
      final List<CollectionItem> items = await ref.watch(
        libraryItemsProvider.future,
      );
      final List<CollectionItem> active = <CollectionItem>[
        for (final CollectionItem i in items)
          if (i.status == ItemStatus.inProgress ||
              i.status == ItemStatus.replaying)
            i,
      ];
      DateTime touched(CollectionItem i) =>
          i.lastActivityAt ?? i.startedAt ?? i.addedAt;
      active.sort(
        (CollectionItem a, CollectionItem b) =>
            touched(b).compareTo(touched(a)),
      );
      return active;
    });

final FutureProvider<List<ReleaseReminder>> upcomingReleasesProvider =
    FutureProvider<List<ReleaseReminder>>((Ref ref) async {
      const int shown = 12;
      final List<CollectionItem> items = await ref.watch(
        libraryItemsProvider.future,
      );
      return ReleaseReminders.plan(items, DateTime.now(), limit: shown);
    });

typedef UpNext = ({MediaPath path, PathStop stop});

/// The stop to pick up on every unfinished path, spoiler stops left out.
final FutureProvider<List<UpNext>> upNextProvider =
    FutureProvider<List<UpNext>>((Ref ref) async {
      final List<MediaPath> paths = await ref.watch(pathsProvider.future);
      final List<UpNext> result = <UpNext>[];
      for (final MediaPath path in paths) {
        final PathWalk walk = await ref.watch(
          pathWalkProvider((pathId: path.id, order: path.defaultOrder)).future,
        );
        final PathStop? stop = walk.current;
        if (stop == null || stop.hidden || stop.item == null) continue;
        result.add((path: path, stop: stop));
      }
      return result;
    });
