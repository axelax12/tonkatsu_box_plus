import 'dart:convert';

import '../../models/collection_item.dart';
import '../../models/media_type.dart';
import '../models/media_path.dart';

class PathExchangeException implements Exception {
  const PathExchangeException(this.message);

  final String message;

  @override
  String toString() => 'PathExchangeException: $message';
}

/// One stop as shared: catalog ids instead of row ids, which mean nothing in
/// someone else's library.
class SharedStop {
  const SharedStop({
    required this.mediaType,
    required this.externalId,
    required this.title,
    required this.releasePos,
    required this.chronoPos,
    required this.recommendedPos,
    this.optional = false,
    this.spoiler = false,
    this.note,
    this.aspect,
  });

  final MediaType mediaType;
  final int externalId;
  final String title;
  final int releasePos;
  final int chronoPos;
  final int recommendedPos;
  final bool optional;
  final bool spoiler;
  final String? note;
  final PathAspect? aspect;
}

class SharedPath {
  const SharedPath({
    required this.name,
    required this.kind,
    required this.defaultOrder,
    required this.stops,
    this.description,
  });

  final String name;
  final PathKind kind;
  final String? description;
  final PathOrder defaultOrder;
  final List<SharedStop> stops;
}

/// Stops of a shared path matched against a library.
class PathMatch {
  const PathMatch({required this.found, required this.missing});

  /// Library item per stop that the library holds.
  final List<({SharedStop stop, CollectionItem item})> found;
  final List<SharedStop> missing;
}

/// Paths travel as plain JSON text, so a guide can be pasted into any chat.
abstract final class PathExchange {
  static const String format = 'tonkatsu-plus-path';
  static const int version = 1;

  static String encode(
    MediaPath path,
    List<PathEntry> entries,
    Map<int, CollectionItem> items,
  ) {
    final List<Map<String, Object?>> stops = <Map<String, Object?>>[
      for (final PathEntry e in entries)
        if (items[e.itemId] case final CollectionItem item)
          <String, Object?>{
            'type': item.mediaType.value,
            'id': item.externalId,
            'title': item.itemName,
            'release': e.releasePos,
            'chrono': e.chronoPos,
            'recommended': e.recommendedPos,
            if (e.optional) 'optional': true,
            if (e.spoiler) 'spoiler': true,
            if (e.note != null) 'note': e.note,
            if (e.aspect != null) 'aspect': e.aspect?.value,
          },
    ];
    return jsonEncode(<String, Object?>{
      'format': format,
      'version': version,
      'name': path.name,
      'kind': path.kind.value,
      if (path.description != null) 'description': path.description,
      'order': path.defaultOrder.value,
      'stops': stops,
    });
  }

  static SharedPath decode(String text) {
    final Object? decoded;
    try {
      decoded = jsonDecode(text.trim());
    } on FormatException {
      throw const PathExchangeException('Not a shared path');
    }
    if (decoded is! Map<String, dynamic> || decoded['format'] != format) {
      throw const PathExchangeException('Not a shared path');
    }
    final int fileVersion = (decoded['version'] as int?) ?? 0;
    if (fileVersion > version) {
      throw const PathExchangeException('Shared by a newer version');
    }
    final String name = ((decoded['name'] as String?) ?? '').trim();
    if (name.isEmpty) throw const PathExchangeException('Path has no name');
    final List<SharedStop> stops = <SharedStop>[];
    for (final Object? raw
        in (decoded['stops'] as List<dynamic>?) ?? const <dynamic>[]) {
      if (raw is! Map<String, dynamic>) continue;
      final MediaType? type = MediaType.values
          .where((MediaType t) => t.value == raw['type'])
          .firstOrNull;
      final Object? id = raw['id'];
      if (type == null || id is! int) continue;
      stops.add(
        SharedStop(
          mediaType: type,
          externalId: id,
          title: (raw['title'] as String?) ?? '',
          releasePos: (raw['release'] as int?) ?? stops.length,
          chronoPos: (raw['chrono'] as int?) ?? stops.length,
          recommendedPos: (raw['recommended'] as int?) ?? stops.length,
          optional: raw['optional'] == true,
          spoiler: raw['spoiler'] == true,
          note: raw['note'] as String?,
          aspect: PathAspect.tryFromString(raw['aspect'] as String?),
        ),
      );
    }
    return SharedPath(
      name: name,
      kind: PathKind.fromString(decoded['kind'] as String?),
      description: decoded['description'] as String?,
      defaultOrder: PathOrder.fromString(decoded['order'] as String?),
      stops: stops,
    );
  }

  /// A work held in several collections matches its first copy.
  static PathMatch match(SharedPath shared, Iterable<CollectionItem> library) {
    final Map<String, CollectionItem> byKey = <String, CollectionItem>{};
    for (final CollectionItem item in library) {
      byKey.putIfAbsent(
        '${item.mediaType.value}:${item.externalId}',
        () => item,
      );
    }
    final List<({SharedStop stop, CollectionItem item})> found =
        <({SharedStop stop, CollectionItem item})>[];
    final List<SharedStop> missing = <SharedStop>[];
    final Set<int> used = <int>{};
    for (final SharedStop stop in shared.stops) {
      final CollectionItem? item =
          byKey['${stop.mediaType.value}:${stop.externalId}'];
      if (item == null) {
        missing.add(stop);
      } else if (used.add(item.id)) {
        found.add((stop: stop, item: item));
      }
    }
    return PathMatch(found: found, missing: missing);
  }
}
