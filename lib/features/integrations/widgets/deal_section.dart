import 'package:core/models/collection_item.dart';
import 'package:core/plus/models/price_snapshot.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/app_localizations.dart';
import '../../../shared/theme/app_colors.dart';
import '../../../shared/theme/app_spacing.dart';
import '../../../shared/theme/app_typography.dart';
import '../../collector/collector_format.dart';
import '../deal_actions.dart';
import '../providers/integrations_providers.dart';
import 'connections_sheet.dart';

/// Best current price and the all-time low for a game the user wants.
class DealSection extends ConsumerStatefulWidget {
  const DealSection({required this.item, required this.accentColor, super.key});

  final CollectionItem item;
  final Color accentColor;

  @override
  ConsumerState<DealSection> createState() => _DealSectionState();
}

class _DealSectionState extends ConsumerState<DealSection> {
  bool _loading = false;

  Future<void> _refresh() async {
    setState(() => _loading = true);
    await refreshDeals(context, ref, <CollectionItem>[widget.item]);
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    final S l = S.of(context);
    final bool connected = ref.watch(itadSettingsProvider) != null;
    final PriceSnapshot? snap = ref
        .watch(itemPriceProvider(widget.item.id))
        .valueOrNull;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Row(
          children: <Widget>[
            Icon(Icons.sell_outlined, size: 20, color: widget.accentColor),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Text(
                l.dealTitle,
                style: AppTypography.h3.copyWith(fontWeight: FontWeight.w600),
              ),
            ),
            if (connected)
              IconButton(
                tooltip: l.steamSync,
                onPressed: _loading ? null : _refresh,
                icon: _loading
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.refresh),
              ),
          ],
        ),
        if (!connected)
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: () => showConnectionsSheet(context),
              icon: const Icon(Icons.link),
              label: Text(l.dealConnect),
              style: TextButton.styleFrom(
                foregroundColor: widget.accentColor,
                minimumSize: const Size(0, AppSpacing.buttonHeightCompact),
              ),
            ),
          )
        else if (snap == null)
          Text(
            l.dealNotChecked,
            style: AppTypography.bodySmall.copyWith(
              color: AppColors.textSecondary,
            ),
          )
        else
          DealSummary(snapshot: snap, accentColor: widget.accentColor),
      ],
    );
  }
}

/// Price, discount, store and the historic low on one card.
class DealSummary extends StatelessWidget {
  const DealSummary({
    required this.snapshot,
    required this.accentColor,
    super.key,
  });

  final PriceSnapshot snapshot;
  final Color accentColor;

  @override
  Widget build(BuildContext context) {
    final S l = S.of(context);
    final double? price = snapshot.price;
    final double? low = snapshot.lowPrice;
    final int? cut = snapshot.cut;
    final String? shop = snapshot.shop;
    if (snapshot.itadId == null || price == null) {
      return Text(
        l.dealNotListed,
        style: AppTypography.bodySmall.copyWith(color: AppColors.textSecondary),
      );
    }
    final bool atLow = snapshot.isAtHistoricLow;
    return InkWell(
      borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
      onTap: () => openDeal(snapshot.url),
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: (atLow ? AppColors.success : accentColor).withValues(
            alpha: 0.12,
          ),
          borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        ),
        child: Row(
          children: <Widget>[
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      Text(
                        formatPrice(price, snapshot.currency),
                        style: AppTypography.h2,
                      ),
                      if (cut != null && cut > 0) ...<Widget>[
                        const SizedBox(width: AppSpacing.sm),
                        Text(
                          '-$cut%',
                          style: AppTypography.body.copyWith(
                            color: AppColors.success,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ],
                  ),
                  if (shop != null) Text(shop, style: AppTypography.bodySmall),
                  if (low != null)
                    Text(
                      atLow
                          ? l.dealAtLow
                          : l.dealHistoricLow(
                              formatPrice(low, snapshot.currency),
                            ),
                      style: AppTypography.caption.copyWith(
                        color: atLow
                            ? AppColors.success
                            : AppColors.textSecondary,
                        fontWeight: atLow ? FontWeight.w700 : null,
                      ),
                    ),
                ],
              ),
            ),
            const Icon(Icons.open_in_new, size: 18),
          ],
        ),
      ),
    );
  }
}
