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
import '../../../shared/widgets/confirm_dialog.dart';
import '../../../shared/widgets/media_detail/media_cover_image.dart';
import '../paths_format.dart';
import '../providers/paths_providers.dart';
import '../widgets/library_picker_sheet.dart';
import '../widgets/path_sheets.dart';
import '../widgets/path_stop_tile.dart';

enum _PathMenu { details, sortRelease, delete }

/// "Where do I start?": one path walked in a chosen order, with the stop to
/// pick up next and spoiler stops masked until reached.
class PathScreen extends ConsumerStatefulWidget {
  const PathScreen({required this.pathId, super.key});

  final int pathId;

  @override
  ConsumerState<PathScreen> createState() => _PathScreenState();
}

class _PathScreenState extends ConsumerState<PathScreen> {
  bool _editing = false;

  // Reveals last only while the screen is open, on purpose.
  final Set<int> _revealed = <int>{};

  PathsController get _controller => ref.read(pathsControllerProvider);

  Future<void> _addWorks(MediaPath path, PathWalk walk) async {
    final List<CollectionItem>? picked = await showLibraryPicker(
      context,
      pathName: path.name,
      pathId: path.id,
      exclude: <int>{for (final PathStop s in walk.stops) s.entry.itemId},
    );
    if (picked == null || picked.isEmpty) return;
    await _controller.addItems(path.id, picked);
  }

  Future<void> _selectOrder(MediaPath path, PathOrder order) async {
    ref.read(pathOrderProvider(path.id).notifier).select(order);
    if (order != path.defaultOrder) {
      await _controller.save(
        path.copyWith(defaultOrder: order, updatedAt: DateTime.now()),
      );
    }
  }

  Future<void> _onMenu(MediaPath path, _PathMenu action) async {
    final S l = S.of(context);
    switch (action) {
      case _PathMenu.details:
        final PathDraft? draft = await showPathEditorSheet(
          context,
          existing: path,
        );
        if (draft == null) return;
        await _controller.save(
          path.copyWith(
            name: draft.name,
            kind: draft.kind,
            description: draft.description,
            clearDescription: draft.description == null,
            updatedAt: DateTime.now(),
          ),
        );
      case _PathMenu.sortRelease:
        await _controller.sortByRelease(path.id);
        await _selectOrder(path, PathOrder.release);
      case _PathMenu.delete:
        final bool confirmed = await ConfirmDialog.show(
          context,
          title: l.delete,
          message: l.pathDeleteConfirm(path.name),
          confirmLabel: l.delete,
        );
        if (!confirmed || !mounted) return;
        await _controller.delete(path.id);
        if (mounted) Navigator.of(context).pop();
    }
  }

  Future<void> _onStopTap(PathStop stop, bool masked) async {
    final S l = S.of(context);
    final CollectionItem? item = stop.item;
    if (_editing) {
      final StopEditResult? result = await showStopEditorSheet(
        context,
        entry: stop.entry,
        title: item?.itemName ?? l.pathNote,
      );
      switch (result) {
        case StopSaved(:final PathEntry entry):
          await _controller.updateEntry(entry);
        case StopRemoved():
          await _controller.removeEntry(stop.entry);
        case null:
          return;
      }
      return;
    }
    if (masked) {
      final bool reveal = await ConfirmDialog.show(
        context,
        title: l.pathReveal,
        message: l.pathRevealConfirm,
        confirmLabel: l.pathReveal,
        destructive: false,
      );
      if (reveal && mounted) setState(() => _revealed.add(stop.entry.id));
      return;
    }
    if (item != null) openPathItem(context, item);
  }

  Future<void> _reorder(PathWalk walk, int from, int to) async {
    final List<int> ids = <int>[
      for (final PathStop s in walk.stops) s.entry.id,
    ];
    final int moved = ids.removeAt(from);
    ids.insert(to, moved);
    await _controller.reorder(widget.pathId, walk.order, ids);
  }

