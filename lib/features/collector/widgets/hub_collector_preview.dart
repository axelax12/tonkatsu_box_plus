import 'package:core/plus/analytics/collector_insights.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/app_localizations.dart';
import '../../../shared/theme/app_colors.dart';
import '../../../shared/theme/app_typography.dart';
import '../providers/collector_providers.dart';

class HubCollectorPreview extends ConsumerWidget {
  const HubCollectorPreview({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final S l = S.of(context);
    final List<KeepsakeProgress> keepsakes =
        ref.watch(keepsakesProvider).valueOrNull ?? const <KeepsakeProgress>[];
    final CollectionValue? value = ref
        .watch(collectionValueProvider)
        .valueOrNull;
    final int unlocked = keepsakes
        .where((KeepsakeProgress k) => k.unlocked)
        .length;
    return Text(
      l.hubCollectorPreview(
        value?.physicalCount ?? 0,
        unlocked,
        Keepsake.values.length,
      ),
      style: AppTypography.bodySmall.copyWith(color: AppColors.textSecondary),
    );
  }
}
