import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/app_localizations.dart';
import '../../../shared/navigation/search_providers.dart';
import '../../../shared/theme/app_spacing.dart';
import '../../home/screens/all_items_screen.dart';
import '../providers/today_providers.dart';
import 'today_view.dart';

/// The home tab: Today on top of the untouched library grid, both kept
/// alive so switching back never loses the library's scroll or search.
class HomeTab extends ConsumerWidget {
  const HomeTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final S l = S.of(context);
    final HomeMode mode = ref.watch(homeModeProvider);
    // A search sent to the home tab is a library search.
    ref.listen<MetaSearchRequest?>(homeMetaSearchRequestProvider, (
      MetaSearchRequest? _,
      MetaSearchRequest? request,
    ) {
      if (request != null) {
        ref.read(homeModeProvider.notifier).select(HomeMode.library);
      }
    });

    return Column(
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.md,
              AppSpacing.sm,
              AppSpacing.md,
              0,
            ),
            child: SegmentedButton<HomeMode>(
              showSelectedIcon: false,
              segments: <ButtonSegment<HomeMode>>[
                ButtonSegment<HomeMode>(
                  value: HomeMode.today,
                  icon: const Icon(Icons.wb_sunny_outlined),
                  label: Text(l.homeToday),
                ),
                ButtonSegment<HomeMode>(
                  value: HomeMode.library,
                  icon: const Icon(Icons.grid_view),
                  label: Text(l.homeLibrary),
                ),
              ],
              selected: <HomeMode>{mode},
              onSelectionChanged: (Set<HomeMode> s) =>
                  ref.read(homeModeProvider.notifier).select(s.first),
            ),
          ),
          Expanded(
            child: IndexedStack(
              index: mode.index,
              children: const <Widget>[TodayView(), AllItemsScreen()],
            ),
          ),
        ],
    );
  }
}
