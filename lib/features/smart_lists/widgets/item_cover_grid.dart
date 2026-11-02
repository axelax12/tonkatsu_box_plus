import 'package:core/models/collection_item.dart';
import 'package:flutter/material.dart';

import '../../../shared/constants/media_type_theme.dart';
import '../../../shared/theme/app_spacing.dart';
import '../../../shared/theme/app_typography.dart';
import '../../../shared/widgets/media_detail/media_cover_image.dart';
import '../../collections/screens/item_detail_screen.dart';

/// Covers in a lazy grid, three across on a phone; a tap opens the item.
class ItemCoverGrid extends StatelessWidget {
  const ItemCoverGrid({required this.items, this.header, super.key});

  final List<CollectionItem> items;
  final Widget? header;

  static const double _maxTileWidth = 140;
  static const double _coverAspect = 2 / 3;
  static const double _titleHeight = 36;

  @override
  Widget build(BuildContext context) {
    final Widget? header = this.header;
    return CustomScrollView(
      slivers: <Widget>[
        if (header != null) SliverToBoxAdapter(child: header),
        SliverPadding(
          padding: const EdgeInsets.all(AppSpacing.md),
          sliver: SliverGrid(
            gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
              maxCrossAxisExtent: _maxTileWidth,
              mainAxisSpacing: AppSpacing.md,
              crossAxisSpacing: AppSpacing.sm,
              mainAxisExtent: _maxTileWidth / _coverAspect + _titleHeight,
            ),
            delegate: SliverChildBuilderDelegate(
              (BuildContext context, int index) => _CoverTile(
                key: ValueKey<int>(items[index].id),
                item: items[index],
              ),
              childCount: items.length,
            ),
          ),
        ),
      ],
    );
  }
}

class _CoverTile extends StatelessWidget {
  const _CoverTile({required this.item, super.key});

  final CollectionItem item;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (BuildContext _) => ItemDetailScreen(
            collectionId: item.collectionId,
            itemId: item.id,
            isEditable: true,
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
              child: MediaCoverImage(
                coverUrl: item.thumbnailUrl ?? item.coverUrl,
                placeholderIcon: MediaTypeTheme.placeholderIconFor(
                  item.mediaType,
                ),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            item.itemName,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: AppTypography.caption,
          ),
        ],
      ),
    );
  }
}
