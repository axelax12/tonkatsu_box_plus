import 'package:core/plus/models/playthrough.dart';
import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';
import '../../../shared/theme/app_spacing.dart';
import '../../../shared/theme/app_typography.dart';
import '../utils/journal_format.dart';
import 'journal_sheet.dart';

sealed class PlaythroughEditResult {
  const PlaythroughEditResult();
}

class PlaythroughSaved extends PlaythroughEditResult {
  const PlaythroughSaved(this.playthrough);

  final Playthrough playthrough;
}

class PlaythroughDeleted extends PlaythroughEditResult {
  const PlaythroughDeleted();
}

Future<PlaythroughEditResult?> showPlaythroughEditorSheet(
  BuildContext context, {
  required int itemId,
  Playthrough? existing,
}) {
  final S l = S.of(context);
  return showJournalSheet<PlaythroughEditResult>(
    context,
    title: existing == null ? l.journalAddPlaythrough : l.edit,
    builder: (BuildContext _) =>
        _PlaythroughForm(itemId: itemId, existing: existing),
  );
}

class _PlaythroughForm extends StatefulWidget {
  const _PlaythroughForm({required this.itemId, this.existing});

  final int itemId;
  final Playthrough? existing;

  @override
  State<_PlaythroughForm> createState() => _PlaythroughFormState();
}

class _PlaythroughFormState extends State<_PlaythroughForm> {
  late final TextEditingController _label =
      TextEditingController(text: widget.existing?.label ?? '');
  late final TextEditingController _review =
      TextEditingController(text: widget.existing?.review ?? '');
  late PlaythroughStatus _status =
      widget.existing?.status ?? PlaythroughStatus.inProgress;
  late DateTime? _startedAt = widget.existing?.startedAt ?? DateTime.now();
  late DateTime? _finishedAt = widget.existing?.finishedAt;
  late double? _rating = widget.existing?.rating;

  @override
  void dispose() {
    _label.dispose();
    _review.dispose();
    super.dispose();
  }

  Future<DateTime?> _pickDate(DateTime? initial) {
    final DateTime now = DateTime.now();
    final DateTime start = initial ?? now;
    return showDatePicker(
      context: context,
      initialDate: start.isAfter(now) ? now : start,
      firstDate: DateTime(1980),
      lastDate: now,
    );
  }

  void _setStatus(PlaythroughStatus status) {
    setState(() {
      _status = status;
      if (status != PlaythroughStatus.inProgress && _finishedAt == null) {
        _finishedAt = DateTime.now();
      }
    });
  }

  void _save() {
    final DateTime now = DateTime.now();
    final String label = _label.text.trim();
    final String review = _review.text.trim();
    final Playthrough base = widget.existing ??
        Playthrough(
          id: 0,
          itemId: widget.itemId,
          status: _status,
          createdAt: now,
          updatedAt: now,
        );
    final Playthrough result = base.copyWith(
      label: label,
      clearLabel: label.isEmpty,
      status: _status,
      startedAt: _startedAt,
      clearStartedAt: _startedAt == null,
      finishedAt: _finishedAt,
      clearFinishedAt: _finishedAt == null,
      rating: _rating,
      clearRating: _rating == null,
      review: review,
      clearReview: review.isEmpty,
      updatedAt: now,
    );
    Navigator.of(context).pop<PlaythroughEditResult>(PlaythroughSaved(result));
  }

  Widget _dateTile({
    required String title,
    required DateTime? value,
    required ValueChanged<DateTime?> onChanged,
  }) {
    final S l = S.of(context);
    final MaterialLocalizations material = MaterialLocalizations.of(context);
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: const Icon(Icons.event_outlined),
      title: Text(title),
      subtitle: Text(
        value == null ? l.journalNotSet : material.formatMediumDate(value),
      ),
      trailing: value == null
          ? null
          : IconButton(
              icon: const Icon(Icons.close),
              tooltip: l.journalNotSet,
              onPressed: () => onChanged(null),
            ),
      onTap: () async {
        final DateTime? picked = await _pickDate(value);
        if (picked != null) onChanged(picked);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final S l = S.of(context);
    final double? rating = _rating;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        TextField(
          controller: _label,
          textCapitalization: TextCapitalization.sentences,
          decoration: InputDecoration(labelText: l.journalPlaythroughLabel),
        ),
        const SizedBox(height: AppSpacing.md),
        SegmentedButton<PlaythroughStatus>(
          segments: <ButtonSegment<PlaythroughStatus>>[
            for (final PlaythroughStatus status in PlaythroughStatus.values)
              ButtonSegment<PlaythroughStatus>(
                value: status,
                label: Text(playthroughStatusLabel(status, l)),
              ),
          ],
          selected: <PlaythroughStatus>{_status},
          showSelectedIcon: false,
          onSelectionChanged: (Set<PlaythroughStatus> selection) =>
              _setStatus(selection.first),
        ),
        _dateTile(
          title: l.journalPlaythroughStarted,
          value: _startedAt,
          onChanged: (DateTime? v) => setState(() => _startedAt = v),
        ),
        _dateTile(
          title: l.journalPlaythroughFinished,
          value: _finishedAt,
          onChanged: (DateTime? v) => setState(() => _finishedAt = v),
        ),
        Row(
          children: <Widget>[
            Text(l.journalPlaythroughRating, style: AppTypography.body),
            const Spacer(),
            Text(
              rating == null
                  ? l.journalPlaythroughNoRating
                  : rating.toStringAsFixed(0),
              style: AppTypography.body.copyWith(fontWeight: FontWeight.w600),
            ),
            if (rating != null)
              IconButton(
                icon: const Icon(Icons.close, size: 18),
                tooltip: l.journalPlaythroughNoRating,
                onPressed: () => setState(() => _rating = null),
              ),
          ],
        ),
        Slider(
          value: rating ?? Playthrough.minRating,
          min: Playthrough.minRating,
          max: Playthrough.maxRating,
          divisions:
              (Playthrough.maxRating - Playthrough.minRating).round(),
          label: rating?.toStringAsFixed(0),
          onChanged: (double v) => setState(() => _rating = v),
        ),
        TextField(
          controller: _review,
          minLines: 3,
          maxLines: 10,
          textCapitalization: TextCapitalization.sentences,
          decoration: InputDecoration(labelText: l.journalPlaythroughReview),
        ),
        const SizedBox(height: AppSpacing.md),
        JournalSheetActions(
          saveLabel: l.save,
          cancelLabel: l.cancel,
          onSave: _save,
          deleteLabel: l.delete,
          onDelete: widget.existing == null
              ? null
              : () => Navigator.of(context)
                  .pop<PlaythroughEditResult>(const PlaythroughDeleted()),
        ),
      ],
    );
  }
}
