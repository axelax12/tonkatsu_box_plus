import 'package:cached_network_image/cached_network_image.dart';
import 'package:core/models/tracker_achievement.dart';
import 'package:core/plus/database/integrations_dao.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/app_localizations.dart';
import '../../../shared/extensions/snackbar_extension.dart';
import '../../../shared/theme/app_colors.dart';
import '../../../shared/theme/app_spacing.dart';
import '../../../shared/theme/app_typography.dart';
import '../providers/integrations_providers.dart';
import '../steam_achievements_api.dart';
import 'connections_sheet.dart';

/// Steam achievements of a game, synced on demand and at most once a day on
/// their own. Hidden entirely for games with no Steam page.
class SteamAchievementsSection extends ConsumerStatefulWidget {
  const SteamAchievementsSection({
    required this.igdbId,
    required this.accentColor,
    super.key,
  });

  final int igdbId;
  final Color accentColor;

  @override
  ConsumerState<SteamAchievementsSection> createState() =>
      _SteamAchievementsSectionState();
}

class _SteamAchievementsSectionState
    extends ConsumerState<SteamAchievementsSection> {
  static const Duration _autoSyncAge = Duration(days: 1);
  static const int _collapsedCount = 6;

  bool _syncing = false;
  bool _expanded = false;
  bool _autoTried = false;

  Future<void> _sync(String appId, {bool quiet = false}) async {
    final S l = S.of(context);
    setState(() => _syncing = true);
    try {
      await ref.read(steamAchievementsServiceProvider).sync(appId);
    } on SteamAchievementsException catch (e) {
      if (!quiet && mounted) {
        context.showSnack(_reason(e.reason, l), type: SnackType.error);
      }
    } finally {
      if (mounted) setState(() => _syncing = false);
    }
  }

  String _reason(SteamAchievementsReason reason, S l) {
    switch (reason) {
      case SteamAchievementsReason.privateProfile:
        return l.steamPrivateProfile;
      case SteamAchievementsReason.noAchievements:
        return l.steamNoAchievements;
      case SteamAchievementsReason.badKey:
        return l.steamBadKey;
      case SteamAchievementsReason.network:
        return l.steamNetworkError;
    }
  }

  void _maybeAutoSync(String appId, SteamSync? sync) {
    if (_autoTried || _syncing) return;
    _autoTried = true;
    final DateTime? last = sync?.syncedAt;
    if (last != null && DateTime.now().difference(last) < _autoSyncAge) return;
    WidgetsBinding.instance.addPostFrameCallback(
      (Duration _) => _sync(appId, quiet: true),
    );
  }

  @override
  Widget build(BuildContext context) {
    final S l = S.of(context);
    final String? appId = ref.watch(steamAppProvider(widget.igdbId)).valueOrNull;
    if (appId == null) return const SizedBox.shrink();

    final bool connected = ref.watch(steamCredentialsProvider) != null;
    final List<TrackerAchievement> achievements =
        ref.watch(steamAchievementsProvider(appId)).valueOrNull ??
        const <TrackerAchievement>[];
    final AsyncValue<SteamSync?> syncAsync = ref.watch(steamSyncProvider(appId));
    final SteamSync? sync = syncAsync.valueOrNull;
    if (connected && syncAsync.hasValue) _maybeAutoSync(appId, sync);

    final int earned = achievements
        .where((TrackerAchievement a) => a.earned)
        .length;
    final List<TrackerAchievement> ordered = <TrackerAchievement>[
      ...achievements.where((TrackerAchievement a) => a.earned).toList()
        ..sort(
          (TrackerAchievement a, TrackerAchievement b) =>
              (b.earnedAt ?? 0).compareTo(a.earnedAt ?? 0),
        ),
      ...achievements.where((TrackerAchievement a) => !a.earned),
    ];
    final List<TrackerAchievement> shown = _expanded
        ? ordered
        : ordered.take(_collapsedCount).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Row(
          children: <Widget>[
            Icon(Icons.emoji_events_outlined, size: 20, color: widget.accentColor),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Text(
                l.steamAchievementsTitle,
                style: AppTypography.h3.copyWith(fontWeight: FontWeight.w600),
              ),
            ),
            if (connected)
              IconButton(
                tooltip: l.steamSync,
                onPressed: _syncing ? null : () => _sync(appId),
                icon: _syncing
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.sync),
              ),
          ],
        ),
        if (!connected)
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: () => showConnectionsSheet(context),
              icon: const Icon(Icons.link),
              label: Text(l.steamConnect),
              style: TextButton.styleFrom(
                foregroundColor: widget.accentColor,
                minimumSize: const Size(0, AppSpacing.buttonHeightCompact),
              ),
            ),
          )
        else if (achievements.isNotEmpty) ...<Widget>[
          LinearProgressIndicator(
            value: earned / achievements.length,
            color: widget.accentColor,
            backgroundColor: AppColors.surfaceBorder,
            minHeight: 6,
            borderRadius: BorderRadius.circular(AppSpacing.radiusXs),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            l.steamProgress(earned, achievements.length),
            style: AppTypography.bodySmall.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          for (final TrackerAchievement a in shown)
            _AchievementTile(key: ValueKey<String>(a.achievementId), achievement: a),
          if (ordered.length > _collapsedCount)
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                onPressed: () => setState(() => _expanded = !_expanded),
                style: TextButton.styleFrom(
                  minimumSize: const Size(0, AppSpacing.buttonHeightCompact),
                ),
                child: Text(
                  _expanded ? l.steamShowLess : l.steamShowAll(ordered.length),
                ),
              ),
            ),
        ] else if (!_syncing)
          Text(
            l.steamNotSynced,
            style: AppTypography.bodySmall.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
      ],
    );
  }
}

class _AchievementTile extends StatelessWidget {
  const _AchievementTile({required this.achievement, super.key});

  final TrackerAchievement achievement;

  static const double _icon = 40;

  @override
  Widget build(BuildContext context) {
    final S l = S.of(context);
    final bool secret = achievement.type == 'hidden' && !achievement.earned;
    final String? icon = achievement.badgeName;
    final int? at = achievement.earnedAt;
    const int msPerSecond = 1000;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      child: Row(
        children: <Widget>[
          ClipRRect(
            borderRadius: BorderRadius.circular(AppSpacing.radiusXs),
            child: SizedBox(
              width: _icon,
              height: _icon,
              child: icon == null
                  ? const Icon(Icons.emoji_events_outlined)
                  : Opacity(
                      opacity: achievement.earned ? 1 : 0.45,
                      child: CachedNetworkImage(
                        imageUrl: icon,
                        fit: BoxFit.cover,
                        errorWidget: (BuildContext _, String _, Object _) =>
                            const Icon(Icons.emoji_events_outlined),
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
                  secret ? l.steamHiddenAchievement : achievement.title,
                  style: AppTypography.body.copyWith(
                    fontWeight: achievement.earned ? FontWeight.w600 : null,
                    color: achievement.earned ? null : AppColors.textSecondary,
                  ),
                ),
                if (!secret && (achievement.description?.isNotEmpty ?? false))
                  Text(
                    achievement.description ?? '',
                    style: AppTypography.caption,
                  ),
                if (at != null)
                  Text(
                    MaterialLocalizations.of(context).formatMediumDate(
                      DateTime.fromMillisecondsSinceEpoch(at * msPerSecond),
                    ),
                    style: AppTypography.caption.copyWith(
                      color: AppColors.textTertiary,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
