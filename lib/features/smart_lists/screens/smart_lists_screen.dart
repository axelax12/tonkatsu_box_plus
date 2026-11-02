import 'package:core/models/collection_item.dart';
import 'package:core/plus/models/smart_list.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/app_localizations.dart';
import '../../../shared/constants/media_type_theme.dart';
import '../../../shared/extensions/snackbar_extension.dart';
import '../../../shared/theme/app_colors.dart';
import '../../../shared/theme/app_spacing.dart';
import '../../../shared/theme/app_typography.dart';
import '../../../shared/widgets/media_detail/media_cover_image.dart';
import '../providers/smart_list_providers.dart';
import '../smart_list_templates.dart';
import 'smart_list_editor_screen.dart';
import 'smart_list_screen.dart';

/// Every saved smart list with its live count, plus one-tap templates.
class SmartListsScreen extends ConsumerWidget {
  const SmartListsScreen({super.key});

  Future<void> _addTemplate(
    BuildContext context,
    WidgetRef ref,
    SmartListTemplate template,
  ) async {
    final S l = S.of(context);
    final DateTime now = DateTime.now();
    await ref
        .read(smartListControllerProvider)
        .save(
          SmartList(
            id: 0,
            name: template.name,
            rules: template.rules,
            createdAt: now,
            updatedAt: now,
          ),
        );
    if (context.mounted) {
      context.showSnack(l.smartAdded(template.name), type: SnackType.success);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final S l = S.of(context);
    final List<SmartList> lists =
        ref.watch(smartListsProvider).valueOrNull ?? const <SmartList>[];
    final Set<String> taken = <String>{for (final SmartList s in lists) s.name};
    final List<SmartListTemplate> templates = smartListTemplates(
      l,
    ).where((SmartListTemplate t) => !taken.contains(t.name)).toList();

    return ListView(
      padding: const EdgeInsets.all(AppSpacing.md),
      children: <Widget>[
        for (final SmartList list in lists)
          Padding(
            key: ValueKey<int>(list.id),
            padding: const EdgeInsets.only(bottom: AppSpacing.sm),
            child: _SmartListTile(list: list),
          ),
        if (lists.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
            child: Text(
              l.smartNoneYet,
              textAlign: TextAlign.center,
              style: AppTypography.body.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ),
        FilledButton.icon(
          onPressed: () => Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (BuildContext _) => const SmartListEditorScreen(),
            ),
          ),
          icon: const Icon(Icons.add),
          label: Text(l.smartNew),
        ),
        if (templates.isNotEmpty) ...<Widget>[
          const SizedBox(height: AppSpacing.lg),
          Text(l.smartTemplates, style: AppTypography.h3),
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: <Widget>[
              for (final SmartListTemplate t in templates)
                ActionChip(
                  key: ValueKey<String>(t.name),
                  avatar: const Icon(Icons.add, size: 18),
                  label: Text(t.name),
                  onPressed: () => _addTemplate(context, ref, t),
                ),
            ],
          ),
        ],
      ],
    );
  }
}

class _SmartListTile extends ConsumerWidget {
  const _SmartListTile({required this.list});

  final SmartList list;

  static const int _previewCovers = 4;
  static const double _coverWidth = 36;
  static const double _coverHeight = 54;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final S l = S.of(context);
    final List<CollectionItem>? items = ref
        .watch(smartListItemsProvider(list.id))
        .valueOrNull;

    return Material(
      color: AppColors.surfaceLight,
      borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (BuildContext _) => SmartListScreen(listId: list.id),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Row(
            children: <Widget>[
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      list.name,
                      style: AppTypography.body.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      items == null ? '…' : l.smartMatches(items.length),
                      style: AppTypography.caption.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              for (final CollectionItem item
                  in (items ?? const <CollectionItem>[]).take(_previewCovers))
                Padding(
                  key: ValueKey<int>(item.id),
                  padding: const EdgeInsets.only(left: AppSpacing.xs),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(AppSpacing.radiusXs),
                    child: SizedBox(
                      width: _coverWidth,
                      height: _coverHeight,
                      child: MediaCoverImage(
                        coverUrl: item.thumbnailUrl ?? item.coverUrl,
                        placeholderIcon: MediaTypeTheme.placeholderIconFor(
                          item.mediaType,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
