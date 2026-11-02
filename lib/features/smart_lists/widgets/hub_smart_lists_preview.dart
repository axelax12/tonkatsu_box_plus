import 'package:core/plus/models/smart_list.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/app_localizations.dart';
import '../../../shared/theme/app_colors.dart';
import '../../../shared/theme/app_spacing.dart';
import '../../../shared/theme/app_typography.dart';
import '../providers/smart_list_providers.dart';

class HubSmartListsPreview extends ConsumerWidget {
  const HubSmartListsPreview({super.key});

  static const int _shown = 3;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final S l = S.of(context);
    final List<SmartList> lists =
        ref.watch(smartListsProvider).valueOrNull ?? const <SmartList>[];
    if (lists.isEmpty) {
      return Text(
        l.smartNoneYet,
        style: AppTypography.bodySmall.copyWith(color: AppColors.textSecondary),
      );
    }
    return Wrap(
      spacing: AppSpacing.sm,
      runSpacing: AppSpacing.xs,
      children: <Widget>[
        for (final SmartList list in lists.take(_shown))
          Chip(key: ValueKey<int>(list.id), label: Text(list.name)),
      ],
    );
  }
}
