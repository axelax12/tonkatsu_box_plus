import 'package:core/models/collection_item.dart';
import 'package:core/plus/analytics/path_walk.dart';
import 'package:core/plus/analytics/theme_index.dart';
import 'package:core/plus/models/item_aspect.dart';
import 'package:core/plus/models/media_path.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/app_localizations.dart';
import '../../../shared/extensions/snackbar_extension.dart';
import '../../../shared/theme/app_colors.dart';
import '../../../shared/theme/app_spacing.dart';
import '../../../shared/theme/app_typography.dart';
import '../../journal/widgets/journal_sheet.dart';
import '../paths_format.dart';
import '../providers/paths_providers.dart';
import '../screens/path_screen.dart';
import 'path_sheets.dart';

/// On an item page: the paths it sits on, what comes after it, and its tags.
class PathsSection extends ConsumerWidget {
  const PathsSection({
    required this.item,
    required this.accentColor,
    required this.isEditable,
    super.key,
  });

  final CollectionItem item;
  final Color accentColor;
  final bool isEditable;

  Future<void> _addToPath(BuildContext context, WidgetRef ref) async {
    final S l = S.of(context);
    final List<MediaPath> all = await ref.read(pathsProvider.future);
    final Set<int> current = <int>{
      for (final ItemPathView v
          in ref.read(itemPathsProvider(item.id)).valueOrNull ??
              const <ItemPathView>[])
        v.path.id,
    };
    if (!context.mounted) return;
    // A null path inside the record means "create a new one".
    final ({MediaPath? path})? chosen = await showJournalSheet<({MediaPath? path})>(
      context,
      title: l.pathAddToPath,
      builder: (BuildContext sheetContext) => _PathChoice(
        paths: <MediaPath>[
          for (final MediaPath p in all)
            if (!current.contains(p.id)) p,
        ],
      ),
    );
    if (chosen == null || !context.mounted) return;
    final PathsController controller = ref.read(pathsControllerProvider);
    MediaPath? target = chosen.path;
    if (target == null) {
      final PathDraft? draft = await showPathEditorSheet(context);
      if (draft == null) return;
      target = await controller.create(
        name: draft.name,
        kind: draft.kind,
        description: draft.description,
        items: <CollectionItem>[item],
      );
    } else {
      await controller.addItems(target.id, <CollectionItem>[item]);
    }
    if (context.mounted) {
      context.showSnack(l.pathAdded(target.name), type: SnackType.success);
    }
  }

  Future<void> _addTag(BuildContext context, WidgetRef ref) async {
    final S l = S.of(context);
    final List<ItemAspectTag> known = await ref.read(
      allAspectTagsProvider.future,
    );
    if (!context.mounted) return;
    final ({PathAspect aspect, String label})? input =
        await showJournalSheet<({PathAspect aspect, String label})>(
          context,
          title: l.aspectAddTag,
          builder: (BuildContext _) => _TagForm(known: known),
        );
    if (input == null) return;
    final bool added = await ref
        .read(pathsControllerProvider)
        .addTag(item.id, input.aspect, input.label);
    if (!added && context.mounted) context.showSnack(l.aspectTagExists);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final S l = S.of(context);
    final List<ItemPathView> paths =
        ref.watch(itemPathsProvider(item.id)).valueOrNull ??
        const <ItemPathView>[];
    final List<ItemAspectTag> tags =
        ref.watch(itemAspectTagsProvider(item.id)).valueOrNull ??
        const <ItemAspectTag>[];
    final Set<BuiltInTheme> derived = ThemeIndex.themesFor(
      item.genres ?? const <String>[],
    );
    if (!isEditable && paths.isEmpty && tags.isEmpty && derived.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Row(
          children: <Widget>[
            Icon(Icons.route_outlined, size: 20, color: accentColor),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Text(
                l.pathsSectionTitle,
                style: AppTypography.h3.copyWith(fontWeight: FontWeight.w600),
              ),
            ),
            if (isEditable)
              TextButton.icon(
                onPressed: () => _addToPath(context, ref),
                icon: const Icon(Icons.add, size: 18),
                label: Text(l.pathAddToPath),
                style: TextButton.styleFrom(
                  foregroundColor: accentColor,
                  minimumSize: const Size(0, AppSpacing.buttonHeightCompact),
                ),
              ),
          ],
        ),
        for (final ItemPathView view in paths)
          _PathLine(
            key: ValueKey<int>(view.path.id),
            view: view,
            itemId: item.id,
            accentColor: accentColor,
          ),
        const SizedBox(height: AppSpacing.xs),
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.xs,
          children: <Widget>[
            for (final BuiltInTheme t in derived)
              Chip(
                key: ValueKey<String>('b-${t.name}'),
                avatar: Icon(aspectIcon(t.aspect), size: 16),
                label: Text(builtInThemeLabel(t, l)),
                visualDensity: VisualDensity.compact,
              ),
            for (final ItemAspectTag tag in tags)
              InputChip(
                key: ValueKey<int>(tag.id),
                avatar: Icon(aspectIcon(tag.aspect), size: 16),
                label: Text(tag.label),
                visualDensity: VisualDensity.compact,
                onDeleted: isEditable
                    ? () => ref.read(pathsControllerProvider).removeTag(tag)
                    : null,
              ),
            if (isEditable)
              ActionChip(
                avatar: const Icon(Icons.add, size: 16),
                label: Text(l.aspectAddTag),
                visualDensity: VisualDensity.compact,
                onPressed: () => _addTag(context, ref),
              ),
          ],
        ),
      ],
    );
  }
}

