import 'package:core/models/collection_item.dart';
import 'package:flutter/material.dart';

import '../../../shared/constants/media_type_theme.dart';
import '../../../shared/theme/app_spacing.dart';
import '../../../shared/theme/app_typography.dart';
import '../../../shared/widgets/media_detail/media_cover_image.dart';
import '../../collections/screens/item_detail_screen.dart';

/// A small cover with title and an optional caption; taps open the item.
class ItemCoverRow extends StatelessWidget {
  const ItemCoverRow({
    required this.item,
    this.caption,
    this.trailing,
    super.key,
  });

  final CollectionItem item;
  final String? caption;
  final Widget? trailing;

  static const double _coverWidth = 40;
  static const double _coverHeight = 60;

  void _open(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (BuildContext _) => ItemDetailScreen(
          collectionId: item.collectionId,
          itemId: item.id,
          isEditable: true,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final String? caption = this.caption;
    final Widget? trailing = this.trailing;
    return InkWell(
      borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
      onTap: () => _open(context),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
        child: Row(
          children: <Widget>[
            ClipRRect(
              borderRadius: BorderRadius.circular(AppSpacing.radiusXs),
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
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    item.itemName,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.body,
                  ),
                  if (caption != null)
                    Text(caption, style: AppTypography.caption),
                ],
              ),
            ),
            ?trailing,
          ],
        ),
      ),
    );
  }
}
