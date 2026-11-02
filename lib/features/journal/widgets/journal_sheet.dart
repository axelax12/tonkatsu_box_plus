import 'package:flutter/material.dart';

import '../../../shared/theme/app_colors.dart';
import '../../../shared/theme/app_spacing.dart';
import '../../../shared/theme/app_typography.dart';

/// Every journal form is a scrollable bottom sheet that lifts above the
/// keyboard, so a long note never hides its own Save button on a phone.
Future<T?> showJournalSheet<T>(
  BuildContext context, {
  required String title,
  required WidgetBuilder builder,
}) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: AppColors.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(
        top: Radius.circular(AppSpacing.radiusLg),
      ),
    ),
    builder: (BuildContext sheetContext) => Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.viewInsetsOf(sheetContext).bottom,
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.md,
          AppSpacing.md,
          AppSpacing.md,
          AppSpacing.lg,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Text(
              title,
              style: AppTypography.h3.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: AppSpacing.md),
            builder(sheetContext),
          ],
        ),
      ),
    ),
  );
}

/// The Save / Cancel row at the bottom of a journal sheet.
class JournalSheetActions extends StatelessWidget {
  const JournalSheetActions({
    required this.saveLabel,
    required this.cancelLabel,
    required this.onSave,
    this.onDelete,
    this.deleteLabel,
    super.key,
  });

  final String saveLabel;
  final String cancelLabel;
  final VoidCallback? onSave;
  final VoidCallback? onDelete;
  final String? deleteLabel;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        if (onDelete != null && deleteLabel != null)
          TextButton(
            onPressed: onDelete,
            style: TextButton.styleFrom(
              foregroundColor: AppColors.error,
              minimumSize: const Size(0, AppSpacing.buttonHeightCompact),
            ),
            child: Text(deleteLabel ?? ''),
          ),
        const Spacer(),
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          style: TextButton.styleFrom(
            minimumSize: const Size(0, AppSpacing.buttonHeightCompact),
          ),
          child: Text(cancelLabel),
        ),
        const SizedBox(width: AppSpacing.sm),
        FilledButton(
          onPressed: onSave,
          style: FilledButton.styleFrom(
            minimumSize: const Size(0, AppSpacing.buttonHeightCompact),
          ),
          child: Text(saveLabel),
        ),
      ],
    );
  }
}
