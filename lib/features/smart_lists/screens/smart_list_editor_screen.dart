import 'package:core/models/collection.dart';
import 'package:core/models/item_status.dart';
import 'package:core/models/media_type.dart';
import 'package:core/models/tag.dart';
import 'package:core/plus/models/smart_list.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/app_localizations.dart';
import '../../../shared/constants/item_status_ui.dart';
import '../../../shared/constants/media_type_theme.dart';
import '../../../shared/constants/media_type_ui.dart';
import '../../../shared/theme/app_colors.dart';
import '../../../shared/theme/app_spacing.dart';
import '../../../shared/theme/app_typography.dart';
import '../../collections/providers/collections_provider.dart';
import '../../collections/providers/global_tags_provider.dart';
import '../providers/smart_list_providers.dart';

/// Builds or edits a smart list, with the match count updating live.
class SmartListEditorScreen extends ConsumerStatefulWidget {
  const SmartListEditorScreen({this.existing, super.key});

  final SmartList? existing;

  @override
  ConsumerState<SmartListEditorScreen> createState() =>
      _SmartListEditorScreenState();
}

class _SmartListEditorScreenState extends ConsumerState<SmartListEditorScreen> {
  static const int _minutesPerHour = 60;

  late SmartListRules _rules = widget.existing?.rules ?? const SmartListRules();
  late final TextEditingController _name =
      TextEditingController(text: widget.existing?.name ?? '');
  late final TextEditingController _text =
      TextEditingController(text: _rules.text ?? '');
  late final TextEditingController _minHours =
      TextEditingController(text: _hoursText(_rules.minMinutes));
  late final TextEditingController _maxHours =
      TextEditingController(text: _hoursText(_rules.maxMinutes));
  late final TextEditingController _unitsLeft =
      TextEditingController(text: _rules.maxUnitsLeft?.toString() ?? '');
  late final TextEditingController _minRating =
      TextEditingController(text: _rules.minRating?.toStringAsFixed(0) ?? '');
  late final TextEditingController _minAge =
      TextEditingController(text: _rules.minAgeDays?.toString() ?? '');

  bool _saving = false;

  static String _hoursText(int? minutes) =>
      minutes == null ? '' : (minutes / _minutesPerHour).toStringAsFixed(0);

  @override
  void initState() {
    super.initState();
    _name.addListener(_onNameChanged);
  }

  @override
  void dispose() {
    _name.removeListener(_onNameChanged);
    for (final TextEditingController c in <TextEditingController>[
      _name,
      _text,
      _minHours,
      _maxHours,
      _unitsLeft,
      _minRating,
      _minAge,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  void _onNameChanged() => setState(() {});

  static int? _parsePositive(String text) {
    final int? value = int.tryParse(text.trim());
    return (value == null || value < 0) ? null : value;
  }

  void _setNumbers() {
    final int? minH = _parsePositive(_minHours.text);
    final int? maxH = _parsePositive(_maxHours.text);
    final int? left = _parsePositive(_unitsLeft.text);
    final int? rating = _parsePositive(_minRating.text);
    final int? age = _parsePositive(_minAge.text);
    final String text = _text.text.trim();
    setState(() {
      _rules = _rules.copyWith(
        minMinutes: minH == null ? null : minH * _minutesPerHour,
        clearMinMinutes: minH == null,
        maxMinutes: maxH == null ? null : maxH * _minutesPerHour,
        clearMaxMinutes: maxH == null,
        maxUnitsLeft: left,
        clearMaxUnitsLeft: left == null,
        minRating: rating?.toDouble(),
        clearMinRating: rating == null,
        minAgeDays: age,
        clearMinAgeDays: age == null,
        text: text,
        clearText: text.isEmpty,
      );
    });
  }

  Set<T> _toggled<T>(Set<T> set, T value, bool on) =>
      on ? <T>{...set, value} : (<T>{...set}..remove(value));

  Future<void> _save() async {
    final String name = _name.text.trim();
    if (name.isEmpty || _saving) return;
    setState(() => _saving = true);
    final DateTime now = DateTime.now();
    final SmartList base = widget.existing ??
        SmartList(
          id: 0,
          name: name,
          rules: _rules,
          createdAt: now,
          updatedAt: now,
        );
    await ref.read(smartListControllerProvider).save(
          base.copyWith(name: name, rules: _rules, updatedAt: now),
        );
    if (mounted) Navigator.of(context).pop();
  }

  Widget _section(String title, Widget child) {
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(title, style: AppTypography.h3),
          const SizedBox(height: AppSpacing.sm),
          child,
        ],
      ),
    );
  }