class _PathLine extends StatelessWidget {
  const _PathLine({
    required this.view,
    required this.itemId,
    required this.accentColor,
    super.key,
  });

  final ItemPathView view;
  final int itemId;
  final Color accentColor;

  @override
  Widget build(BuildContext context) {
    final S l = S.of(context);
    final PathWalk walk = view.walk;
    final int index = walk.indexOfItem(itemId);
    final PathStop? current = walk.current;
    final bool showNext =
        current != null && current.entry.itemId != itemId && !current.hidden;
    final String? nextName = showNext ? current.item?.itemName : null;
    final String? progress = walk.isComplete
        ? l.pathCompleted
        : nextName == null
        ? null
        : l.pathsSectionNext(nextName);
    final List<String> parts = <String>[
      if (index >= 0) l.pathsSectionStop(index + 1, walk.stops.length),
      ?progress,
    ];
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(pathKindIcon(view.path.kind), color: accentColor),
      title: Text(view.path.name),
      subtitle: Text(
        parts.join(' · '),
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: AppTypography.caption.copyWith(color: AppColors.textSecondary),
      ),
      trailing: SizedBox(
        width: AppSpacing.xl,
        height: AppSpacing.xl,
        child: CircularProgressIndicator(
          value: walk.fraction,
          strokeWidth: AppSpacing.xs,
          backgroundColor: AppColors.surfaceLight,
          color: accentColor,
        ),
      ),
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (BuildContext _) => PathScreen(pathId: view.path.id),
        ),
      ),
    );
  }
}

class _PathChoice extends StatelessWidget {
  const _PathChoice({required this.paths});

  final List<MediaPath> paths;

  @override
  Widget build(BuildContext context) {
    final S l = S.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        for (final MediaPath p in paths)
          ListTile(
            key: ValueKey<int>(p.id),
            contentPadding: EdgeInsets.zero,
            leading: Icon(pathKindIcon(p.kind)),
            title: Text(p.name),
            onTap: () => Navigator.of(context).pop((path: p)),
          ),
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.add),
          title: Text(l.pathNew),
          onTap: () => Navigator.of(context).pop((path: null)),
        ),
      ],
    );
  }
}

class _TagForm extends StatefulWidget {
  const _TagForm({required this.known});

  final List<ItemAspectTag> known;

  @override
  State<_TagForm> createState() => _TagFormState();
}

class _TagFormState extends State<_TagForm> {
  PathAspect _aspect = PathAspect.atmosphere;
  final TextEditingController _label = TextEditingController();

  static const int _maxSuggestions = 12;

  @override
  void dispose() {
    _label.dispose();
    super.dispose();
  }

  void _submit([String? label]) {
    final String text = (label ?? _label.text).trim();
    if (text.isEmpty) return;
    Navigator.of(context).pop((aspect: _aspect, label: text));
  }

  @override
  Widget build(BuildContext context) {
    final S l = S.of(context);
    final String query = _label.text.trim().toLowerCase();
    final List<String> suggestions = <String>{
      for (final ItemAspectTag t in widget.known)
        if (t.aspect == _aspect &&
            (query.isEmpty || t.label.toLowerCase().contains(query)))
          t.label,
    }.take(_maxSuggestions).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.xs,
          children: <Widget>[
            for (final PathAspect a in PathAspect.values)
              ChoiceChip(
                key: ValueKey<PathAspect>(a),
                avatar: Icon(aspectIcon(a), size: 16),
                label: Text(aspectLabel(a, l)),
                selected: a == _aspect,
                onSelected: (_) => setState(() => _aspect = a),
              ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        TextField(
          controller: _label,
          autofocus: true,
          textCapitalization: TextCapitalization.none,
          textInputAction: TextInputAction.done,
          onChanged: (_) => setState(() {}),
          onSubmitted: (_) => _submit(),
          decoration: InputDecoration(hintText: l.aspectTagHint),
        ),
        if (suggestions.isNotEmpty) ...<Widget>[
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.xs,
            children: <Widget>[
              for (final String s in suggestions)
                ActionChip(
                  key: ValueKey<String>(s),
                  label: Text(s),
                  onPressed: () => _submit(s),
                ),
            ],
          ),
        ],
        const SizedBox(height: AppSpacing.md),
        JournalSheetActions(
          saveLabel: l.add,
          cancelLabel: l.cancel,
          onSave: _label.text.trim().isEmpty ? null : _submit,
        ),
      ],
    );
  }
}
