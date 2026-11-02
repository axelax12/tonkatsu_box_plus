import 'package:core/plus/models/owned_copy.dart';
import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';
import '../../../shared/theme/app_spacing.dart';
import '../../journal/widgets/journal_sheet.dart';
import '../collector_format.dart';

sealed class CopyEditResult {
  const CopyEditResult();
}

class CopySaved extends CopyEditResult {
  const CopySaved(this.copy);

  final OwnedCopy copy;
}

class CopyDeleted extends CopyEditResult {
  const CopyDeleted();
}

typedef LoanInput = ({String to, DateTime? dueAt});

Future<CopyEditResult?> showCopyEditorSheet(
  BuildContext context, {
  required int itemId,
  OwnedCopy? existing,
}) {
  final S l = S.of(context);
  return showJournalSheet<CopyEditResult>(
    context,
    title: existing == null ? l.copyAdd : l.copyEdit,
    builder: (BuildContext _) => _CopyForm(itemId: itemId, existing: existing),
  );
}

Future<LoanInput?> showLendSheet(BuildContext context) {
  final S l = S.of(context);
  return showJournalSheet<LoanInput>(
    context,
    title: l.copyLend,
    builder: (BuildContext _) => const _LendForm(),
  );
}

class _CopyForm extends StatefulWidget {
  const _CopyForm({required this.itemId, this.existing});

  final int itemId;
  final OwnedCopy? existing;

  @override
  State<_CopyForm> createState() => _CopyFormState();
}

class _CopyFormState extends State<_CopyForm> {
  late CopyFormat _format = widget.existing?.format ?? CopyFormat.physical;
  late CopyCondition? _condition = widget.existing?.condition;
  late DateTime? _purchasedAt = widget.existing?.purchasedAt;
  late final TextEditingController _edition = TextEditingController(
    text: widget.existing?.edition ?? '',
  );
  late final TextEditingController _price = TextEditingController(
    text: widget.existing?.pricePaid?.toStringAsFixed(2) ?? '',
  );
  late final TextEditingController _currency = TextEditingController(
    text: widget.existing?.currency ?? '',
  );
  late final TextEditingController _store = TextEditingController(
    text: widget.existing?.store ?? '',
  );
  late final TextEditingController _notes = TextEditingController(
    text: widget.existing?.notes ?? '',
  );

