import 'package:dio/dio.dart';

import '../../core/api/api_dio.dart';

class SteamAchievementsException implements Exception {
  const SteamAchievementsException(this.reason, [this.detail]);

  final SteamAchievementsReason reason;
  final String? detail;

  @override
  String toString() => 'SteamAchievementsException($reason, $detail)';
}

enum SteamAchievementsReason { privateProfile, noAchievements, badKey, network }

class SteamAchievement {
  const SteamAchievement({
    required this.apiName,
    required this.title,
    required this.achieved,
    required this.order,
    this.description,
    this.icon,
    this.iconGray,
    this.unlockTime,
    this.hidden = false,
  });

  final String apiName;
  final String title;
  final String? description;
  final String? icon;
  final String? iconGray;
  final bool achieved;

  /// Seconds since the epoch, as Steam reports it.
  final int? unlockTime;
  final bool hidden;
  final int order;
}

/// Steam Web API calls the fork needs beyond upstream's library import.
class SteamAchievementsApi {
  SteamAchievementsApi({Dio? dio})
    : _dio = dio ?? createApiDio(connectTimeout: _timeout, receiveTimeout: _timeout);

  static const Duration _timeout = Duration(seconds: 10);
  static const String _base = 'https://api.steampowered.com/ISteamUserStats';

  final Dio _dio;

  /// Joins the player's progress with the game's schema (names, icons).
  Future<List<SteamAchievement>> fetch({
    required String apiKey,
    required String steamId,
    required String appId,
  }) async {
    final Map<String, Map<String, dynamic>> schema = await _schema(
      apiKey: apiKey,
      appId: appId,
    );
    final List<dynamic> player = await _player(
      apiKey: apiKey,
      steamId: steamId,
      appId: appId,
    );
    final List<SteamAchievement> result = <SteamAchievement>[];
    int order = 0;
    for (final dynamic raw in player) {
      if (raw is! Map<String, dynamic>) continue;
      final String? apiName = raw['apiname'] as String?;
      if (apiName == null) continue;
      final Map<String, dynamic> meta =
          schema[apiName] ?? const <String, dynamic>{};
      final int unlock = (raw['unlocktime'] as num?)?.toInt() ?? 0;
      result.add(
        SteamAchievement(
          apiName: apiName,
          title:
              meta['displayName'] as String? ?? raw['name'] as String? ?? apiName,
          description:
              meta['description'] as String? ?? raw['description'] as String?,
          icon: meta['icon'] as String?,
          iconGray: meta['icongray'] as String?,
          hidden: (meta['hidden'] as num?) == 1,
          achieved: (raw['achieved'] as num?) == 1,
          unlockTime: unlock > 0 ? unlock : null,
          order: order++,
        ),
      );
    }
    return result;
  }

  Future<Map<String, Map<String, dynamic>>> _schema({
    required String apiKey,
    required String appId,
  }) async {
    final Map<String, dynamic> data = await _get(
      '$_base/GetSchemaForGame/v2/',
      <String, dynamic>{'key': apiKey, 'appid': appId, 'l': 'english'},
    );
    final Object? game = data['game'];
    final Object? stats = game is Map<String, dynamic>
        ? game['availableGameStats']
        : null;
    final Object? list = stats is Map<String, dynamic>
        ? stats['achievements']
        : null;
    if (list is! List<dynamic>) return <String, Map<String, dynamic>>{};
    return <String, Map<String, dynamic>>{
      for (final dynamic a in list)
        if (a is Map<String, dynamic> && a['name'] is String)
          a['name'] as String: a,
    };
  }

  Future<List<dynamic>> _player({
    required String apiKey,
    required String steamId,
    required String appId,
  }) async {
    final Map<String, dynamic> data = await _get(
      '$_base/GetPlayerAchievements/v1/',
      <String, dynamic>{
        'key': apiKey,
        'steamid': steamId,
        'appid': appId,
        'l': 'english',
      },
    );
    final Object? stats = data['playerstats'];
    if (stats is! Map<String, dynamic>) {
      throw const SteamAchievementsException(SteamAchievementsReason.network);
    }
    final Object? achievements = stats['achievements'];
    if (achievements is List<dynamic>) return achievements;
    throw _fromError(stats['error'] as String?);
  }

  Future<Map<String, dynamic>> _get(
    String url,
    Map<String, dynamic> query,
  ) async {
    try {
      final Response<Map<String, dynamic>> response = await _dio
          .get<Map<String, dynamic>>(url, queryParameters: query);
      return response.data ?? const <String, dynamic>{};
    } on DioException catch (e) {
      final Object? body = e.response?.data;
      final Object? stats = body is Map<String, dynamic>
          ? body['playerstats']
          : null;
      if (stats is Map<String, dynamic>) {
        throw _fromError(stats['error'] as String?);
      }
      final int? status = e.response?.statusCode;
      if (status == 401 || status == 403) {
        throw SteamAchievementsException(
          SteamAchievementsReason.badKey,
          e.message,
        );
      }
      throw SteamAchievementsException(
        SteamAchievementsReason.network,
        e.message,
      );
    }
  }

  static SteamAchievementsException _fromError(String? error) {
    final String lower = error?.toLowerCase() ?? '';
    if (lower.contains('not public') || lower.contains('private')) {
      return SteamAchievementsException(
        SteamAchievementsReason.privateProfile,
        error,
      );
    }
    return SteamAchievementsException(
      SteamAchievementsReason.noAchievements,
      error,
    );
  }
}
