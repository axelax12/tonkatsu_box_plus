import 'package:core/models/collection_item.dart';
import 'package:core/plus/analytics/path_walk.dart';
import 'package:core/plus/models/media_path.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/app_localizations.dart';
import '../../../shared/constants/media_type_theme.dart';
import '../../../shared/theme/app_colors.dart';
import '../../../shared/theme/app_spacing.dart';
import '../../../shared/theme/app_typography.dart';
import '../../../shared/widgets/media_detail/media_cover_image.dart';
import '../paths_format.dart';
import '../providers/paths_providers.dart';
import '../widgets/library_picker_sheet.dart';
import '../widgets/path_sheets.dart';
import 'explore_screen.dart';
import 'path_screen.dart';

class PathsScreen extends StatelessWidget {
  const PathsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final S l = S.of(context);
    return DefaultTabController(
      length: 2,
      child: Column(
        children: <Widget>[
          TabBar(
            tabs: <Widget>[
              Tab(text: l.pathsTabPaths),
              Tab(text: l.pathsTabExplore),
            ],
          ),
          const Expanded(
            child: TabBarView(children: <Widget>[_PathsTab(), ExploreScreen()]),
          ),
        ],
      ),
    );
  }
}

/// Creates a path, offers matching works straight away, then opens it.
Future<void> createPathFlow(
  BuildContext context,
  WidgetRef ref, {
  PathKind kind = PathKind.universe,
}) async {
  final PathDraft? draft = await showPathEditorSheet(
    context,
    initialKind: kind,
  );
  if (draft == null || !context.mounted) return;
  final List<CollectionItem>? picked = await showLibraryPicker(
    context,
    pathName: draft.name,
  );
  final MediaPath path = await ref
      .read(pathsControllerProvider)
      .create(
        name: draft.name,
        kind: draft.kind,
        description: draft.description,
        items: picked ?? const <CollectionItem>[],
      );
  if (!context.mounted) return;
  await Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (BuildContext _) => PathScreen(pathId: path.id),
    ),
  );
}

class _PathsTab extends ConsumerWidget {
  const _PathsTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final S l = S.of(context);
    final List<MediaPath> paths =
        ref.watch(pathsProvider).valueOrNull ?? const <MediaPath>[];
    final List<MediaPath> universes = <MediaPath>[
      for (final MediaPath p in paths)
        if (p.kind == PathKind.universe) p,
    ];
    final List<MediaPath> themes = <MediaPath>[
      for (final MediaPath p in paths)
        if (p.kind == PathKind.theme) p,
    ];

    return ListView(
      padding: const EdgeInsets.all(AppSpacing.md),
      children: <Widget>[
        FilledButton.icon(
          onPressed: () => createPathFlow(context, ref),
          icon: const Icon(Icons.add),
          label: Text(l.pathNew),
        ),
        if (paths.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
            child: Text(
              l.pathsNoneYet,
              textAlign: TextAlign.center,
              style: AppTypography.body.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ),
        for (final (String title, List<MediaPath> group)
            in <(String, List<MediaPath>)>[
              (l.pathsUniverses, universes),
              (l.pathsThemes, themes),
            ])
          if (group.isNotEmpty) ...<Widget>[
            const SizedBox(height: AppSpacing.lg),
            Text(title, style: AppTypography.h3),
            const SizedBox(height: AppSpacing.sm),
            for (final MediaPath p in group)
              Padding(
                key: ValueKey<int>(p.id),
                padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                child: PathCard(path: p),
              ),
          ],
      ],
    );
  }
}

class PathCard extends ConsumerWidget {
  const PathCard({required this.path, super.key});

  final MediaPath path;

  static const int _previewCovers = 4;
  static const double _coverWidth = 40;
  static const double _coverHeight = 60;
  static const double _overlap = 14;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final S l = S.of(context);
    final PathWalk? walk = ref
        .watch(pathWalkProvider((pathId: path.id, order: path.defaultOrder)))
        .valueOrNull;
    final List<CollectionItem> covers = <CollectionItem>[
      for (final PathStop s in walk?.stops ?? const <PathStop>[])
        if (!s.hidden) ?s.item,
    ].take(_previewCovers).toList();
    final PathStop? current = walk?.current;
    final String? currentName = current == null || current.hidden
        ? null
        : current.item?.itemName;

    return Material(
      color: AppColors.surfaceLight,
      borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (BuildContext _) => PathScreen(pathId: path.id),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Row(
            children: <Widget>[
              SizedBox(
                width: _coverWidth + (_previewCovers - 1) * _overlap,
                height: _coverHeight,
                child: Stack(
                  children: <Widget>[
                    if (covers.isEmpty)
                      Icon(
                        pathKindIcon(path.kind),
                        size: _coverWidth,
                        color: AppColors.textTertiary,
                      ),
                    for (int i = covers.length - 1; i >= 0; i--)
                      Positioned(
                        key: ValueKey<int>(covers[i].id),
                        left: i * _overlap,
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(
                            AppSpacing.radiusXs,
                          ),
                          child: SizedBox(
                            width: _coverWidth,
                            height: _coverHeight,
                            child: MediaCoverImage(
                              coverUrl:
                                  covers[i].thumbnailUrl ?? covers[i].coverUrl,
                              placeholderIcon:
                                  MediaTypeTheme.placeholderIconFor(
                                    covers[i].mediaType,
                                  ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      path.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.body.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    if (walk != null && walk.stops.isNotEmpty) ...<Widget>[
                      ClipRRect(
                        borderRadius: BorderRadius.circular(
                          AppSpacing.radiusXs,
                        ),
                        child: LinearProgressIndicator(
                          value: walk.fraction,
                          minHeight: AppSpacing.xs,
                          backgroundColor: AppColors.surface,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        walk.isComplete
                            ? l.pathCompleted
                            : currentName != null
                            ? l.pathsSectionNext(currentName)
                            : l.pathProgress(
                                walk.requiredDone,
                                walk.requiredTotal,
                              ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.caption.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ] else
                      Text(
                        pathKindLabel(path.kind, l),
                        style: AppTypography.caption.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
