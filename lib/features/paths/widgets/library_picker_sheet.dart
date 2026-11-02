import 'package:core/models/collection_item.dart';
import 'package:core/plus/analytics/path_walk.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/app_localizations.dart';
import '../../../shared/constants/media_type_theme.dart';
import '../../../shared/theme/app_colors.dart';
import '../../../shared/theme/app_spacing.dart';
import '../../../shared/theme/app_typography.dart';
import '../../../shared/widgets/media_detail/media_cover_image.dart';
import '../../insights/providers/insights_providers.dart';
import '../providers/paths_providers.dart';

/// Picks works from the library; games of the same series as [pathId]'s and
/// titles matching [pathName] are offered first.
Future<List<CollectionItem>?> showLibraryPicker(
  BuildContext context, {
  required String pathName,
  int? pathId,
  Set<int> exclude = const <int>{},
}) {
  return showModalBottomSheet<List<CollectionItem>>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: AppColors.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(
        top: Radius.circular(AppSpacing.radiusLg),
      ),
    ),
    builder: (BuildContext sheetContext) => FractionallySizedBox(
      heightFactor: _LibraryPicker.heightFactor,
      child: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.viewInsetsOf(sheetContext).bottom,
        ),
        child: _LibraryPicker(
          pathName: pathName,
          pathId: pathId,
          exclude: exclude,
        ),
      ),
    ),
  );
}

class _LibraryPicker extends ConsumerStatefulWidget {
  const _LibraryPicker({
    required this.pathName,
    required this.pathId,
    required this.exclude,
  });

  static const double heightFactor = 0.92;

  final String pathName;
  final int? pathId;
  final Set<int> exclude;

  @override
  ConsumerState<_LibraryPicker> createState() => _LibraryPickerState();
}

class _LibraryPickerState extends ConsumerState<_LibraryPicker> {
  final TextEditingController _query = TextEditingController();
  final Set<int> _selected = <int>{};
  String _text = '';

  static const int _maxResults = 200;

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  void _toggle(int id) => setState(() {
    if (!_selected.remove(id)) _selected.add(id);
  });

  @override
  Widget build(BuildContext context) {
    final S l = S.of(context);
    final List<CollectionItem> library =
        ref.watch(libraryItemsProvider).valueOrNull ?? const <CollectionItem>[];
    final List<CollectionItem> available = <CollectionItem>[
      for (final CollectionItem i in library)
        if (!widget.exclude.contains(i.id)) i,
    ];
    final String query = _text.trim().toLowerCase();
    final int? pathId = widget.pathId;
    final List<CollectionItem> sameSeries = pathId == null
        ? const <CollectionItem>[]
        : ref.watch(seriesSuggestionsProvider(pathId)).valueOrNull ??
              const <CollectionItem>[];
    final Set<int> availableIds = <int>{
      for (final CollectionItem i in available) i.id,
    };
    final List<CollectionItem> suggested = query.isEmpty
        ? <CollectionItem>[
            for (final CollectionItem i in sameSeries)
              if (availableIds.contains(i.id)) i,
            for (final CollectionItem i in PathSuggestions.byTitle(
              widget.pathName,
              available,
            ))
              if (!sameSeries.any((CollectionItem s) => s.id == i.id)) i,
          ]
        : const <CollectionItem>[];
    final Set<int> suggestedIds = <int>{
      for (final CollectionItem i in suggested) i.id,
    };
    final List<CollectionItem> results = <CollectionItem>[
      for (final CollectionItem i in available)
        if (!suggestedIds.contains(i.id) &&
            (query.isEmpty || i.itemName.toLowerCase().contains(query)))
          i,
    ].take(_maxResults).toList();
    final List<CollectionItem> chosen = <CollectionItem>[
      for (final CollectionItem i in available)
        if (_selected.contains(i.id)) i,
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.md,
            AppSpacing.md,
            AppSpacing.md,
            AppSpacing.sm,
          ),
          child: Text(
            l.pathPickerTitle,
            style: AppTypography.h3.copyWith(fontWeight: FontWeight.w600),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
          child: TextField(
            controller: _query,
            onChanged: (String v) => setState(() => _text = v),
            decoration: InputDecoration(
              hintText: l.pathPickerSearch,
              prefixIcon: const Icon(Icons.search),
            ),
          ),
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
            children: <Widget>[
              if (suggested.isNotEmpty) ...<Widget>[
                _Header(
                  title: l.pathPickerSuggested,
                  action: TextButton(
                    onPressed: () =>
                        setState(() => _selected.addAll(suggestedIds)),
                    style: TextButton.styleFrom(
                      minimumSize: const Size(0, AppSpacing.buttonHeightDense),
                    ),
                    child: Text(l.pathPickerSelectAll(suggested.length)),
                  ),
                ),
                for (final CollectionItem item in suggested)
                  _PickTile(
                    key: ValueKey<String>('s-${item.id}'),
                    item: item,
                    selected: _selected.contains(item.id),
                    onTap: () => _toggle(item.id),
                  ),
                const Divider(),
              ],
              for (final CollectionItem item in results)
                _PickTile(
                  key: ValueKey<String>('r-${item.id}'),
                  item: item,
                  selected: _selected.contains(item.id),
                  onTap: () => _toggle(item.id),
                ),
              if (suggested.isEmpty && results.isEmpty)
                Padding(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  child: Text(
                    l.pathPickerNoResults,
                    textAlign: TextAlign.center,
                    style: AppTypography.body.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
              Padding(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Text(
                  l.pathPickerMissing,
                  textAlign: TextAlign.center,
                  style: AppTypography.caption.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
            ],
          ),
        ),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: FilledButton.icon(
              onPressed: chosen.isEmpty
                  ? null
                  : () => Navigator.of(context).pop(chosen),
              icon: const Icon(Icons.playlist_add),
              label: Text(l.pathPickerAdd(chosen.length)),
            ),
          ),
        ),
      ],
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.title, required this.action});

  final String title;
  final Widget action;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Text(
              title,
              style: AppTypography.bodySmall.copyWith(
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          action,
        ],
      ),
    );
  }
}

class _PickTile extends StatelessWidget {
  const _PickTile({
    required this.item,
    required this.selected,
    required this.onTap,
    super.key,
  });

  final CollectionItem item;
  final bool selected;
  final VoidCallback onTap;

  static const double _coverWidth = 36;
  static const double _coverHeight = 54;

  @override
  Widget build(BuildContext context) {
    final int? year = item.releaseYear;
    return CheckboxListTile(
      value: selected,
      onChanged: (_) => onTap(),
      secondary: ClipRRect(
        borderRadius: BorderRadius.circular(AppSpacing.radiusXs),
        child: SizedBox(
          width: _coverWidth,
          height: _coverHeight,
          child: MediaCoverImage(
            coverUrl: item.thumbnailUrl ?? item.coverUrl,
            placeholderIcon: MediaTypeTheme.placeholderIconFor(item.mediaType),
          ),
        ),
      ),
      title: Text(item.itemName, maxLines: 2, overflow: TextOverflow.ellipsis),
      subtitle: Row(
        children: <Widget>[
          Icon(
            MediaTypeTheme.iconFor(item.mediaType),
            size: 14,
            color: AppColors.textSecondary,
          ),
          if (year != null) ...<Widget>[
            const SizedBox(width: AppSpacing.xs),
            Text('$year', style: AppTypography.caption),
          ],
        ],
      ),
    );
  }
}
