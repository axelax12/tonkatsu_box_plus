import 'package:core/models/collection_item.dart';
import 'package:core/models/data_source.dart';
import 'package:core/models/item_status.dart';
import 'package:core/models/media_type.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logging/logging.dart';

import '../../core/database/database_service.dart';
import '../../l10n/app_localizations.dart';
import '../../shared/constants/item_status_ui.dart';
import '../../shared/theme/app_colors.dart';
import '../../shared/theme/app_spacing.dart';
import '../../shared/theme/app_typography.dart';
import '../collections/providers/collections_provider.dart';
import '../settings/providers/settings_provider.dart';

final Logger _log = Logger('QuickStatus');

/// The status a freshly added work lands in; "not started" keeps the
/// upstream behaviour, anything else is applied right after the add.
class NewItemStatusNotifier extends Notifier<ItemStatus> {
  static const String prefsKey = 'plus_new_item_status';

  @override
  ItemStatus build() {
    final String? stored = ref
        .read(sharedPreferencesProvider)
        .getString(prefsKey);
    return quickStatuses
            .where((ItemStatus s) => s.value == stored)
            .firstOrNull ??
        ItemStatus.notStarted;
  }

  Future<void> select(ItemStatus status) async {
    state = status;
    await ref.read(sharedPreferencesProvider).setString(prefsKey, status.value);
  }
}

final NotifierProvider<NewItemStatusNotifier, ItemStatus>
newItemStatusProvider = NotifierProvider<NewItemStatusNotifier, ItemStatus>(
  NewItemStatusNotifier.new,
);

/// The handful that make sense at the moment of adding.
const List<ItemStatus> quickStatuses = <ItemStatus>[
  ItemStatus.notStarted,
  ItemStatus.planned,
  ItemStatus.inProgress,
  ItemStatus.completed,
];

typedef AddedItem = ({
  int? collectionId,
  MediaType mediaType,
  int externalId,
  int? platformId,
  DataSource? source,
});

Future<void> _setStatus(
  WidgetRef ref,
  AddedItem added,
  ItemStatus status,
) async {
  try {
    final CollectionItem? item = await ref
        .read(databaseServiceProvider)
        .collectionDao
        .findCollectionItem(
          collectionId: added.collectionId,
          mediaType: added.mediaType,
          externalId: added.externalId,
          platformId: added.platformId,
          source: added.source,
        );
    if (item == null || item.status == status) return;
    await ref
        .read(collectionItemsNotifierProvider(added.collectionId).notifier)
        .updateStatus(item.id, status, item.mediaType);
  } on Exception catch (e, stack) {
    _log.warning('Could not set the status of a new item', e, stack);
  }
}

/// Applies the user's default to a work that was just added.
Future<void> applyNewItemStatus(WidgetRef ref, AddedItem added) async {
  final ItemStatus status = ref.read(newItemStatusProvider);
  if (status == ItemStatus.notStarted) return;
  await _setStatus(ref, added, status);
}

/// One tap to fix the status of what was just added, and to make it the
/// default for the next ones.
Future<void> showQuickStatusSheet(
  BuildContext context,
  WidgetRef ref,
  AddedItem added,
) {
  return showModalBottomSheet<void>(
    context: context,
    useSafeArea: true,
    backgroundColor: AppColors.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(
        top: Radius.circular(AppSpacing.radiusLg),
      ),
    ),
    builder: (BuildContext _) => _QuickStatusSheet(added: added),
  );
}

class _QuickStatusSheet extends ConsumerStatefulWidget {
  const _QuickStatusSheet({required this.added});

  final AddedItem added;

  @override
  ConsumerState<_QuickStatusSheet> createState() => _QuickStatusSheetState();
}

class _QuickStatusSheetState extends ConsumerState<_QuickStatusSheet> {
  bool _remember = false;

  Future<void> _pick(ItemStatus status) async {
    final NavigatorState navigator = Navigator.of(context);
    if (_remember) {
      await ref.read(newItemStatusProvider.notifier).select(status);
    }
    await _setStatus(ref, widget.added, status);
    navigator.pop();
  }

  @override
  Widget build(BuildContext context) {
    final S l = S.of(context);
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text(
            l.quickStatusTitle,
            style: AppTypography.h3.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: AppSpacing.md),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: <Widget>[
              for (final ItemStatus s in quickStatuses)
                ActionChip(
                  key: ValueKey<ItemStatus>(s),
                  avatar: Icon(s.materialIcon, size: 18, color: s.color),
                  label: Text(s.localizedLabel(l, widget.added.mediaType)),
                  onPressed: () => _pick(s),
                ),
            ],
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(l.quickStatusRemember),
            value: _remember,
            onChanged: (bool v) => setState(() => _remember = v),
          ),
        ],
      ),
    );
  }
}
