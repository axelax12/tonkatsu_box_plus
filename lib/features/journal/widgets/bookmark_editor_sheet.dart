import 'package:core/plus/models/resume_bookmark.dart';
import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';
import '../../../shared/theme/app_spacing.dart';
import 'journal_sheet.dart';

Future<ResumeBookmark?> showBookmarkEditorSheet(
  BuildContext context, {
  required int itemId,
  ResumeBookmark? existing,
}) {
  final S l = S.of(context);
  return showJournalSheet<ResumeBookmark>(
    context,
    title: l.journalResumeTitle,
    builder: (BuildContext _) =>
        _BookmarkForm(itemId: itemId, existing: existing),
  );
}

class _BookmarkForm extends StatefulWidget {
  const _BookmarkForm({required this.itemId, this.existing});

  final int itemId;
  final ResumeBookmark? existing;

  @override
  State<_BookmarkForm> createState() => _BookmarkFormState();
}

class _BookmarkFormState extends State<_BookmarkForm> {
  late final TextEditingController _position =
      TextEditingController(text: widget.existing?.position ?? '');
  late final TextEditingController _objective =
      TextEditingController(text: widget.existing?.objective ?? '');
  late final TextEditingController _reminders =
      TextEditingController(text: widget.existing?.reminders ?? '');
  late final TextEditingController _characters =
      TextEditingController(text: widget.existing?.characters ?? '');
  late final TextEditingController _notes =
      TextEditingController(text: widget.existing?.notes ?? '');

  @override
  void dispose() {
    _position.dispose();
    _objective.dispose();
    _reminders.dispose();
    _characters.dispose();
    _notes.dispose();
    super.dispose();
  }

  void _save() {
    Navigator.of(context).pop<ResumeBookmark>(
      ResumeBookmark(
        itemId: widget.itemId,
        position: _position.text,
        objective: _objective.text,
        reminders: _reminders.text,
        characters: _characters.text,
        notes: _notes.text,
        updatedAt: DateTime.now(),
      ),
    );
  }

  Widget _field(
    TextEditingController controller,
    String label,
    IconData icon, {
    int maxLines = 1,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: TextField(
        controller: controller,
        minLines: 1,
        maxLines: maxLines,
        textCapitalization: TextCapitalization.sentences,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon),
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
        _field(_position, l.journalResumePosition, Icons.place_outlined),
        _field(_objective, l.journalResumeObjective, Icons.flag_outlined),
        _field(
          _reminders,
          l.journalResumeReminders,
          Icons.sports_esports_outlined,
          maxLines: 5,
        ),
        _field(
          _characters,
          l.journalResumeCharacters,
          Icons.people_outline,
          maxLines: 5,
        ),
        _field(_notes, l.journalResumeNotes, Icons.notes, maxLines: 6),
        const SizedBox(height: AppSpacing.sm),
        JournalSheetActions(
          saveLabel: l.save,
          cancelLabel: l.cancel,
          onSave: _save,
        ),
      ],
    );
  }
}
