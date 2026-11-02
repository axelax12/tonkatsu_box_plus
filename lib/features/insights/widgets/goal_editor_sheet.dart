import 'package:core/models/media_type.dart';
import 'package:core/plus/models/yearly_goal.dart';
import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';
import '../../../shared/theme/app_spacing.dart';
import '../../../shared/theme/app_typography.dart';
import '../../journal/widgets/journal_sheet.dart';
import '../utils/insights_format.dart';

sealed class GoalEditResult {
  const GoalEditResult();
}

class GoalSaved extends GoalEditResult {
  const GoalSaved(this.goal);

  final YearlyGoal goal;
}

class GoalDeleted extends GoalEditResult {
  const GoalDeleted();
}

/// Types a goal can be scoped to; podcasts and custom cards have no "finish".
const List<MediaType> kGoalMediaTypes = <MediaType>[
  MediaType.game,
  MediaType.book,
  MediaType.movie,
  MediaType.tvShow,
  MediaType.anime,
  MediaType.manga,
  MediaType.visualNovel,
  MediaType.animation,
];

Future<GoalEditResult?> showGoalEditorSheet(
  BuildContext context, {
  required int year,
  YearlyGoal? existing,
}) {
  final S l = S.of(context);
  return showJournalSheet<GoalEditResult>(
    context,
    title: existing == null ? l.goalAdd : l.goalEdit,
    builder: (BuildContext _) => _GoalForm(year: year, existing: existing),
  );
}

class _GoalForm extends StatefulWidget {
  const _GoalForm({required this.year, this.existing});

  final int year;
  final YearlyGoal? existing;

  @override
  State<_GoalForm> createState() => _GoalFormState();
}

class _GoalFormState extends State<_GoalForm> {
  static const int _defaultTarget = 12;

  late GoalMetric _metric = widget.existing?.metric ?? GoalMetric.completed;
  late MediaType? _type = widget.existing?.mediaType;
  late final TextEditingController _target = TextEditingController(
    text: '${widget.existing?.target ?? _defaultTarget}',
  );

  @override
  void initState() {
    super.initState();
    _target.addListener(_onChanged);
  }

  @override
  void dispose() {
    _target.removeListener(_onChanged);
    _target.dispose();
    super.dispose();
  }

  void _onChanged() => setState(() {});

  int? get _targetValue {
    final int? value = int.tryParse(_target.text.trim());
    return (value == null || value < YearlyGoal.minTarget) ? null : value;
  }

  void _save() {
    final int? target = _targetValue;
    if (target == null) return;
    final DateTime now = DateTime.now();
    final YearlyGoal base =
        widget.existing ??
        YearlyGoal(
          id: 0,
          year: widget.year,
          metric: _metric,
          target: target,
          createdAt: now,
          updatedAt: now,
        );
    Navigator.of(context).pop<GoalEditResult>(
      GoalSaved(
        base.copyWith(
          metric: _metric,
          mediaType: _type,
          clearMediaType: _type == null,
          target: target,
          updatedAt: now,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final S l = S.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.xs,
          children: <Widget>[
            for (final GoalMetric metric in GoalMetric.values)
              ChoiceChip(
                key: ValueKey<GoalMetric>(metric),
                avatar: Icon(goalMetricIcon(metric), size: 18),
                label: Text(goalMetricLabel(metric, l)),
                selected: _metric == metric,
                onSelected: (bool _) => setState(() => _metric = metric),
              ),
          ],
        ),
        if (_metric == GoalMetric.hours) ...<Widget>[
          const SizedBox(height: AppSpacing.xs),
          Text(l.goalHoursHint, style: AppTypography.caption),
        ],
        const SizedBox(height: AppSpacing.md),
        DropdownButtonFormField<MediaType?>(
          initialValue: _type,
          decoration: InputDecoration(labelText: l.goalScope),
          items: <DropdownMenuItem<MediaType?>>[
            DropdownMenuItem<MediaType?>(child: Text(l.goalAllTypes)),
            for (final MediaType type in kGoalMediaTypes)
              DropdownMenuItem<MediaType?>(
                value: type,
                child: Text(mediaScopeLabel(type, l)),
              ),
          ],
          onChanged: (MediaType? value) => setState(() => _type = value),
        ),
        const SizedBox(height: AppSpacing.md),
        TextField(
          controller: _target,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(labelText: l.goalTarget),
        ),
        const SizedBox(height: AppSpacing.md),
        JournalSheetActions(
          saveLabel: l.save,
          cancelLabel: l.cancel,
          onSave: _targetValue == null ? null : _save,
          deleteLabel: l.delete,
          onDelete: widget.existing == null
              ? null
              : () => Navigator.of(
                  context,
                ).pop<GoalEditResult>(const GoalDeleted()),
        ),
      ],
    );
  }
}
