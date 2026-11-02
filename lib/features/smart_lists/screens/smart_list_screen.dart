import 'package:core/models/collection_item.dart';
import 'package:core/plus/models/smart_list.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/app_localizations.dart';
import '../../../shared/theme/app_colors.dart';
import '../../../shared/theme/app_spacing.dart';
import '../../../shared/theme/app_typography.dart';
import '../../../shared/widgets/confirm_dialog.dart';
import '../providers/smart_list_providers.dart';
import '../widgets/item_cover_grid.dart';
import 'smart_list_editor_screen.dart';

/// One smart list's live result.
class SmartListScreen extends ConsumerWidget {
  const SmartListScreen({required this.listId, super.key});

  final int listId;

  Future<void> _delete(
    BuildContext context,
    WidgetRef ref,
    SmartList list,
  ) async {
    final S l = S.of(context);
    final bool confirmed = await ConfirmDialog.show(
      context,
      title: l.delete,
      message: l.smartDeleteConfirm(list.name),
      confirmLabel: l.delete,
    );
    if (!confirmed || !context.mounted) return;
    await ref.read(smartListControllerProvider).delete(list);
    if (context.mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final S l = S.of(context);
    final SmartList? list = ref
        .watch(smartListsProvider)
        .valueOrNull
        ?.where((SmartList s) => s.id == listId)
        .firstOrNull;
    final AsyncValue<List<CollectionItem>> items = ref.watch(
      smartListItemsProvider(listId),
    );

    return Scaffold(
      appBar: AppBar(
        title: Text(list?.name ?? ''),
        actions: <Widget>[
          if (list != null) ...<Widget>[
            IconButton(
              tooltip: l.edit,
              icon: const Icon(Icons.tune),
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (BuildContext _) =>
                      SmartListEditorScreen(existing: list),
                ),
              ),
            ),
            IconButton(
              tooltip: l.delete,
              icon: const Icon(Icons.delete_outline),
              onPressed: () => _delete(context, ref, list),
            ),
          ],
        ],
      ),
      body: items.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (Object e, StackTrace _) => Center(child: Text('$e')),
        data: (List<CollectionItem> found) => found.isEmpty
            ? Center(
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.xl),
                  child: Text(
                    l.smartEmpty,
                    textAlign: TextAlign.center,
                    style: AppTypography.body.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
              )
            : ItemCoverGrid(
                items: found,
                header: Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.md,
                    AppSpacing.md,
                    AppSpacing.md,
                    0,
                  ),
                  child: Text(
                    l.smartMatches(found.length),
                    style: AppTypography.bodySmall.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
              ),
      ),
    );
  }
}
