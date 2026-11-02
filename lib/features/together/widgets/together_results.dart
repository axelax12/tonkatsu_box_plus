import 'package:core/models/collection_item.dart';
import 'package:core/plus/analytics/group_pick.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/app_localizations.dart';
import '../../../shared/constants/media_type_theme.dart';
import '../../../shared/theme/app_colors.dart';
import '../../../shared/theme/app_spacing.dart';
import '../../../shared/theme/app_typography.dart';
import '../../../shared/widgets/media_detail/media_cover_image.dart';
import '../../paths/widgets/path_stop_tile.dart';
import '../../settings/providers/profile_provider.dart';
import '../providers/together_providers.dart';

class TogetherResults extends ConsumerWidget {
  const TogetherResults({super.key});

  static const double _winnerCoverWidth = 140;
  static const double _coverWidth = 40;
  static const double _coverHeight = 60;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final S l = S.of(context);
    final TogetherState state = ref.watch(togetherProvider);
    final TogetherController controller = ref.read(togetherProvider.notifier);
    final String me = ref.watch(currentProfileProvider).id;
    final List<PickResult> results = GroupPick.tally(state.ballot, state.votes);
    if (results.isEmpty) return const SizedBox.shrink();
    final PickResult winner = results.first;
    final CollectionItem top = winner.candidate.item;

    // Only the current profile's own copy has a row id that opens here.
    VoidCallback? opener(PickCandidate c) =>
        c.owners.contains(me) ? () => openPathItem(context, c.item) : null;

    return ListView(
      padding: const EdgeInsets.all(AppSpacing.md),
      children: <Widget>[
        Text(
          l.togetherWinner,
          textAlign: TextAlign.center,
          style: AppTypography.bodySmall.copyWith(
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        Center(
          child: SizedBox(
            width: _winnerCoverWidth,
            child: AspectRatio(
              aspectRatio: AppSpacing.posterAspectRatio,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
                child: MediaCoverImage(
                  coverUrl: top.thumbnailUrl ?? top.coverUrl,
                  placeholderIcon: MediaTypeTheme.placeholderIconFor(
                    top.mediaType,
                  ),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        Text(
          top.itemName,
          textAlign: TextAlign.center,
          style: AppTypography.h2,
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          winner.unanimousFor(state.voters.length)
              ? l.togetherUnanimous
              : l.togetherScore(winner.yes, winner.no),
          textAlign: TextAlign.center,
          style: AppTypography.bodySmall.copyWith(color: AppColors.success),
        ),
        if (opener(winner.candidate) case final VoidCallback open) ...<Widget>[
          const SizedBox(height: AppSpacing.md),
          FilledButton.icon(
            onPressed: open,
            icon: const Icon(Icons.open_in_new),
            label: Text(l.togetherOpen),
          ),
        ],
        const SizedBox(height: AppSpacing.lg),
        for (int i = 1; i < results.length; i++)
          ListTile(
            key: ValueKey<String>(results[i].candidate.key),
            contentPadding: EdgeInsets.zero,
            leading: ClipRRect(
              borderRadius: BorderRadius.circular(AppSpacing.radiusXs),
              child: SizedBox(
                width: _coverWidth,
                height: _coverHeight,
                child: MediaCoverImage(
                  coverUrl:
                      results[i].candidate.item.thumbnailUrl ??
                      results[i].candidate.item.coverUrl,
                  placeholderIcon: MediaTypeTheme.placeholderIconFor(
                    results[i].candidate.item.mediaType,
                  ),
                ),
              ),
            ),
            title: Text(
              results[i].candidate.item.itemName,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            subtitle: Text(
              l.togetherScore(results[i].yes, results[i].no),
              style: AppTypography.caption,
            ),
            trailing: Text('${i + 1}', style: AppTypography.h3),
            onTap: opener(results[i].candidate),
          ),
        const SizedBox(height: AppSpacing.lg),
        Row(
          children: <Widget>[
            Expanded(
              child: OutlinedButton(
                onPressed: controller.voteAgain,
                child: Text(l.togetherVoteAgain),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: FilledButton(
                onPressed: controller.newRound,
                child: Text(l.togetherNewRound),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
