import 'package:core/plus/models/play_session.dart';
import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';
import '../../../shared/theme/app_spacing.dart';
import '../../../shared/theme/app_typography.dart';
import 'journal_sheet.dart';

typedef SessionWrapUp = ({String? note, String? progressLabel});

sealed class SessionEditResult {
  const SessionEditResult();
}

class SessionInput extends SessionEditResult {
  const SessionInput({
    required this.startedAt,
    required this.duration,
    this.note,
    this.progressLabel,
  });

  final DateTime startedAt;
  final Duration duration;
  final String? note;
  final String? progressLabel;
}

class SessionDeleteRequested extends SessionEditResult {
  const SessionDeleteRequested();
}

/// Asks for an optional note and progress when a session ends. Null means the
/// user backed out and the session keeps running.
Future<SessionWrapUp?> showStopSessionSheet(
  BuildContext context, {
  String? initialProgress,
}) {
  final S l = S.of(context);
  return showJournalSheet<SessionWrapUp>(
    context,
    title: l.journalStopSheetTitle,
    builder: (BuildContext _) =>
        _StopSessionForm(initialProgress: initialProgress),
  );
}

/// Logs a past session, or edits [existing] (a timer left running overnight).
Future<SessionEditResult?> showManualSessionSheet(
  BuildContext context, {
  PlaySession? existing,
}) {
  final S l = S.of(context);
  return showJournalSheet<SessionEditResult>(
    context,
    title: existing == null ? l.journalLogPastSession : l.edit,
    builder: (BuildContext _) => _ManualSessionForm(existing: existing),
  );
}

class _StopSessionForm extends StatefulWidget {
  const _StopSessionForm({this.initialProgress});

  final String? initialProgress;

  @override
  State<_StopSessionForm> createState() => _StopSessionFormState();
}

class _StopSessionFormState extends State<_StopSessionForm> {
  final TextEditingController _note = TextEditingController();
  late final TextEditingController _progress =
      TextEditingController(text: widget.initialProgress ?? '');

  @override
  void dispose() {
    _note.dispose();
    _progress.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final S l = S.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        TextField(
          controller: _progress,
          textCapitalization: TextCapitalization.sentences,
          decoration: InputDecoration(labelText: l.journalEntryProgress),
        ),
        const SizedBox(height: AppSpacing.sm),
        TextField(
          controller: _note,
          minLines: 2,
          maxLines: 5,
          textCapitalization: TextCapitalization.sentences,
          decoration: InputDecoration(labelText: l.journalSessionNote),
        ),
        const SizedBox(height: AppSpacing.md),
        JournalSheetActions(
          saveLabel: l.journalStopSession,
          cancelLabel: l.cancel,
          onSave: () => Navigator.of(context).pop<SessionWrapUp>((
            note: _note.text,
            progressLabel: _progress.text,
          )),
        ),
      ],
    );
  }
}

class _ManualSessionForm extends StatefulWidget {
  const _ManualSessionForm({this.existing});

  final PlaySession? existing;

  @override
  State<_ManualSessionForm> createState() => _ManualSessionFormState();
}

class _ManualSessionFormState extends State<_ManualSessionForm> {
  static const Duration _defaultDuration = Duration(hours: 1);

  late final Duration _initialDuration = widget.existing != null
      ? Duration(seconds: widget.existing?.durationSeconds ?? 0)
      : _defaultDuration;
  late final TextEditingController _hours =
      TextEditingController(text: '${_initialDuration.inHours}');
  late final TextEditingController _minutes = TextEditingController(
    text: '${_initialDuration.inMinutes % Duration.minutesPerHour}',
  );
  late final TextEditingController _note =
      TextEditingController(text: widget.existing?.note ?? '');
  late final TextEditingController _progress =
      TextEditingController(text: widget.existing?.progressLabel ?? '');
  late DateTime _start =
      widget.existing?.startedAt ?? DateTime.now().subtract(_defaultDuration);
  String? _error;

  @override
  void dispose() {
    _hours.dispose();
    _minutes.dispose();
    _note.dispose();
    _progress.dispose();
    super.dispose();
  }

  Future<void> _pickStart() async {
    final DateTime now = DateTime.now();
    final DateTime? date = await showDatePicker(
      context: context,
      initialDate: _start.isAfter(now) ? now : _start,
      firstDate: DateTime(2000),
      lastDate: now,
    );
    if (date == null || !mounted) return;
    final TimeOfDay? time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_start),
    );
    if (!mounted) return;
    final TimeOfDay picked = time ?? TimeOfDay.fromDateTime(_start);
    setState(() {
      _start = DateTime(
        date.year,
        date.month,
        date.day,
        picked.hour,
        picked.minute,
      );
    });
  }

  void _save() {
    final S l = S.of(context);
    final int hours = int.tryParse(_hours.text.trim()) ?? 0;
    final int minutes = int.tryParse(_minutes.text.trim()) ?? 0;
    final Duration duration = Duration(hours: hours, minutes: minutes);
    if (hours < 0 || minutes < 0 || duration <= Duration.zero) {
      setState(() => _error = l.journalInvalidDuration);
      return;
    }
    Navigator.of(context).pop<SessionEditResult>(
      SessionInput(
        startedAt: _start,
        duration: duration,
        note: _note.text,
        progressLabel: _progress.text,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final S l = S.of(context);
    final MaterialLocalizations material = MaterialLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.event_outlined),
          title: Text(l.journalSessionStart),
          subtitle: Text(
            '${material.formatMediumDate(_start)} · '
            '${material.formatTimeOfDay(TimeOfDay.fromDateTime(_start))}',
          ),
          onTap: _pickStart,
        ),
        Text(l.journalSessionDuration, style: AppTypography.bodySmall),
        const SizedBox(height: AppSpacing.xs),
        Row(
          children: <Widget>[
            Expanded(
              child: TextField(
                controller: _hours,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(labelText: l.journalHours),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: TextField(
                controller: _minutes,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(labelText: l.journalMinutes),
              ),
            ),
          ],
        ),
        if (_error != null) ...<Widget>[
          const SizedBox(height: AppSpacing.xs),
          Text(
            _error ?? '',
            style: AppTypography.bodySmall.copyWith(
              color: Theme.of(context).colorScheme.error,
            ),
          ),
        ],
        const SizedBox(height: AppSpacing.sm),
        TextField(
          controller: _progress,
          textCapitalization: TextCapitalization.sentences,
          decoration: InputDecoration(labelText: l.journalEntryProgress),
        ),
        const SizedBox(height: AppSpacing.sm),
        TextField(
          controller: _note,
          minLines: 2,
          maxLines: 5,
          textCapitalization: TextCapitalization.sentences,
          decoration: InputDecoration(labelText: l.journalSessionNote),
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
                  .pop<SessionEditResult>(const SessionDeleteRequested()),
        ),
      ],
    );
  }
}
