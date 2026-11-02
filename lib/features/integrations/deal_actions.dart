import 'package:core/models/collection_item.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logging/logging.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../l10n/app_localizations.dart';
import '../../shared/extensions/snackbar_extension.dart';
import '../collector/collector_format.dart';
import '../notifications/plus_notifications.dart';
import 'itad_api.dart';
import 'providers/integrations_providers.dart';

final Logger _log = Logger('Deals');

/// Refreshes prices for [items] and turns new all-time lows into
/// notifications. Errors become a snack, never an exception.
Future<void> refreshDeals(
  BuildContext context,
  WidgetRef ref,
  List<CollectionItem> items,
) async {
  final S l = S.of(context);
  try {
    final List<DealAlert> alerts = await ref
        .read(dealsServiceProvider)
        .refresh(items);
    for (final DealAlert a in alerts) {
      final double? price = a.snapshot.price;
      if (price == null) continue;
      await PlusNotifications.instance.showDeal(
        itemId: a.item.id,
        title: l.dealLowTitle(a.item.itemName),
        body: l.dealLowBody(
          formatPrice(price, a.snapshot.currency),
          a.snapshot.shop ?? '',
        ),
      );
    }
  } on ItadException catch (e, stack) {
    _log.warning('Deal refresh failed', e, stack);
    if (context.mounted) {
      context.showSnack(
        e.isBadKey ? l.dealBadKey : l.steamNetworkError,
        type: SnackType.error,
      );
    }
  }
}

Future<void> openDeal(String? url) async {
  if (url == null || url.isEmpty) return;
  await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
}
