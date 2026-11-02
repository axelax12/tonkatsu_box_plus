import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/app_localizations.dart';
import '../../../shared/theme/app_colors.dart';
import '../../../shared/theme/app_spacing.dart';
import '../../../shared/theme/app_typography.dart';
import '../providers/today_providers.dart';

String todaySectionLabel(TodaySection section, S l) => switch (section) {
  TodaySection.resume => l.todayResume,
  TodaySection.goals => l.todayGoals,
  TodaySection.upNext => l.todayUpNext,
  TodaySection.releases => l.todayReleases,
  TodaySection.backlog => l.todayBacklog,
  TodaySection.lists => l.todayLists,
};

IconData todaySectionIcon(TodaySection section) => switch (section) {
  TodaySection.resume => Icons.play_circle_outline,
  TodaySection.goals => Icons.donut_large,
  TodaySection.upNext => Icons.route_outlined,
  TodaySection.releases => Icons.event_outlined,
  TodaySection.backlog => Icons.inventory_2_outlined,
  TodaySection.lists => Icons.filter_list_alt,
};

Future<void> showTodayCustomizeSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: AppColors.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(
        top: Radius.circular(AppSpacing.radiusLg),
      ),
    ),
    builder: (BuildContext _) => const _CustomizeSheet(),
  );
}

class _CustomizeSheet extends ConsumerWidget {
  const _CustomizeSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final S l = S.of(context);
    final TodayLayout layout = ref.watch(todayLayoutProvider);
    final TodayLayoutNotifier notifier = ref.read(todayLayoutProvider.notifier);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.md,
            AppSpacing.md,
            AppSpacing.md,
            0,
          ),
          child: Text(
            l.todayCustomize,
            style: AppTypography.h3.copyWith(fontWeight: FontWeight.w600),
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Text(
            l.todayCustomizeHint,
            style: AppTypography.bodySmall.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
        ),
        Flexible(
          child: ReorderableListView.builder(
            shrinkWrap: true,
            buildDefaultDragHandles: false,
            itemCount: layout.order.length,
            onReorderItem: notifier.move,
            itemBuilder: (BuildContext context, int index) {
              final TodaySection section = layout.order[index];
              return SwitchListTile(
                key: ValueKey<TodaySection>(section),
                secondary: ReorderableDragStartListener(
                  index: index,
                  child: const Icon(Icons.drag_handle),
                ),
                title: Row(
                  children: <Widget>[
                    Icon(todaySectionIcon(section), size: 20),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(child: Text(todaySectionLabel(section, l))),
                  ],
                ),
                value: !layout.hidden.contains(section),
                onChanged: (bool v) => notifier.setVisible(section, visible: v),
              );
            },
          ),
        ),
        const SizedBox(height: AppSpacing.md),
      ],
    );
  }
}
