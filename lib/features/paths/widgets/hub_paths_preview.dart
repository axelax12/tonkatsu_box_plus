import 'package:core/plus/analytics/path_walk.dart';
import 'package:core/plus/models/media_path.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/app_localizations.dart';
import '../../../shared/theme/app_colors.dart';
import '../../../shared/theme/app_spacing.dart';
import '../../../shared/theme/app_typography.dart';
import '../paths_format.dart';
import '../providers/paths_providers.dart';

class HubPathsPreview extends ConsumerWidget {
  const HubPathsPreview({super.key});

  static const int _shown = 3;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final S l = S.of(context);
    final List<MediaPath> paths =
        ref.watch(pathsProvider).valueOrNull ?? const <MediaPath>[];
    if (paths.isEmpty) {
      return Text(
        l.pathsNoneYet,
        style: AppTypography.bodySmall.copyWith(color: AppColors.textSecondary),
      );
    }
    return Wrap(
      spacing: AppSpacing.sm,
      runSpacing: AppSpacing.xs,
      children: <Widget>[
        for (final MediaPath p in paths.take(_shown))
          _PathChip(key: ValueKey<int>(p.id), path: p),
      ],
    );
  }
}

class _PathChip extends ConsumerWidget {
  const _PathChip({required this.path, super.key});

  final MediaPath path;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final PathWalk? walk = ref
        .watch(pathWalkProvider((pathId: path.id, order: path.defaultOrder)))
        .valueOrNull;
    final String progress = walk == null || walk.requiredTotal == 0
        ? ''
        : ' ${walk.requiredDone}/${walk.requiredTotal}';
    return Chip(
      avatar: Icon(pathKindIcon(path.kind), size: 16),
      label: Text('${path.name}$progress'),
    );
  }
}
