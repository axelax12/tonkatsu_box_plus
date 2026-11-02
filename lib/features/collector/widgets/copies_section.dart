import 'package:core/plus/models/owned_copy.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/app_localizations.dart';
import '../../../shared/theme/app_colors.dart';
import '../../../shared/theme/app_spacing.dart';
import '../../../shared/theme/app_typography.dart';
import '../../../shared/widgets/confirm_dialog.dart';
import '../../notifications/plus_notifications.dart';
import '../collector_format.dart';
import '../providers/collector_providers.dart';
import 'copy_sheets.dart';

/// "My copies" on an item page: editions owned, what they cost, who has them.
class CopiesSection extends ConsumerWidget {
  const CopiesSection({
    required this.itemId,
    required this.accentColor,
    required this.isEditable,
    this.itemName,
    super.key,
  });

  final int itemId;

  /// Named in the loan reminder.
  final String? itemName;
  final Color accentColor;
  final bool isEditable;

  Future<void> _edit(
    BuildContext context,
    WidgetRef ref, {
    OwnedCopy? existing,
  }) async {
    final S l = S.of(context);
    final CopyEditResult? result = await showCopyEditorSheet(
      context,
      itemId: itemId,
      existing: existing,
    );
    if (result == null || !context.mounted) return;
    final CopiesController controller = ref.read(copiesControllerProvider);
    switch (result) {
      case CopySaved(:final OwnedCopy copy):
        await controller.save(copy);
      case CopyDeleted():
        final OwnedCopy? target = existing;
        if (target == null) return;
        final bool confirmed = await ConfirmDialog.show(
          context,
          title: l.delete,
          message: l.copyDeleteConfirm,
          confirmLabel: l.delete,
        );
        if (confirmed) {
          await controller.delete(target);
          await PlusNotifications.instance.cancelLoanReminder(target.id);
        }
    }
  }

  Future<void> _lendOrReturn(
    BuildContext context,
    WidgetRef ref,
    OwnedCopy copy,
  ) async {
    final S l = S.of(context);
    final CopiesController controller = ref.read(copiesControllerProvider);
    if (copy.isLoaned) {
      await controller.markReturned(copy);
      await PlusNotifications.instance.cancelLoanReminder(copy.id);
      return;
    }
    final LoanInput? loan = await showLendSheet(context);
    if (loan == null) return;
    await controller.lend(copy, to: loan.to, dueAt: loan.dueAt);
    final DateTime? due = loan.dueAt;
    if (due != null) {
      await PlusNotifications.instance.scheduleLoanReminder(
        copyId: copy.id,
        title: l.loanReminderTitle(itemName ?? l.copiesTitle),
        body: l.loanReminderBody(loan.to),
        dueAt: due,
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final S l = S.of(context);
    final List<OwnedCopy> copies =
        ref.watch(itemCopiesProvider(itemId)).valueOrNull ??
        const <OwnedCopy>[];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Row(
          children: <Widget>[
            Icon(Icons.shelves, size: 20, color: accentColor),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Text(
                l.copiesTitle,
                style: AppTypography.h3.copyWith(fontWeight: FontWeight.w600),
              ),
            ),
            if (isEditable)
              TextButton.icon(
                onPressed: () => _edit(context, ref),
                icon: const Icon(Icons.add, size: 18),
                label: Text(l.copyAdd),
                style: TextButton.styleFrom(
                  foregroundColor: accentColor,
                  minimumSize: const Size(0, AppSpacing.buttonHeightCompact),
                ),
              ),
          ],
        ),
        if (copies.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
            child: Text(
              l.copiesNone,
              style: AppTypography.bodySmall.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          )
        else
          for (final OwnedCopy copy in copies)
            _CopyTile(
              key: ValueKey<int>(copy.id),
              copy: copy,
              accentColor: accentColor,
              onTap: isEditable
                  ? () => _edit(context, ref, existing: copy)
                  : null,
              onLoan: isEditable
                  ? () => _lendOrReturn(context, ref, copy)
                  : null,
            ),
      ],
    );
  }
}

class _CopyTile extends StatelessWidget {
  const _CopyTile({
    required this.copy,
    required this.accentColor,
    this.onTap,
    this.onLoan,
    super.key,
  });

  final OwnedCopy copy;
  final Color accentColor;
  final VoidCallback? onTap;
  final VoidCallback? onLoan;

  @override
  Widget build(BuildContext context) {
    final S l = S.of(context);
    final MaterialLocalizations material = MaterialLocalizations.of(context);
    final DateTime now = DateTime.now();
    final double? price = copy.pricePaid;
    final CopyCondition? condition = copy.condition;
    final String? edition = copy.edition;
    final DateTime? due = copy.loanDueAt;
    final String details = <String>[
      copyFormatLabel(copy.format, l),
      ?edition,
      if (condition != null) copyConditionLabel(condition, l),
      if (price != null) formatPrice(price, copy.currency),
    ].join(' · ');
    final bool overdue = copy.isOverdue(now);

    return InkWell(
      borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
        child: Row(
          children: <Widget>[
            Icon(copyFormatIcon(copy.format), color: accentColor, size: 20),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(details, style: AppTypography.body),
                  if (copy.isLoaned)
                    Text(
                      <String>[
                        l.copyLentChip(copy.loanedTo ?? ''),
                        if (due != null)
                          l.loanDue(material.formatMediumDate(due)),
                        if (overdue) l.copyOverdue,
                      ].join(' · '),
                      style: AppTypography.caption.copyWith(
                        color: overdue ? AppColors.error : AppColors.warning,
                      ),
                    ),
                ],
              ),
            ),
            if (onLoan != null)
              IconButton(
                tooltip: copy.isLoaned ? l.copyReturned : l.copyLend,
                onPressed: onLoan,
                icon: Icon(
                  copy.isLoaned
                      ? Icons.assignment_return_outlined
                      : Icons.handshake_outlined,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
