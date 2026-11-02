import 'package:core/plus/models/journal_entry.dart';
import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';
import '../../../shared/theme/app_spacing.dart';
import '../utils/journal_format.dart';
import 'journal_sheet.dart';

/// Result of the entry editor: a saved entry, or a request to delete it.
sealed class EntryEditResult {
  const EntryEditResult();
}

class EntrySaved extends EntryEditResult {
  const EntrySaved(this.entry);

  final JournalEntry entry;
}

class EntryDeleted extends EntryEditResult {
  const EntryDeleted();
}

/// Pass [existing] to edit; otherwise a new entry is drafted for [itemId].
Future<EntryEditResult?> showEntryEditorSheet(
  BuildContext context, {
  required int itemId,
  JournalEntry? existing,
  JournalEntryKind initialKind = JournalEntryKind.note,
  String? initialProgress,
}) {
  final S l = S.of(context);
  return showJournalSheet<EntryEditResult>(
    context,
    title: existing == null ? l.journalAddEntry : l.edit,
    builder: (BuildContext _) => _EntryEditorForm(
      itemId: itemId,
      existing: existing,
      initialKind: initialKind,
      initialProgress: initialProgress,
    ),
  );
}

class _EntryEditorForm extends StatefulWidget {
  const _EntryEditorForm({
    required this.itemId,
    required this.initialKind,
    this.existing,
    this.initialProgress,
  });

  final int itemId;
  final JournalEntry? existing;
  final JournalEntryKind initialKind;
  final String? initialProgress;

  @override
  State<_EntryEditorForm> createState() => _EntryEditorFormState();
}

class _EntryEditorFormState extends State<_EntryEditorForm> {
  late JournalEntryKind _kind = widget.existing?.kind ?? widget.initialKind;
  late final TextEditingController _body =
      TextEditingController(text: widget.existing?.body ?? '');
  late final TextEditingController _progress = TextEditingController(
    text: widget.existing?.progressLabel ?? widget.initialProgress ?? '',
  );
  late bool _spoiler = widget.existing?.isSpoiler ?? false;
  late DateTime _occurredAt = widget.existing?.occurredAt ?? DateTime.now();

  @override
  void initState() {
    super.initState();
    _body.addListener(_onTextChanged);
  }

  @override
  void dispose() {
    _body.removeListener(_onTextChanged);
    _body.dispose();
    _progress.dispose();
    super.dispose();
  }

  void _onTextChanged() => setState(() {});

  bool get _canSave => _body.text.trim().isNotEmpty;

  Future<void> _pickDate() async {
    final DateTime now = DateTime.now();
    final DateTime? date = await showDatePicker(
      context: context,
      initialDate: _occurredAt.isAfter(now) ? now : _occurredAt,
      firstDate: DateTime(2000),
      lastDate: now,
    );
    if (date == null || !mounted) return;
    setState(() {
      _occurredAt = DateTime(
        date.year,
        date.month,
        date.day,
        _occurredAt.hour,
        _occurredAt.minute,
      );
    });
  }

  void _save() {
    final DateTime now = DateTime.now();
    final String progress = _progress.text.trim();
    final JournalEntry? existing = widget.existing;
    final JournalEntry entry = existing != null
        ? existing.copyWith(
            kind: _kind,
            body: _body.text.trim(),
            progressLabel: progress,
            clearProgressLabel: progress.isEmpty,
            isSpoiler: _spoiler,
            occurredAt: _occurredAt,
            updatedAt: now,
          )
        : JournalEntry(
            id: 0,
            itemId: widget.itemId,
            kind: _kind,
            body: _body.text.trim(),
            progressLabel: progress.isEmpty ? null : progress,
            isSpoiler: _spoiler,
            occurredAt: _occurredAt,
            createdAt: now,
            updatedAt: now,
          );
    Navigator.of(context).pop<EntryEditResult>(EntrySaved(entry));
  }

  @override
  Widget build(BuildContext context) {
    final S l = S.of(context);
    final MaterialLocalizations material = MaterialLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.xs,
          children: <Widget>[
            for (final JournalEntryKind kind in kEditableJournalKinds)
              ChoiceChip(
                key: ValueKey<JournalEntryKind>(kind),
                avatar: Icon(journalKindIcon(kind), size: 18),
                label: Text(journalKindLabel(kind, l)),
                selected: _kind == kind,
                onSelected: (bool _) => setState(() => _kind = kind),
              ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        TextField(
          controller: _body,
          autofocus: widget.existing == null,
          minLines: 3,
          maxLines: 10,
          textCapitalization: TextCapitalization.sentences,
          decoration: InputDecoration(labelText: l.journalEntryText),
        ),
        const SizedBox(height: AppSpacing.sm),
        TextField(
          controller: _progress,
          textCapitalization: TextCapitalization.sentences,
          decoration: InputDecoration(labelText: l.journalEntryProgress),
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(l.journalEntrySpoiler),
          value: _spoiler,
          onChanged: (bool value) => setState(() => _spoiler = value),
        ),
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.event_outlined),
          title: Text(l.journalEntryDate),
          subtitle: Text(material.formatMediumDate(_occurredAt)),
          onTap: _pickDate,
        ),
        const SizedBox(height: AppSpacing.sm),
        JournalSheetActions(
          saveLabel: l.save,
          cancelLabel: l.cancel,
          onSave: _canSave ? _save : null,
          deleteLabel: l.delete,
          onDelete: widget.existing == null
              ? null
              : () => Navigator.of(context)
                  .pop<EntryEditResult>(const EntryDeleted()),
        ),
      ],
    );
  }
}