  Widget _numberField(TextEditingController c, String label) {
    return TextField(
      controller: c,
      keyboardType: TextInputType.number,
      decoration: InputDecoration(labelText: label),
      onChanged: (String _) => _setNumbers(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final S l = S.of(context);
    final int? matches =
        ref.watch(smartListContextProvider).valueOrNull?.apply(_rules).length;
    final List<Tag> tags =
        ref.watch(globalTagsProvider).valueOrNull ?? const <Tag>[];
    final List<Collection> collections =
        ref.watch(collectionsProvider).valueOrNull ?? const <Collection>[];

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.existing == null ? l.smartNew : l.edit),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  matches == null ? '…' : l.smartMatches(matches),
                  style: AppTypography.body.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
              FilledButton(
                onPressed:
                    _name.text.trim().isEmpty || _saving ? null : _save,
                style: FilledButton.styleFrom(
                  minimumSize: const Size(0, AppSpacing.buttonHeight),
                ),
                child: Text(l.save),
              ),
            ],
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.md,
          AppSpacing.md,
          AppSpacing.md,
          AppSpacing.xl,
        ),
        children: <Widget>[
          TextField(
            controller: _name,
            autofocus: widget.existing == null,
            textCapitalization: TextCapitalization.sentences,
            decoration: InputDecoration(labelText: l.smartName),
          ),
          _section(
            l.smartRuleTypes,
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.xs,
              children: <Widget>[
                for (final MediaType type in MediaType.values)
                  FilterChip(
                    key: ValueKey<MediaType>(type),
                    avatar: Icon(
                      MediaTypeTheme.iconFor(type),
                      size: 16,
                      color: MediaTypeTheme.colorFor(type),
                    ),
                    label: Text(type.localizedPluralLabel(l)),
                    selected: _rules.mediaTypes.contains(type),
                    onSelected: (bool on) => setState(() {
                      _rules = _rules.copyWith(
                        mediaTypes: _toggled(_rules.mediaTypes, type, on),
                      );
                    }),
                  ),
              ],
            ),
          ),
          _section(
            l.smartRuleStatus,
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.xs,
              children: <Widget>[
                for (final ItemStatus status in ItemStatus.values)
                  FilterChip(
                    key: ValueKey<ItemStatus>(status),
                    avatar: Icon(status.materialIcon, size: 16),
                    label: Text(status.genericLabel(l)),
                    selected: _rules.statuses.contains(status),
                    onSelected: (bool on) => setState(() {
                      _rules = _rules.copyWith(
                        statuses: _toggled(_rules.statuses, status, on),
                      );
                    }),
                  ),
              ],
            ),
          ),
          _section(
            l.smartRuleLength,
            Row(
              children: <Widget>[
                Expanded(child: _numberField(_minHours, l.smartMinHours)),
                const SizedBox(width: AppSpacing.sm),
                Expanded(child: _numberField(_maxHours, l.smartMaxHours)),
              ],
            ),
          ),
          _section(
            l.smartRuleProgress,
            Column(
              children: <Widget>[
                _numberField(_unitsLeft, l.smartUnitsLeft),
                const SizedBox(height: AppSpacing.sm),
                _numberField(_minRating, l.smartMinRating),
                const SizedBox(height: AppSpacing.sm),
                _numberField(_minAge, l.smartMinAgeDays),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(l.smartFavoritesOnly),
                  value: _rules.favoritesOnly,
                  onChanged: (bool v) => setState(
                    () => _rules = _rules.copyWith(favoritesOnly: v),
                  ),
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(l.smartNeverStarted),
                  value: _rules.neverStarted,
                  onChanged: (bool v) => setState(
                    () => _rules = _rules.copyWith(neverStarted: v),
                  ),
                ),
              ],
            ),
          ),
          if (tags.isNotEmpty)
            _section(
              l.smartRuleTags,
              Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.xs,
                children: <Widget>[
                  for (final Tag tag in tags)
                    FilterChip(
                      key: ValueKey<int>(tag.id),
                      label: Text(tag.name),
                      selected: _rules.tagIds.contains(tag.id),
                      onSelected: (bool on) => setState(() {
                        _rules = _rules.copyWith(
                          tagIds: _toggled(_rules.tagIds, tag.id, on),
                        );
                      }),
                    ),
                ],
              ),
            ),
          if (collections.isNotEmpty)
            _section(
              l.smartRuleCollections,
              Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.xs,
                children: <Widget>[
                  for (final Collection c in collections)
                    FilterChip(
                      key: ValueKey<String>('c${c.id}'),
                      label: Text(c.name),
                      selected: _rules.collectionIds.contains(c.id),
                      onSelected: (bool on) => setState(() {
                        _rules = _rules.copyWith(
                          collectionIds: _toggled(
                            _rules.collectionIds,
                            c.id,
                            on,
                          ),
                        );
                      }),
                    ),
                ],
              ),
            ),
          _section(
            l.smartRuleText,
            TextField(
              controller: _text,
              decoration: InputDecoration(
                labelText: l.smartTextHint,
                prefixIcon: const Icon(Icons.search),
              ),
              onChanged: (String _) => _setNumbers(),
            ),
          ),
          _section(
            l.smartSort,
            DropdownButtonFormField<SmartListSort>(
              initialValue: _rules.sort,
              items: <DropdownMenuItem<SmartListSort>>[
                for (final SmartListSort sort in SmartListSort.values)
                  DropdownMenuItem<SmartListSort>(
                    value: sort,
                    child: Text(_sortLabel(sort, l)),
                  ),
              ],
              onChanged: (SmartListSort? sort) => setState(
                () => _rules = _rules.copyWith(sort: sort),
              ),
            ),
          ),
        ],
      ),
    );
  }

  static String _sortLabel(SmartListSort sort, S l) {
    switch (sort) {
      case SmartListSort.addedOldest:
        return l.smartSortOldest;
      case SmartListSort.addedNewest:
        return l.smartSortNewest;
      case SmartListSort.shortestFirst:
        return l.smartSortShortest;
      case SmartListSort.ratingHighest:
        return l.smartSortRating;
      case SmartListSort.nameAsc:
        return l.smartSortName;
    }
  }
}
