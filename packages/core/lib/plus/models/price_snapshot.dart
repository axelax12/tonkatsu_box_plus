/// The best current deal and the all-time low for one wished-for game, as
/// IsThereAnyDeal reported them at [checkedAt].
class PriceSnapshot {
  const PriceSnapshot({
    required this.itemId,
    required this.checkedAt,
    this.itadId,
    this.price,
    this.regular,
    this.cut,
    this.currency,
    this.shop,
    this.url,
    this.lowPrice,
    this.alertedLow,
  });

  factory PriceSnapshot.fromDb(Map<String, dynamic> row) {
    return PriceSnapshot(
      itemId: row['item_id'] as int,
      itadId: row['itad_id'] as String?,
      price: (row['price'] as num?)?.toDouble(),
      regular: (row['regular'] as num?)?.toDouble(),
      cut: row['cut'] as int?,
      currency: row['currency'] as String?,
      shop: row['shop'] as String?,
      url: row['url'] as String?,
      lowPrice: (row['low_price'] as num?)?.toDouble(),
      alertedLow: (row['alerted_low'] as num?)?.toDouble(),
      checkedAt: DateTime.fromMillisecondsSinceEpoch(row['checked_at'] as int),
    );
  }

  final int itemId;

  /// Null when the store has no page for this game.
  final String? itadId;
  final double? price;
  final double? regular;

  /// Discount in percent.
  final int? cut;
  final String? currency;
  final String? shop;
  final String? url;
  final double? lowPrice;

  /// The low already announced, so the same price is not notified twice.
  final double? alertedLow;
  final DateTime checkedAt;

  /// Cheapest it has ever been, give or take a cent of rounding.
  bool get isAtHistoricLow {
    final double? now = price;
    final double? low = lowPrice;
    const double cent = 0.01;
    return now != null && low != null && now > 0 && now <= low + cent;
  }

  bool get shouldAlert {
    final double? now = price;
    final double? alerted = alertedLow;
    return isAtHistoricLow && now != null && (alerted == null || now < alerted);
  }

  Map<String, dynamic> toDb() {
    return <String, dynamic>{
      'item_id': itemId,
      'itad_id': itadId,
      'price': price,
      'regular': regular,
      'cut': cut,
      'currency': currency,
      'shop': shop,
      'url': url,
      'low_price': lowPrice,
      'alerted_low': alertedLow,
      'checked_at': checkedAt.millisecondsSinceEpoch,
    };
  }

  PriceSnapshot copyWith({double? alertedLow}) {
    return PriceSnapshot(
      itemId: itemId,
      itadId: itadId,
      price: price,
      regular: regular,
      cut: cut,
      currency: currency,
      shop: shop,
      url: url,
      lowPrice: lowPrice,
      alertedLow: alertedLow ?? this.alertedLow,
      checkedAt: checkedAt,
    );
  }
}
