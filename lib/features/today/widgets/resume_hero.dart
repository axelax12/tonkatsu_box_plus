import 'dart:ui' show ImageFilter;

import 'package:core/models/collection_item.dart';
import 'package:core/plus/models/play_session.dart';
import 'package:core/plus/models/resume_bookmark.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/app_localizations.dart';
import '../../../shared/constants/media_type_theme.dart';
import '../../../shared/theme/app_colors.dart';
import '../../../shared/theme/app_spacing.dart';
import '../../../shared/theme/app_typography.dart';
import '../../../shared/widgets/media_detail/media_cover_image.dart';
import '../../journal/journal_actions.dart';
import '../../journal/providers/journal_providers.dart';
import '../../paths/widgets/path_stop_tile.dart';

/// The work in progress, big: its cover blurred behind, where the user left
/// off without spoilers, and one tap to start or stop a session.
class ResumeHero extends ConsumerWidget {
  const ResumeHero({required this.item, super.key});

  final CollectionItem item;

  static const double _coverWidth = 120;
  static const double _blurSigma = 28;
  static const double _scrimAlpha = 0.5;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final S l = S.of(context);
    final String? cover = item.thumbnailUrl ?? item.coverUrl;
    final PlaySession? running = ref
        .watch(runningSessionProvider(item.id))
        .valueOrNull;
    final ResumeBookmark? bookmark = ref
        .watch(itemBookmarkProvider(item.id))
        .valueOrNull;
    final String? position = bookmark?.position;
    final JournalActions actions = JournalActions(
      ref,
      item.id,
      itemName: item.itemName,
    );
    final Color accent = MediaTypeTheme.colorFor(item.mediaType);

    final Widget content = Material(
      type: MaterialType.transparency,
      child: InkWell(
        onTap: () => openPathItem(context, item),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Row(
            children: <Widget>[
              SizedBox(
                width: _coverWidth,
                child: AspectRatio(
                  aspectRatio: AppSpacing.posterAspectRatio,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                    child: MediaCoverImage(
                      coverUrl: cover,
                      placeholderIcon: MediaTypeTheme.placeholderIconFor(
                        item.mediaType,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Icon(
                      MediaTypeTheme.iconFor(item.mediaType),
                      size: 18,
                      color: accent,
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      item.itemName,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.h2,
                    ),
                    if (position != null) ...<Widget>[
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        l.todayWhereWasI(position),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.bodySmall.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                    const SizedBox(height: AppSpacing.md),
                    FilledButton.icon(
                      onPressed: () => running == null
                          ? actions.startSession(context)
                          : actions.stopSession(context, running),
                      icon: Icon(
                        running == null
                            ? Icons.timer_outlined
                            : Icons.stop_circle_outlined,
                      ),
                      label: Text(running == null ? l.todayStart : l.todayStop),
                      style: FilledButton.styleFrom(
                        minimumSize: const Size(
                          0,
                          AppSpacing.buttonHeightCompact,
                        ),
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

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppSpacing.radiusXl),
        // The row sizes the card; the art only fills in behind it.
        child: Stack(
          children: <Widget>[
            Positioned.fill(
              child: ImageFiltered(
                imageFilter: ImageFilter.blur(
                  sigmaX: _blurSigma,
                  sigmaY: _blurSigma,
                ),
                child: MediaCoverImage(
                  coverUrl: cover,
                  placeholderIcon: MediaTypeTheme.placeholderIconFor(
                    item.mediaType,
                  ),
                ),
              ),
            ),
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: <Color>[
                      AppColors.background.withValues(alpha: _scrimAlpha),
                      AppColors.background,
                    ],
                  ),
                ),
              ),
            ),
            content,
          ],
        ),
      ),
    );
  }
}
