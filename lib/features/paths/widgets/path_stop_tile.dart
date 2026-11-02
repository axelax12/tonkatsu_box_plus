import 'package:core/models/collection_item.dart';
import 'package:core/plus/analytics/path_walk.dart';
import 'package:core/plus/models/media_path.dart';
import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';
import '../../../shared/constants/media_type_theme.dart';
import '../../../shared/theme/app_colors.dart';
import '../../../shared/theme/app_spacing.dart';
import '../../../shared/theme/app_typography.dart';
import '../../../shared/widgets/media_detail/media_cover_image.dart';
import '../../collections/screens/item_detail_screen.dart';
import '../paths_format.dart';

void openPathItem(BuildContext context, CollectionItem item) {
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

/// One numbered stop; a masked spoiler shows neither cover, title nor note.
class PathStopTile extends StatelessWidget {
  const PathStopTile({
    required this.stop,
    required this.number,
    required this.masked,
    required this.onTap,
    this.trailing,
    super.key,
  });

  final PathStop stop;
  final int number;
  final bool masked;
  final VoidCallback onTap;
  final Widget? trailing;

  static const double _coverWidth = 44;
  static const double _coverHeight = 66;
  static const double _badgeSize = 28;
  static const String _maskedTitle = '???';

  Color _stateColor() => switch (stop.state) {
    StopState.done => AppColors.statusCompleted,
    StopState.inProgress => AppColors.statusInProgress,
    StopState.next => AppColors.brand,
    StopState.upcoming => AppColors.surfaceBorder,
  };

  String? _stateLabel(S l) => switch (stop.state) {
    StopState.done => l.pathStateDone,
    StopState.inProgress => l.pathStateActive,
    StopState.next => l.pathStateNext,
    StopState.upcoming => null,
  };

  @override
  Widget build(BuildContext context) {
    final S l = S.of(context);
    final CollectionItem? item = stop.item;
    final PathEntry entry = stop.entry;
    final Color color = _stateColor();
    final String? stateLabel = _stateLabel(l);
    final String? note = masked ? null : entry.note;
    final PathAspect? aspect = entry.aspect;
    final int? year = item?.releaseYear;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
        child: Row(
          children: <Widget>[
            Container(
              width: _badgeSize,
              height: _badgeSize,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: stop.isDone ? color : Colors.transparent,
                border: Border.all(color: color, width: 2),
              ),
              child: stop.isDone
                  ? Icon(Icons.check, size: 16, color: AppColors.onBrand)
                  : Text('$number', style: AppTypography.caption),
            ),
            const SizedBox(width: AppSpacing.sm),
            ClipRRect(
              borderRadius: BorderRadius.circular(AppSpacing.radiusXs),
              child: SizedBox(
                width: _coverWidth,
                height: _coverHeight,
                child: masked || item == null
                    ? ColoredBox(
                        color: AppColors.surfaceLight,
                        child: Icon(
                          masked ? Icons.visibility_off_outlined : Icons.help,
                          color: AppColors.textTertiary,
                        ),
                      )
                    : MediaCoverImage(
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
                    masked ? _maskedTitle : item?.itemName ?? '',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.body.copyWith(
                      fontWeight: FontWeight.w600,
                      color: entry.optional
                          ? AppColors.textSecondary
                          : AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Wrap(
                    spacing: AppSpacing.sm,
                    runSpacing: AppSpacing.xs,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: <Widget>[
                      if (masked)
                        Text(
                          l.pathSpoilerHidden,
                          style: AppTypography.caption.copyWith(
                            color: AppColors.textTertiary,
                          ),
                        )
                      else if (item != null) ...<Widget>[
                        Icon(
                          MediaTypeTheme.iconFor(item.mediaType),
                          size: 14,
                          color: MediaTypeTheme.colorFor(item.mediaType),
                        ),
                        if (year != null)
                          Text('$year', style: AppTypography.caption),
                      ],
                      if (stateLabel != null)
                        Text(
                          stateLabel,
                          style: AppTypography.caption.copyWith(
                            color: color,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      if (entry.optional) _Pill(label: l.pathOptional),
                      if (aspect != null && !masked)
                        _Pill(label: aspectLabel(aspect, l)),
                    ],
                  ),
                  if (note != null) ...<Widget>[
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      note,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.caption.copyWith(
                        color: AppColors.textSecondary,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ],
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

class _Pill extends StatelessWidget {
  const _Pill({required this.label});

  final String label;

  static const double _vertical = 2;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: _vertical,
      ),
      decoration: BoxDecoration(
        color: AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
      ),
      child: Text(label, style: AppTypography.caption),
    );
  }
}