  @override
  Widget build(BuildContext context) {
    final S l = S.of(context);
    final MediaPath? path = ref
        .watch(pathsProvider)
        .valueOrNull
        ?.where((MediaPath p) => p.id == widget.pathId)
        .firstOrNull;
    if (path == null) {
      return Scaffold(
        appBar: AppBar(),
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    final PathOrder order =
        ref.watch(pathOrderProvider(path.id)) ?? path.defaultOrder;
    final PathWalk? walk = ref
        .watch(pathWalkProvider((pathId: path.id, order: order)))
        .valueOrNull;

    return Scaffold(
      appBar: AppBar(
        title: Text(path.name),
        actions: <Widget>[
          IconButton(
            tooltip: _editing ? l.done : l.pathEditStops,
            icon: Icon(_editing ? Icons.check : Icons.edit_note),
            onPressed: () => setState(() => _editing = !_editing),
          ),
          PopupMenuButton<_PathMenu>(
            onSelected: (_PathMenu a) => _onMenu(path, a),
            itemBuilder: (BuildContext _) => <PopupMenuEntry<_PathMenu>>[
              PopupMenuItem<_PathMenu>(
                value: _PathMenu.details,
                child: Text(l.edit),
              ),
              PopupMenuItem<_PathMenu>(
                value: _PathMenu.sortRelease,
                child: Text(l.pathSortByRelease),
              ),
              PopupMenuItem<_PathMenu>(
                value: _PathMenu.delete,
                child: Text(l.delete),
              ),
            ],
          ),
        ],
      ),
      floatingActionButton: walk == null
          ? null
          : FloatingActionButton.extended(
              onPressed: () => _addWorks(path, walk),
              icon: const Icon(Icons.playlist_add),
              label: Text(l.pathAddWorks),
            ),
      body: walk == null
          ? const Center(child: CircularProgressIndicator())
          : _buildBody(path, walk, l),
    );
  }

  Widget _buildBody(MediaPath path, PathWalk walk, S l) {
    final Widget header = _PathHeader(
      path: path,
      walk: walk,
      onOrder: (PathOrder o) => _selectOrder(path, o),
      onOpenCurrent: (PathStop s) => _onStopTap(s, false),
    );
    if (walk.stops.isEmpty) {
      return ListView(
        children: <Widget>[
          header,
          Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Text(
              l.pathEmpty,
              textAlign: TextAlign.center,
              style: AppTypography.body.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ),
        ],
      );
    }
    bool masked(PathStop s) =>
        !_editing && s.hidden && !_revealed.contains(s.entry.id);

    if (_editing) {
      return ReorderableListView.builder(
        header: header,
        buildDefaultDragHandles: false,
        padding: const EdgeInsets.only(bottom: _fabClearance),
        itemCount: walk.stops.length,
        onReorderItem: (int from, int to) => _reorder(walk, from, to),
        itemBuilder: (BuildContext context, int index) {
          final PathStop stop = walk.stops[index];
          return PathStopTile(
            key: ValueKey<int>(stop.entry.id),
            stop: stop,
            number: index + 1,
            masked: false,
            onTap: () => _onStopTap(stop, false),
            trailing: ReorderableDragStartListener(
              index: index,
              child: const Padding(
                padding: EdgeInsets.all(AppSpacing.sm),
                child: Icon(Icons.drag_handle),
              ),
            ),
          );
        },
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.only(bottom: _fabClearance),
      itemCount: walk.stops.length + 1,
      itemBuilder: (BuildContext context, int index) {
        if (index == 0) return header;
        final PathStop stop = walk.stops[index - 1];
        final bool isMasked = masked(stop);
        return PathStopTile(
          key: ValueKey<int>(stop.entry.id),
          stop: stop,
          number: index,
          masked: isMasked,
          onTap: () => _onStopTap(stop, isMasked),
        );
      },
    );
  }

  static const double _fabClearance = 88;
}

class _PathHeader extends StatelessWidget {
  const _PathHeader({
    required this.path,
    required this.walk,
    required this.onOrder,
    required this.onOpenCurrent,
  });

  final MediaPath path;
  final PathWalk walk;
  final ValueChanged<PathOrder> onOrder;
  final ValueChanged<PathStop> onOpenCurrent;

  @override
  Widget build(BuildContext context) {
    final S l = S.of(context);
    final String? description = path.description;
    final PathStop? current = walk.current;
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Row(
            children: <Widget>[
              Icon(
                pathKindIcon(path.kind),
                size: 18,
                color: AppColors.textSecondary,
              ),
              const SizedBox(width: AppSpacing.xs),
              Text(
                pathKindLabel(path.kind, l),
                style: AppTypography.caption.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
          if (description != null) ...<Widget>[
            const SizedBox(height: AppSpacing.sm),
            Text(description, style: AppTypography.body),
          ],
          if (walk.stops.isNotEmpty) ...<Widget>[
            const SizedBox(height: AppSpacing.md),
            ClipRRect(
              borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
              child: LinearProgressIndicator(
                value: walk.fraction,
                minHeight: AppSpacing.sm,
                backgroundColor: AppColors.surfaceLight,
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              walk.isComplete
                  ? l.pathCompleted
                  : l.pathProgress(walk.requiredDone, walk.requiredTotal),
              style: AppTypography.bodySmall,
            ),
            if (walk.optionalTotal > 0)
              Text(
                l.pathOptionalProgress(walk.optionalDone, walk.optionalTotal),
                style: AppTypography.caption.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
          ],
          const SizedBox(height: AppSpacing.md),
          SegmentedButton<PathOrder>(
            showSelectedIcon: false,
            segments: <ButtonSegment<PathOrder>>[
              for (final PathOrder o in PathOrder.values)
                ButtonSegment<PathOrder>(
                  value: o,
                  label: Text(pathOrderLabel(o, l)),
                ),
            ],
            selected: <PathOrder>{walk.order},
            onSelectionChanged: (Set<PathOrder> s) => onOrder(s.first),
          ),
          if (current != null && current.item != null) ...<Widget>[
            const SizedBox(height: AppSpacing.md),
            _CurrentCard(
              stop: current,
              isStart:
                  walk.requiredDone == 0 && current.state == StopState.next,
              onTap: () => onOpenCurrent(current),
            ),
          ],
        ],
      ),
    );
  }
}

/// The stop to pick up, given cover-first weight so the answer is obvious.
class _CurrentCard extends StatelessWidget {
  const _CurrentCard({
    required this.stop,
    required this.isStart,
    required this.onTap,
  });

  final PathStop stop;
  final bool isStart;
  final VoidCallback onTap;

  static const double _coverWidth = 72;
  static const double _coverHeight = 108;

  @override
  Widget build(BuildContext context) {
    final S l = S.of(context);
    final CollectionItem? item = stop.item;
    if (item == null) return const SizedBox.shrink();
    final String? note = stop.entry.note;
    return Material(
      color: AppColors.surfaceLight,
      borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Row(
            children: <Widget>[
              ClipRRect(
                borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                child: SizedBox(
                  width: _coverWidth,
                  height: _coverHeight,
                  child: MediaCoverImage(
                    coverUrl: item.thumbnailUrl ?? item.coverUrl,
                    placeholderIcon: MediaTypeTheme.placeholderIconFor(
                      item.mediaType,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      isStart ? l.pathStartHere : l.pathContinue,
                      style: AppTypography.caption.copyWith(
                        color: AppColors.brand,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      item.itemName,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.h3.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (note != null) ...<Widget>[
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        note,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.caption.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const Icon(Icons.chevron_right),
            ],
          ),
        ),
      ),
    );
  }
}
