import 'package:core/models/collection_item.dart';
import 'package:core/plus/analytics/collector_insights.dart';
import 'package:core/plus/models/owned_copy.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logging/logging.dart';

import '../../../l10n/app_localizations.dart';
import '../../../shared/extensions/snackbar_extension.dart';
import '../../../shared/services/png_export_service.dart';
import '../../../shared/theme/app_colors.dart';
import '../../../shared/theme/app_spacing.dart';
import '../../../shared/theme/app_typography.dart';
import '../../insights/providers/insights_providers.dart';
import '../../insights/widgets/item_cover_row.dart';
import '../../insights/widgets/stat_tile.dart';
import '../collector_format.dart';
import '../providers/collector_providers.dart';
import '../widgets/collector_room.dart';

class CollectorScreen extends StatelessWidget {
  const CollectorScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final S l = S.of(context);
    return DefaultTabController(
      length: 2,
      child: Column(
        children: <Widget>[
          TabBar(
            tabs: <Widget>[
              Tab(text: l.roomTab),
              Tab(text: l.loansTab),
            ],
          ),
          const Expanded(
            child: TabBarView(children: <Widget>[_RoomTab(), _LoansTab()]),
          ),
        ],
      ),
    );
  }
}

class _RoomTab extends ConsumerStatefulWidget {
  const _RoomTab();

  @override
  ConsumerState<_RoomTab> createState() => _RoomTabState();
}

class _RoomTabState extends ConsumerState<_RoomTab> {
  static final Logger _log = Logger('CollectorRoom');
  static const Duration _imageSettle = Duration(milliseconds: 150);

  final GlobalKey _roomKey = GlobalKey();
  bool _saving = false;

  Future<void> _saveImage() async {
    final S l = S.of(context);
    setState(() => _saving = true);
    await WidgetsBinding.instance.endOfFrame;
    await Future<void>.delayed(_imageSettle);
    final BulkExportResult result;
    try {
      result = await saveBoundaryAsPng(
        repaintKey: _roomKey,
        suggestedFileName: '${sanitizeFileName(l.collectorTitle)}.png',
        saveDialogTitle: l.roomSave,
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
    if (!mounted) return;
    switch (result.status) {
      case BulkExportStatus.saved:
        context.showSnack(l.imageSaved, type: SnackType.success);
      case BulkExportStatus.cancelled:
        break;
      case BulkExportStatus.failed:
        _log.warning('Failed to export the room', result.error);
        context.showSnack(l.statsExportFailed, type: SnackType.error);
    }
  }

  String _sourceLabel(RoomSource source, S l) {
    switch (source) {
      case RoomSource.owned:
        return l.roomSourceOwned;
      case RoomSource.favorites:
        return l.roomSourceFavorites;
      case RoomSource.finishedThisYear:
        return l.roomSourceFinished;
    }
  }

  String _themeLabel(RoomTheme theme, S l) {
    switch (theme) {
      case RoomTheme.wood:
        return l.roomThemeWood;
      case RoomTheme.midnight:
        return l.roomThemeMidnight;
      case RoomTheme.neon:
        return l.roomThemeNeon;
    }
  }

  @override
  Widget build(BuildContext context) {
    final S l = S.of(context);
    final RoomTheme theme = ref.watch(roomThemeProvider);
    final RoomSource source = ref.watch(roomSourceProvider);
    final List<CollectionItem>? items = ref.watch(roomItemsProvider).valueOrNull;
    final List<KeepsakeProgress> keepsakes =
        ref.watch(keepsakesProvider).valueOrNull ?? const <KeepsakeProgress>[];

    return ListView(
      padding: const EdgeInsets.all(AppSpacing.md),
      children: <Widget>[
        SegmentedButton<RoomTheme>(
          segments: <ButtonSegment<RoomTheme>>[
            for (final RoomTheme t in RoomTheme.values)
              ButtonSegment<RoomTheme>(value: t, label: Text(_themeLabel(t, l))),
          ],
          selected: <RoomTheme>{theme},
          showSelectedIcon: false,
          onSelectionChanged: (Set<RoomTheme> s) =>
              ref.read(roomThemeProvider.notifier).set(s.first),
        ),
        const SizedBox(height: AppSpacing.sm),
        Wrap(
          spacing: AppSpacing.sm,
          children: <Widget>[
            for (final RoomSource s in RoomSource.values)
              ChoiceChip(
                key: ValueKey<RoomSource>(s),
                label: Text(_sourceLabel(s, l)),
                selected: s == source,
                onSelected: (bool _) =>
                    ref.read(roomSourceProvider.notifier).set(s),
              ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        if (items == null)
          const Padding(
            padding: EdgeInsets.all(AppSpacing.xl),
            child: Center(child: CircularProgressIndicator()),
          )
        else
          RepaintBoundary(
            key: _roomKey,
            child: CollectorRoom(
              items: items,
              keepsakes: keepsakes,
              theme: theme,
            ),
          ),
        const SizedBox(height: AppSpacing.md),
        OutlinedButton.icon(
          onPressed: _saving || items == null ? null : _saveImage,
          icon: const Icon(Icons.ios_share),
          label: Text(l.roomSave),
        ),
      ],
    );
  }
}

class _LoansTab extends ConsumerWidget {
  const _LoansTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final S l = S.of(context);
    final MaterialLocalizations material = MaterialLocalizations.of(context);
    final CollectionValue? value = ref.watch(collectionValueProvider).valueOrNull;
    final List<OwnedCopy> loans =
        ref.watch(activeLoansProvider).valueOrNull ?? const <OwnedCopy>[];
    final Map<int, CollectionItem> itemsById = <int, CollectionItem>{
      for (final CollectionItem i
          in ref.watch(libraryItemsProvider).valueOrNull ??
              const <CollectionItem>[])
        i.id: i,
    };
    final DateTime now = DateTime.now();

    return ListView(
      padding: const EdgeInsets.all(AppSpacing.md),
      children: <Widget>[
        if (value != null)
          StatTileGrid(
            tiles: <Widget>[
              StatTile(
                icon: Icons.album_outlined,
                value: '${value.physicalCount}',
                label: l.valuePhysical,
              ),
              StatTile(
                icon: Icons.cloud_download_outlined,
                value: '${value.digitalCount}',
                label: l.valueDigital,
              ),
              for (final MapEntry<String, double> e
                  in value.spentByCurrency.entries)
                StatTile(
                  key: ValueKey<String>('spent-${e.key}'),
                  icon: Icons.payments_outlined,
                  value: formatPrice(e.value, e.key),
                  label: l.valueSpent,
                ),
            ],
          ),
        const SizedBox(height: AppSpacing.md),
        Text(l.loansTab, style: AppTypography.h3),
        const SizedBox(height: AppSpacing.sm),
        if (loans.isEmpty)
          Text(
            l.loansNone,
            style: AppTypography.body.copyWith(color: AppColors.textSecondary),
          ),
        for (final OwnedCopy loan in loans)
          if (itemsById[loan.itemId] case final CollectionItem item)
            ItemCoverRow(
              key: ValueKey<int>(loan.id),
              item: item,
              caption: <String>[
                l.copyLentChip(loan.loanedTo ?? ''),
                if (loan.loanDueAt case final DateTime due)
                  l.loanDue(material.formatMediumDate(due)),
                if (loan.isOverdue(now)) l.copyOverdue,
              ].join(' · '),
              trailing: IconButton(
                tooltip: l.copyReturned,
                icon: const Icon(Icons.assignment_return_outlined),
                onPressed: () =>
                    ref.read(copiesControllerProvider).markReturned(loan),
              ),
            ),
      ],
    );
  }
}