  @override
  void dispose() {
    for (final TextEditingController c in <TextEditingController>[
      _edition,
      _price,
      _currency,
      _store,
      _notes,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  static String? _clean(String text) {
    final String trimmed = text.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  Future<void> _pickPurchase() async {
    final DateTime now = DateTime.now();
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _purchasedAt ?? now,
      firstDate: DateTime(1970),
      lastDate: now,
    );
    if (picked != null && mounted) setState(() => _purchasedAt = picked);
  }

  void _save() {
    final DateTime now = DateTime.now();
    final double? price = double.tryParse(
      _price.text.trim().replaceAll(',', '.'),
    );
    final OwnedCopy base =
        widget.existing ??
        OwnedCopy(
          id: 0,
          itemId: widget.itemId,
          format: _format,
          createdAt: now,
          updatedAt: now,
        );
    final String? edition = _clean(_edition.text);
    final String? currency = _clean(_currency.text);
    final String? store = _clean(_store.text);
    final String? notes = _clean(_notes.text);
    Navigator.of(context).pop<CopyEditResult>(
      CopySaved(
        base.copyWith(
          format: _format,
          edition: edition,
          clearEdition: edition == null,
          condition: _condition,
          clearCondition: _condition == null,
          pricePaid: price,
          clearPrice: price == null,
          currency: currency,
          clearCurrency: currency == null,
          purchasedAt: _purchasedAt,
          clearPurchasedAt: _purchasedAt == null,
          store: store,
          clearStore: store == null,
          notes: notes,
          clearNotes: notes == null,
          updatedAt: now,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final S l = S.of(context);
    final MaterialLocalizations material = MaterialLocalizations.of(context);
    final DateTime? purchased = _purchasedAt;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        SegmentedButton<CopyFormat>(
          segments: <ButtonSegment<CopyFormat>>[
            for (final CopyFormat f in CopyFormat.values)
              ButtonSegment<CopyFormat>(
                value: f,
                icon: Icon(copyFormatIcon(f)),
                label: Text(copyFormatLabel(f, l)),
              ),
          ],
          selected: <CopyFormat>{_format},
          onSelectionChanged: (Set<CopyFormat> s) =>
              setState(() => _format = s.first),
        ),
        const SizedBox(height: AppSpacing.md),
        TextField(
          controller: _edition,
          textCapitalization: TextCapitalization.sentences,
          decoration: InputDecoration(labelText: l.copyEdition),
        ),
        const SizedBox(height: AppSpacing.sm),
        DropdownButtonFormField<CopyCondition?>(
          initialValue: _condition,
          decoration: InputDecoration(labelText: l.copyCondition),
          items: <DropdownMenuItem<CopyCondition?>>[
            DropdownMenuItem<CopyCondition?>(child: Text(l.copyNoCondition)),
            for (final CopyCondition c in CopyCondition.values)
              DropdownMenuItem<CopyCondition?>(
                value: c,
                child: Text(copyConditionLabel(c, l)),
              ),
          ],
          onChanged: (CopyCondition? c) => setState(() => _condition = c),
        ),
        const SizedBox(height: AppSpacing.sm),
        Row(
          children: <Widget>[
            Expanded(
              flex: 2,
              child: TextField(
                controller: _price,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: InputDecoration(labelText: l.copyPrice),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: TextField(
                controller: _currency,
                textCapitalization: TextCapitalization.characters,
                decoration: InputDecoration(labelText: l.copyCurrency),
              ),
            ),
          ],
        ),
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.event_outlined),
          title: Text(l.copyPurchased),
          subtitle: Text(
            purchased == null
                ? l.journalNotSet
                : material.formatMediumDate(purchased),
          ),
          onTap: _pickPurchase,
        ),
        TextField(
          controller: _store,
          textCapitalization: TextCapitalization.sentences,
          decoration: InputDecoration(labelText: l.copyStore),
        ),
        const SizedBox(height: AppSpacing.sm),
        TextField(
          controller: _notes,
          minLines: 1,
          maxLines: 4,
          textCapitalization: TextCapitalization.sentences,
          decoration: InputDecoration(labelText: l.copyNotes),
        ),
        const SizedBox(height: AppSpacing.md),
        JournalSheetActions(
          saveLabel: l.save,
          cancelLabel: l.cancel,
          onSave: _save,
          deleteLabel: l.delete,
          onDelete: widget.existing == null
              ? null
              : () => Navigator.of(
                  context,
                ).pop<CopyEditResult>(const CopyDeleted()),
        ),
      ],
    );
  }
}

class _LendForm extends StatefulWidget {
  const _LendForm();

  @override
  State<_LendForm> createState() => _LendFormState();
}

class _LendFormState extends State<_LendForm> {
  static const Duration _defaultLoan = Duration(days: 14);

  final TextEditingController _to = TextEditingController();
  DateTime? _due = DateTime.now().add(_defaultLoan);

  @override
  void initState() {
    super.initState();
    _to.addListener(_onChanged);
  }

  @override
  void dispose() {
    _to.removeListener(_onChanged);
    _to.dispose();
    super.dispose();
  }

  void _onChanged() => setState(() {});

  Future<void> _pickDue() async {
    final DateTime now = DateTime.now();
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _due ?? now.add(_defaultLoan),
      firstDate: now,
      lastDate: DateTime(now.year + 5),
    );
    if (picked != null && mounted) setState(() => _due = picked);
  }

  @override
  Widget build(BuildContext context) {
    final S l = S.of(context);
    final MaterialLocalizations material = MaterialLocalizations.of(context);
    final DateTime? due = _due;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        TextField(
          controller: _to,
          autofocus: true,
          textCapitalization: TextCapitalization.words,
          decoration: InputDecoration(
            labelText: l.copyLendTo,
            prefixIcon: const Icon(Icons.person_outline),
          ),
        ),
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.event_outlined),
          title: Text(l.copyDue),
          subtitle: Text(
            due == null ? l.copyNoDue : material.formatMediumDate(due),
          ),
          trailing: due == null
              ? null
              : IconButton(
                  tooltip: l.copyNoDue,
                  icon: const Icon(Icons.close),
                  onPressed: () => setState(() => _due = null),
                ),
          onTap: _pickDue,
        ),
        const SizedBox(height: AppSpacing.sm),
        JournalSheetActions(
          saveLabel: l.copyLend,
          cancelLabel: l.cancel,
          onSave: _to.text.trim().isEmpty
              ? null
              : () => Navigator.of(
                  context,
                ).pop<LoanInput>((to: _to.text.trim(), dueAt: _due)),
        ),
      ],
    );
  }
}
