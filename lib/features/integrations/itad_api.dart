import 'package:dio/dio.dart';

import '../../core/api/api_dio.dart';

class ItadException implements Exception {
  const ItadException(this.message, {this.statusCode});

  final String message;
  final int? statusCode;

  bool get isBadKey => statusCode == 401 || statusCode == 403;

  @override
  String toString() => 'ItadException($statusCode, $message)';
}

class ItadPrice {
  const ItadPrice({
    required this.id,
    this.price,
    this.regular,
    this.cut,
    this.currency,
    this.shop,
    this.url,
    this.lowPrice,
  });

  final String id;
  final double? price;
  final double? regular;
  final int? cut;
  final String? currency;
  final String? shop;
  final String? url;
  final double? lowPrice;
}

/// IsThereAnyDeal v2 API: one game id per title or Steam app, then prices
/// and the all-time low for a batch of ids in the user's country.
class ItadApi {
  ItadApi({Dio? dio})
    : _dio =
          dio ??
          createApiDio(
            connectTimeout: _timeout,
            receiveTimeout: _timeout,
            baseUrl: 'https://api.isthereanydeal.com',
          );

  static const Duration _timeout = Duration(seconds: 10);
  static const int steamShopId = 61;

  /// The prices endpoint caps a request at this many ids.
  static const int batchSize = 200;

  final Dio _dio;

  /// Steam app ids ("app/570") to ITAD game ids; unknown apps are absent.
  Future<Map<String, String>> lookupSteamApps(
    List<String> appIds, {
    required String apiKey,
  }) async {
    if (appIds.isEmpty) return <String, String>{};
    final Map<String, dynamic> data = await _call<Map<String, dynamic>>(
      () => _dio.post<Map<String, dynamic>>(
        '/lookup/id/shop/$steamShopId/v1',
        queryParameters: <String, dynamic>{'key': apiKey},
        data: <String>[for (final String id in appIds) 'app/$id'],
      ),
    );
    final Map<String, String> result = <String, String>{};
    for (final String appId in appIds) {
      final Object? id = data['app/$appId'];
      if (id is String) result[appId] = id;
    }
    return result;
  }

  Future<String?> lookupTitle(String title, {required String apiKey}) async {
    final Map<String, dynamic> data = await _call<Map<String, dynamic>>(
      () => _dio.get<Map<String, dynamic>>(
        '/games/lookup/v1',
        queryParameters: <String, dynamic>{'key': apiKey, 'title': title},
      ),
    );
    final Object? game = data['game'];
    if (data['found'] != true || game is! Map<String, dynamic>) return null;
    return game['id'] as String?;
  }

  /// Cheapest current deal per game plus the all-time low.
  Future<List<ItadPrice>> prices(
    List<String> ids, {
    required String apiKey,
    required String country,
  }) async {
    final List<ItadPrice> result = <ItadPrice>[];
    for (int i = 0; i < ids.length; i += batchSize) {
      final List<String> batch = ids.sublist(
        i,
        i + batchSize > ids.length ? ids.length : i + batchSize,
      );
      final List<dynamic> data = await _call<List<dynamic>>(
        () => _dio.post<List<dynamic>>(
          '/games/prices/v3',
          queryParameters: <String, dynamic>{'key': apiKey, 'country': country},
          data: batch,
        ),
      );
      for (final dynamic raw in data) {
        if (raw is Map<String, dynamic>) result.add(_parse(raw));
      }
    }
    return result;
  }

  static ItadPrice _parse(Map<String, dynamic> raw) {
    Map<String, dynamic>? best;
    final Object? deals = raw['deals'];
    if (deals is List<dynamic>) {
      for (final dynamic d in deals) {
        if (d is! Map<String, dynamic>) continue;
        final double? amount = _amount(d['price']);
        if (amount == null) continue;
        final double? bestAmount = best == null ? null : _amount(best['price']);
        if (bestAmount == null || amount < bestAmount) best = d;
      }
    }
    final Object? lows = raw['historyLow'];
    final Map<String, dynamic>? deal = best;
    final Object? shop = deal?['shop'];
    final Object? price = deal?['price'];
    return ItadPrice(
      id: raw['id'] as String? ?? '',
      price: _amount(price),
      regular: _amount(deal?['regular']),
      cut: (deal?['cut'] as num?)?.toInt(),
      currency: price is Map<String, dynamic>
          ? price['currency'] as String?
          : null,
      shop: shop is Map<String, dynamic> ? shop['name'] as String? : null,
      url: deal?['url'] as String?,
      lowPrice: lows is Map<String, dynamic> ? _amount(lows['all']) : null,
    );
  }

  static double? _amount(Object? price) => price is Map<String, dynamic>
      ? (price['amount'] as num?)?.toDouble()
      : null;

  Future<T> _call<T>(Future<Response<T>> Function() request) async {
    try {
      final Response<T> response = await request();
      final T? data = response.data;
      if (data == null) throw const ItadException('Empty response');
      return data;
    } on DioException catch (e) {
      throw ItadException(
        e.message ?? 'Network error',
        statusCode: e.response?.statusCode,
      );
    }
  }
}
