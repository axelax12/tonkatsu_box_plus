import 'package:core/models/collection_item.dart';
import 'package:flutter/material.dart';

import '../../../shared/constants/media_type_theme.dart';
import '../../../shared/theme/app_colors.dart';
import '../../../shared/theme/app_spacing.dart';
import '../../../shared/theme/app_typography.dart';
import '../../../shared/widgets/media_detail/media_cover_image.dart';
import '../../paths/widgets/path_stop_tile.dart';

class TodaySectionHeader extends StatelessWidget {
  const TodaySectionHeader({
    required this.title,
    this.actionLabel,
    this.onAction,
    super.key,
  });

  final String title;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final String? label = actionLabel;
    final VoidCallback? action = onAction;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.lg,
        AppSpacing.sm,
        AppSpacing.sm,
      ),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Text(
              title,
              style: AppTypography.h3.copyWith(fontWeight: FontWeight.w700),
            ),
          ),
          if (label != null && action != null)
            TextButton(
              onPressed: action,
              style: TextButton.styleFrom(
                minimumSize: const Size(0, AppSpacing.buttonHeightDense),
              ),
              child: Text(label),
            ),
        ],
      ),
    );
  }
}

class CoverStripEntry {
  const CoverStripEntry({required this.item, this.caption});

  final CollectionItem item;

  /// Replaces the title line: a release date, the path a stop belongs to.
  final String? caption;
}

/// A row of tall covers, the work's art doing the talking.
class CoverStrip extends StatelessWidget {
  const CoverStrip({required this.entries, super.key});

  final List<CoverStripEntry> entries;

  static const double coverWidth = 112;
  static const double _textBlock = 52;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: coverWidth / AppSpacing.posterAspectRatio + _textBlock,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
        itemCount: entries.length,
        separatorBuilder: (BuildContext _, int _) =>
            const SizedBox(width: AppSpacing.sm),
        itemBuilder: (BuildContext context, int index) {
          final CoverStripEntry entry = entries[index];
          return _CoverTile(
            key: ValueKey<int>(entry.item.id),
            entry: entry,
          );
        },
      ),
    );
  }
}

class _CoverTile extends StatelessWidget {
  const _CoverTile({required this.entry, super.key});

  final CoverStripEntry entry;

  @override
  Widget build(BuildContext context) {
    final CollectionItem item = entry.item;
    final String? caption = entry.caption;
    return SizedBox(
      width: CoverStrip.coverWidth,
      child: InkWell(
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        onTap: () => openPathItem(context, item),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            AspectRatio(
              aspectRatio: AppSpacing.posterAspectRatio,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
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
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTypography.caption.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            if (caption != null)
              Text(
                caption,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTypography.caption.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
