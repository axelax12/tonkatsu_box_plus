import 'dart:ui' show ImageFilter;

import 'package:core/models/collection_item.dart';
import 'package:core/models/profile.dart';
import 'package:core/plus/analytics/group_pick.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/app_localizations.dart';
import '../../../shared/constants/media_type_theme.dart';
import '../../../shared/theme/app_colors.dart';
import '../../../shared/theme/app_spacing.dart';
import '../../../shared/theme/app_typography.dart';
import '../../../shared/utils/duration_formatter.dart';
import '../../../shared/widgets/media_detail/media_cover_image.dart';
import '../../settings/providers/profile_provider.dart';
import '../providers/together_providers.dart';

/// A blank screen between voters, so nobody sees the previous ballot.
class TogetherHandoff extends ConsumerWidget {
  const TogetherHandoff({super.key});

  static const double _avatarRadius = 44;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final S l = S.of(context);
    final Voter? voter = ref.watch(
      togetherProvider.select((TogetherState s) => s.currentVoter),
    );
    if (voter == null) return const SizedBox.shrink();
    final String initial = voter.name.isEmpty
        ? '?'
        : voter.name.characters.first.toUpperCase();
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            CircleAvatar(
              radius: _avatarRadius,
              backgroundColor: AppColors.brand,
              child: Text(
                initial,
                style: AppTypography.h1.copyWith(color: AppColors.onBrand),
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(
              l.togetherPassTo(voter.name),
              textAlign: TextAlign.center,
              style: AppTypography.h2,
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              l.togetherPassHint,
              textAlign: TextAlign.center,
              style: AppTypography.body.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            FilledButton(
              onPressed: () => ref.read(togetherProvider.notifier).beginTurn(),
              child: Text(l.togetherReady(voter.name)),
            ),
          ],
        ),
      ),
    );
  }
}

/// One work at a time, cover first, with three big answers.
class TogetherBallotCard extends ConsumerWidget {
  const TogetherBallotCard({super.key});

  static const double _blurSigma = 24;
  static const double _scrimAlpha = 0.55;
  static const double _coverMaxHeight = 320;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final S l = S.of(context);
    final TogetherState state = ref.watch(togetherProvider);
    final TogetherController controller = ref.read(togetherProvider.notifier);
    final PickCandidate? card = state.currentCard;
    if (card == null) return const SizedBox.shrink();
    final CollectionItem item = card.item;
    final String? cover = item.thumbnailUrl ?? item.coverUrl;
    final ProfilesData profiles = ref.watch(profilesDataProvider);
    final String owners = <String>[
      for (final Profile p in profiles.profiles)
        if (card.owners.contains(p.id)) p.name,
    ].join(', ');
    final int? minutes = card.minutes;
    final int? year = item.releaseYear;

    return Stack(
      fit: StackFit.expand,
      children: <Widget>[
        if (cover != null)
          ImageFiltered(
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
        ColoredBox(
          color: AppColors.background.withValues(alpha: _scrimAlpha),
        ),
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    if (state.cardIndex > 0)
                      IconButton(
                        tooltip: l.togetherBack,
                        icon: const Icon(Icons.undo),
                        onPressed: controller.undo,
                      ),
                    Expanded(
                      child: Text(
                        state.currentVoter?.name ?? '',
                        style: AppTypography.bodySmall,
                      ),
                    ),
                    Text(
                      l.togetherCardProgress(
                        state.cardIndex + 1,
                        state.ballot.length,
                      ),
                      style: AppTypography.bodySmall,
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.sm),
                Expanded(
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(
                        maxHeight: _coverMaxHeight,
                      ),
                      child: AspectRatio(
                        aspectRatio: AppSpacing.posterAspectRatio,
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(
                            AppSpacing.radiusLg,
                          ),
                          child: MediaCoverImage(
                            key: ValueKey<String>(card.key),
                            coverUrl: cover,
                            placeholderIcon: MediaTypeTheme.placeholderIconFor(
                              item.mediaType,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                Text(
                  item.itemName,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.h2,
                ),
                const SizedBox(height: AppSpacing.xs),
                Wrap(
                  alignment: WrapAlignment.center,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: AppSpacing.sm,
                  children: <Widget>[
                    Icon(
                      MediaTypeTheme.iconFor(item.mediaType),
                      size: 16,
                      color: MediaTypeTheme.colorFor(item.mediaType),
                    ),
                    if (year != null)
                      Text('$year', style: AppTypography.bodySmall),
                    if (minutes != null)
                      Text(
                        formatMinutes(minutes, l),
                        style: AppTypography.bodySmall,
                      ),
                  ],
                ),
                if (owners.isNotEmpty) ...<Widget>[
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    l.togetherOwnedBy(owners),
                    textAlign: TextAlign.center,
                    style: AppTypography.caption.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
                const SizedBox(height: AppSpacing.lg),
                Row(
                  children: <Widget>[
                    Expanded(
                      child: _VoteButton(
                        icon: Icons.thumb_down_alt_outlined,
                        label: l.togetherVoteNo,
                        color: AppColors.error,
                        onTap: () => controller.vote(Vote.no),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: _VoteButton(
                        icon: Icons.help_outline,
                        label: l.togetherVoteMaybe,
                        color: AppColors.warning,
                        onTap: () => controller.vote(Vote.maybe),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: _VoteButton(
                        icon: Icons.favorite,
                        label: l.togetherVoteYes,
                        color: AppColors.success,
                        onTap: () => controller.vote(Vote.yes),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _VoteButton extends StatelessWidget {
  const _VoteButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: onTap,
      icon: Icon(icon, color: color),
      label: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(0, AppSpacing.buttonHeight),
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
        side: BorderSide(color: color),
        foregroundColor: AppColors.textPrimary,
      ),
    );
  }
}
