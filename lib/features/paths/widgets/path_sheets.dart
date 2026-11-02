import 'package:core/plus/models/media_path.dart';
import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';
import '../../../shared/theme/app_spacing.dart';
import '../../journal/widgets/journal_sheet.dart';
import '../paths_format.dart';

class PathDraft {
  const PathDraft({required this.name, required this.kind, this.description});

  final String name;
  final PathKind kind;
  final String? description;
}

Future<PathDraft?> showPathEditorSheet(
  BuildContext context, {
  MediaPath? existing,
  PathKind initialKind = PathKind.universe,
  String initialName = '',
}) {
  final S l = S.of(context);
  return showJournalSheet<PathDraft>(
    context,
    title: existing == null ? l.pathNew : l.edit,
    builder: (BuildContext _) => _PathForm(
      existing: existing,
      initialKind: initialKind,
      initialName: initialName,
    ),
  );
}

sealed class StopEditResult {
  const StopEditResult();
}

class StopSaved extends StopEditResult {
  const StopSaved(this.entry);

  final PathEntry entry;
}

class StopRemoved extends StopEditResult {
  const StopRemoved();
}

Future<StopEditResult?> showStopEditorSheet(
  BuildContext context, {
  required PathEntry entry,
  required String title,
}) {
  return showJournalSheet<StopEditResult>(
    context,
    title: title,
    builder: (BuildContext _) => _StopForm(entry: entry),
  );
}

class _PathForm extends StatefulWidget {
  const _PathForm({
    required this.existing,
    required this.initialKind,
    required this.initialName,
  });

  final MediaPath? existing;
  final PathKind initialKind;
  final String initialName;

  @override
  State<_PathForm> createState() => _PathFormState();
}

class _PathFormState extends State<_PathForm> {
  late PathKind _kind = widget.existing?.kind ?? widget.initialKind;
  late final TextEditingController _name = TextEditingController(
    text: widget.existing?.name ?? widget.initialName,
  );
  late final TextEditingController _description = TextEditingController(
    text: widget.existing?.description ?? '',
  );

  @override
  void dispose() {
    _name.dispose();
    _description.dispose();
    super.dispose();
  }

  void _save() {
    final String name = _name.text.trim();
    if (name.isEmpty) return;
    final String description = _description.text.trim();
    Navigator.of(context).pop(
      PathDraft(
        name: name,
        kind: _kind,
        description: description.isEmpty ? null : description,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final S l = S.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        SegmentedButton<PathKind>(
          segments: <ButtonSegment<PathKind>>[
            for (final PathKind k in PathKind.values)
              ButtonSegment<PathKind>(
                value: k,
                icon: Icon(pathKindIcon(k)),
                label: Text(pathKindLabel(k, l)),
              ),
          ],
          selected: <PathKind>{_kind},
          onSelectionChanged: (Set<PathKind> s) =>
              setState(() => _kind = s.first),
        ),
        const SizedBox(height: AppSpacing.md),
        TextField(
          controller: _name,
          autofocus: widget.existing == null && widget.initialName.isEmpty,
          textCapitalization: TextCapitalization.sentences,
          onChanged: (_) => setState(() {}),
          decoration: InputDecoration(
            labelText: l.name,
            hintText: l.pathNameHint,
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        TextField(
          controller: _description,
          minLines: 1,
          maxLines: 4,
          textCapitalization: TextCapitalization.sentences,
          decoration: InputDecoration(labelText: l.description),
        ),
        const SizedBox(height: AppSpacing.md),
        JournalSheetActions(
          saveLabel: widget.existing == null ? l.pathCreate : l.save,
          cancelLabel: l.cancel,
          onSave: _name.text.trim().isEmpty ? null : _save,
        ),
      ],
    );
  }
}

class _StopForm extends StatefulWidget {
  const _StopForm({required this.entry});

  final PathEntry entry;

  @override
  State<_StopForm> createState() => _StopFormState();
}

class _StopFormState extends State<_StopForm> {
  late bool _optional = widget.entry.optional;
  late bool _spoiler = widget.entry.spoiler;
  late PathAspect? _aspect = widget.entry.aspect;
  late final TextEditingController _note = TextEditingController(
    text: widget.entry.note ?? '',
  );

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  void _save() {
    final String note = _note.text.trim();
    final PathAspect? aspect = _aspect;
    Navigator.of(context).pop<StopEditResult>(
      StopSaved(
        widget.entry.copyWith(
          optional: _optional,
          spoiler: _spoiler,
          note: note.isEmpty ? null : note,
          clearNote: note.isEmpty,
          aspect: aspect,
          clearAspect: aspect == null,
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
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(l.pathOptional),
          subtitle: Text(l.pathOptionalHint),
          value: _optional,
          onChanged: (bool v) => setState(() => _optional = v),
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(l.pathSpoiler),
          subtitle: Text(l.pathSpoilerHint),
          value: _spoiler,
          onChanged: (bool v) => setState(() => _spoiler = v),
        ),
        const SizedBox(height: AppSpacing.sm),
        DropdownButtonFormField<PathAspect?>(
          initialValue: _aspect,
          decoration: InputDecoration(labelText: l.pathAspect),
          items: <DropdownMenuItem<PathAspect?>>[
            DropdownMenuItem<PathAspect?>(child: Text(l.pathAspectNone)),
            for (final PathAspect a in PathAspect.values)
              DropdownMenuItem<PathAspect?>(
                value: a,
                child: Text(aspectLabel(a, l)),
              ),
          ],
          onChanged: (PathAspect? a) => setState(() => _aspect = a),
        ),
        const SizedBox(height: AppSpacing.sm),
        TextField(
          controller: _note,
          minLines: 1,
          maxLines: 3,
          textCapitalization: TextCapitalization.sentences,
          decoration: InputDecoration(
            labelText: l.pathNote,
            hintText: l.pathNoteHint,
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        JournalSheetActions(
          saveLabel: l.save,
          cancelLabel: l.cancel,
          onSave: _save,
          deleteLabel: l.pathRemoveStop,
          onDelete: () =>
              Navigator.of(context).pop<StopEditResult>(const StopRemoved()),
        ),
      ],
    );
  }
}
