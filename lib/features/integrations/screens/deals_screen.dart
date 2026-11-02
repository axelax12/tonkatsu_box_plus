import 'package:core/models/collection_item.dart';
import 'package:core/plus/models/price_snapshot.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/app_localizations.dart';
import '../../../shared/theme/app_colors.dart';
import '../../../shared/theme/app_spacing.dart';
import '../../../shared/theme/app_typography.dart';
import '../../insights/widgets/item_cover_row.dart';
import '../deal_actions.dart';
import '../providers/integrations_providers.dart';
import '../widgets/connections_sheet.dart';
import '../widgets/deal_section.dart';

/// Planned games with their best price, biggest discounts first.
class DealsScreen extends ConsumerStatefulWidget {
  const DealsScreen({super.key});

  @override
  ConsumerState<DealsScreen> createState() => _DealsScreenState();
}

class _DealsScreenState extends ConsumerState<DealsScreen> {
  bool _refreshing = false;

  Future<void> _refresh() async {
    final List<CollectionItem> games = await ref.read(
      watchedGamesProvider.future,
    );
    if (!mounted) return;
    setState(() => _refreshing = true);
    await refreshDeals(context, ref, games);
    if (mounted) setState(() => _refreshing = false);
  }

  @override
  Widget build(BuildContext context) {
    final S l = S.of(context);
    final bool connected = ref.watch(itadSettingsProvider) != null;
    final List<CollectionItem> games =
        ref.watch(watchedGamesProvider).valueOrNull ?? const <CollectionItem>[];
    final Map<int, PriceSnapshot> prices = <int, PriceSnapshot>{
      for (final PriceSnapshot p
          in ref.watch(allPricesProvider).valueOrNull ??
              const <PriceSnapshot>[])
        p.itemId: p,
    };
    final List<CollectionItem> sorted = <CollectionItem>[...games]
      ..sort(
        (CollectionItem a, CollectionItem b) =>
            (prices[b.id]?.cut ?? -1).compareTo(prices[a.id]?.cut ?? -1),
      );

    if (!connected) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Text(
                l.dealConnectHint,
                textAlign: TextAlign.center,
                style: AppTypography.body.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              FilledButton.icon(
                onPressed: () => showConnectionsSheet(context),
                icon: const Icon(Icons.link),
                label: Text(l.dealConnect),
              ),
            ],
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _refresh,
      child: ListView(
        padding: const EdgeInsets.all(AppSpacing.md),
        children: <Widget>[
          Text(
            l.dealsHint,
            style: AppTypography.bodySmall.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          FilledButton.icon(
            onPressed: _refreshing ? null : _refresh,
            icon: const Icon(Icons.refresh),
            label: Text(l.dealsRefresh),
          ),
          const SizedBox(height: AppSpacing.md),
          if (games.isEmpty)
            Text(
              l.dealsEmpty,
              textAlign: TextAlign.center,
              style: AppTypography.body.copyWith(color: AppColors.textSecondary),
            ),
          for (final CollectionItem item in sorted)
            Padding(
              key: ValueKey<int>(item.id),
              padding: const EdgeInsets.only(bottom: AppSpacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  ItemCoverRow(item: item),
                  if (prices[item.id] case final PriceSnapshot snap)
                    DealSummary(snapshot: snap, accentColor: AppColors.brand),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
