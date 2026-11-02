import 'package:core/plus/analytics/path_exchange.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../l10n/app_localizations.dart';
import '../../../shared/theme/app_colors.dart';
import '../../../shared/theme/app_spacing.dart';
import '../../../shared/theme/app_typography.dart';

/// Asks for a shared path's text; returns it decoded, or null on cancel.
Future<SharedPath?> showPathImportDialog(BuildContext context) {
  return showDialog<SharedPath>(
    context: context,
    builder: (BuildContext _) => const _PathImportDialog(),
  );
}

class _PathImportDialog extends StatefulWidget {
  const _PathImportDialog();

  @override
  State<_PathImportDialog> createState() => _PathImportDialogState();
}

class _PathImportDialogState extends State<_PathImportDialog> {
  final TextEditingController _text = TextEditingController();
  bool _invalid = false;

  static const int _visibleLines = 4;

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  Future<void> _paste() async {
    final ClipboardData? data = await Clipboard.getData(Clipboard.kTextPlain);
    final String? text = data?.text;
    if (text == null || !mounted) return;
    setState(() {
      _text.text = text;
      _invalid = false;
    });
  }

  void _submit() {
    try {
      Navigator.of(context).pop(PathExchange.decode(_text.text));
    } on PathExchangeException {
      setState(() => _invalid = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final S l = S.of(context);
    return AlertDialog(
      title: Text(l.pathImport),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            TextField(
              controller: _text,
              minLines: _visibleLines,
              maxLines: _visibleLines,
              onChanged: (_) => setState(() => _invalid = false),
              decoration: InputDecoration(hintText: l.pathImportHint),
            ),
            if (_invalid) ...<Widget>[
              const SizedBox(height: AppSpacing.sm),
              Text(
                l.pathImportInvalid,
                style: AppTypography.caption.copyWith(color: AppColors.error),
              ),
            ],
            const SizedBox(height: AppSpacing.sm),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: _paste,
                icon: const Icon(Icons.content_paste),
                label: Text(l.pathImportPaste),
                style: TextButton.styleFrom(
                  minimumSize: const Size(0, AppSpacing.buttonHeightDense),
                ),
              ),
            ),
          ],
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l.cancel),
        ),
        TextButton(
          onPressed: _text.text.trim().isEmpty ? null : _submit,
          child: Text(l.pathImport),
        ),
      ],
    );
  }
}
