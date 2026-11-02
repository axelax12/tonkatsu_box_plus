import 'package:core/models/collection_item.dart';
import 'package:core/models/media_type.dart';
import 'package:core/plus/analytics/theme_index.dart';
import 'package:core/plus/analytics/time_estimator.dart';
import 'package:core/plus/models/media_path.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/app_localizations.dart';
import '../../../shared/constants/media_type_theme.dart';
import '../../../shared/extensions/snackbar_extension.dart';
import '../../../shared/theme/app_colors.dart';
import '../../../shared/theme/app_spacing.dart';
import '../../../shared/theme/app_typography.dart';
import '../../smart_lists/widgets/item_cover_grid.dart';
import '../paths_format.dart';
import '../providers/paths_providers.dart';
import 'path_screen.dart';

/// Explore by theme: an aspect, then one thread through every medium.
class ExploreScreen extends ConsumerStatefulWidget {
  const ExploreScreen({super.key});

  @override
  ConsumerState<ExploreScreen> createState() => _ExploreScreenState();
}

class _ExploreScreenState extends ConsumerState<ExploreScreen> {
  PathAspect _aspect = PathAspect.atmosphere;
  ThemeKey? _selected;
  MediaType? _media;

  /// Unfinished works first: exploring is about what comes next.
  static List<CollectionItem> _ordered(List<CollectionItem> items) {
    final List<CollectionItem> sorted = List<CollectionItem>.of(items);
    sorted.sort((CollectionItem a, CollectionItem b) {
      final bool fa = isFinishedStatus(a.status);
      final bool fb = isFinishedStatus(b.status);
      if (fa != fb) return fa ? 1 : -1;
      return a.itemName.toLowerCase().compareTo(b.itemName.toLowerCase());
    });
    return sorted;
  }

  Future<void> _makePath(String name, List<CollectionItem> items) async {
    final S l = S.of(context);
    final int id =
        (await ref
                .read(pathsControllerProvider)
                .create(name: name, kind: PathKind.theme, items: items))
            .id;
    if (!mounted) return;
    context.showSnack(l.explorePathCreated(name), type: SnackType.success);
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (BuildContext _) => PathScreen(pathId: id),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final S l = S.of(context);
    final ThemeIndex? index = ref.watch(themeIndexProvider).valueOrNull;
    if (index == null) {
      return const Center(child: CircularProgressIndicator());
    }
    final List<ThemeKey> keys = index.keysFor(_aspect);
    final ThemeKey? selected = keys.contains(_selected) ? _selected : null;
    final List<CollectionItem> all = selected == null
        ? const <CollectionItem>[]
        : _ordered(index.itemsFor(selected));
    final Set<MediaType> media = <MediaType>{
      for (final CollectionItem i in all) i.mediaType,
    };
    final MediaType? mediaFilter = media.contains(_media) ? _media : null;
    final List<CollectionItem> shown = <CollectionItem>[
      for (final CollectionItem i in all)
        if (mediaFilter == null || i.mediaType == mediaFilter) i,
    ];
    final int toDiscover = all
        .where((CollectionItem i) => !isFinishedStatus(i.status))
        .length;

    final Widget header = Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.md,
        AppSpacing.md,
        0,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text(
            l.exploreIntro,
            style: AppTypography.bodySmall.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: SegmentedButton<PathAspect>(
              showSelectedIcon: false,
              segments: <ButtonSegment<PathAspect>>[
                for (final PathAspect a in PathAspect.values)
                  ButtonSegment<PathAspect>(
                    value: a,
                    icon: Icon(aspectIcon(a)),
                    label: Text(aspectLabel(a, l)),
                  ),
              ],
              selected: <PathAspect>{_aspect},
              onSelectionChanged: (Set<PathAspect> s) => setState(() {
                _aspect = s.first;
                _selected = null;
                _media = null;
              }),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          if (keys.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
              child: Text(
                l.exploreEmpty,
                textAlign: TextAlign.center,
                style: AppTypography.body.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
            )
          else
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.xs,
              children: <Widget>[
                for (final ThemeKey k in keys)
                  ChoiceChip(
                    key: ValueKey<ThemeKey>(k),
                    label: Text(
                      '${themeKeyLabel(k, l)} · ${index.itemsFor(k).length}',
                    ),
                    avatar: k.builtIn == null
                        ? const Icon(Icons.sell_outlined, size: 16)
                        : null,
                    selected: k == selected,
                    onSelected: (bool on) => setState(() {
                      _selected = on ? k : null;
                      _media = null;
                    }),
                  ),
              ],
            ),
          if (selected != null) ...<Widget>[
            const SizedBox(height: AppSpacing.md),
            Row(
              children: <Widget>[
                Expanded(
                  child: Text(
                    l.exploreToDiscover(toDiscover),
                    style: AppTypography.h3,
                  ),
                ),
                TextButton.icon(
                  onPressed: () => _makePath(themeKeyLabel(selected, l), all),
                  icon: const Icon(Icons.route_outlined, size: 18),
                  label: Text(l.exploreMakePath),
                  style: TextButton.styleFrom(
                    minimumSize: const Size(0, AppSpacing.buttonHeightCompact),
                  ),
                ),
              ],
            ),
            if (media.length > 1)
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: <Widget>[
                    ChoiceChip(
                      label: Text(l.all),
                      selected: mediaFilter == null,
                      onSelected: (_) => setState(() => _media = null),
                    ),
                    for (final MediaType m in media)
                      Padding(
                        key: ValueKey<MediaType>(m),
                        padding: const EdgeInsets.only(left: AppSpacing.sm),
                        child: ChoiceChip(
                          avatar: Icon(MediaTypeTheme.iconFor(m), size: 16),
                          label: Text(
                            '${all.where((CollectionItem i) => i.mediaType == m).length}',
                          ),
                          selected: mediaFilter == m,
                          onSelected: (bool on) =>
                              setState(() => _media = on ? m : null),
                        ),
                      ),
                  ],
                ),
              ),
          ],
        ],
      ),
    );

    return ItemCoverGrid(items: shown, header: header);
  }
}
