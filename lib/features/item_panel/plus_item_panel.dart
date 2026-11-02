import 'package:core/models/collection_item.dart';
import 'package:core/models/media_type.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/app_localizations.dart';
import '../../shared/theme/app_spacing.dart';
import '../collector/widgets/copies_section.dart';
import '../integrations/providers/integrations_providers.dart';
import '../integrations/widgets/deal_section.dart';
import '../integrations/widgets/steam_achievements_section.dart';
import '../journal/widgets/journal_section.dart';
import '../paths/widgets/paths_section.dart';
import '../settings/providers/settings_provider.dart';

enum PlusPanelTab { journal, copies, paths, achievements, deals }

/// The fork's item sections behind one row of chips, one open at a time, so
/// the item page stays short instead of stacking five blocks.
class PlusItemPanel extends ConsumerStatefulWidget {
  const PlusItemPanel({
    required this.item,
    required this.itemName,
    required this.accentColor,
    required this.isEditable,
    super.key,
  });

  final CollectionItem item;
  final String itemName;
  final Color accentColor;
  final bool isEditable;

  static const String prefsKey = 'plus_item_panel_tab';

  static const double _selectedAlpha = 0.25;

  @override
  ConsumerState<PlusItemPanel> createState() => _PlusItemPanelState();
}

class _PlusItemPanelState extends ConsumerState<PlusItemPanel> {
  // The last chip opened is reopened on the next item.
  late PlusPanelTab _tab = _restore();

  PlusPanelTab _restore() {
    final String? stored = ref
        .read(sharedPreferencesProvider)
        .getString(PlusItemPanel.prefsKey);
    return PlusPanelTab.values
            .where((PlusPanelTab t) => t.name == stored)
            .firstOrNull ??
        PlusPanelTab.journal;
  }

  List<PlusPanelTab> _available() => <PlusPanelTab>[
    PlusPanelTab.journal,
    PlusPanelTab.copies,
    PlusPanelTab.paths,
    if (widget.item.mediaType == MediaType.game) PlusPanelTab.achievements,
    if (isWatchedForDeals(widget.item)) PlusPanelTab.deals,
  ];

  void _select(PlusPanelTab tab) {
    setState(() => _tab = tab);
    ref.read(sharedPreferencesProvider).setString(
      PlusItemPanel.prefsKey,
      tab.name,
    );
  }

  static IconData _icon(PlusPanelTab tab) => switch (tab) {
    PlusPanelTab.journal => Icons.menu_book_outlined,
    PlusPanelTab.copies => Icons.shelves,
    PlusPanelTab.paths => Icons.route_outlined,
    PlusPanelTab.achievements => Icons.emoji_events_outlined,
    PlusPanelTab.deals => Icons.sell_outlined,
  };

  static String _label(PlusPanelTab tab, S l) => switch (tab) {
    PlusPanelTab.journal => l.journalTitle,
    PlusPanelTab.copies => l.copiesTitle,
    PlusPanelTab.paths => l.pathsSectionTitle,
    PlusPanelTab.achievements => l.steamAchievementsTitle,
    PlusPanelTab.deals => l.dealTitle,
  };

  Widget _content(PlusPanelTab tab) => switch (tab) {
    PlusPanelTab.journal => JournalSection(
      itemId: widget.item.id,
      itemName: widget.itemName,
      accentColor: widget.accentColor,
      isEditable: widget.isEditable,
    ),
    PlusPanelTab.copies => CopiesSection(
      itemId: widget.item.id,
      itemName: widget.itemName,
      accentColor: widget.accentColor,
      isEditable: widget.isEditable,
    ),
    PlusPanelTab.paths => PathsSection(
      item: widget.item,
      accentColor: widget.accentColor,
      isEditable: widget.isEditable,
    ),
    PlusPanelTab.achievements => SteamAchievementsSection(
      igdbId: widget.item.externalId,
      accentColor: widget.accentColor,
    ),
    PlusPanelTab.deals => DealSection(
      item: widget.item,
      accentColor: widget.accentColor,
    ),
  };

  @override
  Widget build(BuildContext context) {
    final S l = S.of(context);
    final List<PlusPanelTab> tabs = _available();
    final PlusPanelTab tab = tabs.contains(_tab) ? _tab : tabs.first;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: <Widget>[
              for (final PlusPanelTab t in tabs)
                Padding(
                  key: ValueKey<PlusPanelTab>(t),
                  padding: const EdgeInsets.only(right: AppSpacing.sm),
                  child: ChoiceChip(
                    avatar: Icon(_icon(t), size: 16),
                    label: Text(_label(t, l)),
                    selected: t == tab,
                    showCheckmark: false,
                    selectedColor: widget.accentColor.withValues(
                      alpha: PlusItemPanel._selectedAlpha,
                    ),
                    onSelected: (_) => _select(t),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        AnimatedSize(
          duration: kThemeAnimationDuration,
          alignment: Alignment.topCenter,
          child: KeyedSubtree(key: ValueKey<PlusPanelTab>(tab), child: _content(tab)),
        ),
      ],
    );
  }
}
