import 'package:core/plus/analytics/goal_progress.dart';
import 'package:core/plus/models/yearly_goal.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/app_localizations.dart';
import '../../../shared/theme/app_colors.dart';
import '../../../shared/theme/app_spacing.dart';
import '../../../shared/theme/app_typography.dart';
import '../../../shared/widgets/confirm_dialog.dart';
import '../providers/insights_providers.dart';
import '../widgets/goal_card.dart';
import '../widgets/goal_editor_sheet.dart';
import '../widgets/year_switcher.dart';

class GoalsScreen extends ConsumerStatefulWidget {
  const GoalsScreen({super.key});

  @override
  ConsumerState<GoalsScreen> createState() => _GoalsScreenState();
}

class _GoalsScreenState extends ConsumerState<GoalsScreen> {
  int _year = DateTime.now().year;

  Future<void> _edit({YearlyGoal? existing}) async {
    final S l = S.of(context);
    final GoalEditResult? result = await showGoalEditorSheet(
      context,
      year: _year,
      existing: existing,
    );
    if (result == null || !mounted) return;
    final GoalsController controller = ref.read(goalsControllerProvider);
    switch (result) {
      case GoalSaved(:final YearlyGoal goal):
        await controller.save(goal);
      case GoalDeleted():
        final YearlyGoal? target = existing;
        if (target == null) return;
        final bool confirmed = await ConfirmDialog.show(
          context,
          title: l.delete,
          message: l.goalDeleteConfirm,
          confirmLabel: l.delete,
        );
        if (confirmed) await controller.delete(target);
    }
  }

  @override
  Widget build(BuildContext context) {
    final S l = S.of(context);
    final AsyncValue<List<GoalProgress>> progress =
        ref.watch(goalProgressProvider(_year));
    final List<GoalProgress> goals =
        progress.valueOrNull ?? const <GoalProgress>[];

    return ListView(
      padding: const EdgeInsets.all(AppSpacing.md),
      children: <Widget>[
        YearSwitcher(
          year: _year,
          onChanged: (int year) => setState(() => _year = year),
        ),
        const SizedBox(height: AppSpacing.sm),
        if (!progress.hasValue)
          const Padding(
            padding: EdgeInsets.all(AppSpacing.xl),
            child: Center(child: CircularProgressIndicator()),
          )
        else if (goals.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.xl),
            child: Text(
              l.goalNoneYet(_year),
              textAlign: TextAlign.center,
              style:
                  AppTypography.body.copyWith(color: AppColors.textSecondary),
            ),
          )
        else
          for (final GoalProgress p in goals)
            Padding(
              key: ValueKey<int>(p.goal.id),
              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: GoalCard(
                progress: p,
                onTap: () => _edit(existing: p.goal),
              ),
            ),
        const SizedBox(height: AppSpacing.sm),
        FilledButton.icon(
          onPressed: _edit,
          icon: const Icon(Icons.add),
          label: Text(l.goalAdd),
        ),
      ],
    );
  }
}
