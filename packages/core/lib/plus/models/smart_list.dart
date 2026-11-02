import 'dart:convert';

import '../../models/item_status.dart';
import '../../models/media_type.dart';

enum SmartListSort {
  addedOldest('added_oldest'),
  addedNewest('added_newest'),
  shortestFirst('shortest_first'),
  ratingHighest('rating_highest'),
  nameAsc('name_asc');

  const SmartListSort(this.value);

  final String value;

  static SmartListSort fromString(String? value) {
    for (final SmartListSort sort in SmartListSort.values) {
      if (sort.value == value) return sort;
    }
    return SmartListSort.addedOldest;
  }
}

/// The filter behind a smart list. Every rule left empty or null matches
/// everything, so an empty rule set is the whole library.
class SmartListRules {
  const SmartListRules({
    this.mediaTypes = const <MediaType>{},
    this.statuses = const <ItemStatus>{},
    this.tagIds = const <int>{},
    this.collectionIds = const <int>{},
    this.minMinutes,
    this.maxMinutes,
    this.maxUnitsLeft,
    this.minRating,
    this.minAgeDays,
    this.favoritesOnly = false,
    this.neverStarted = false,
    this.text,
    this.sort = SmartListSort.addedOldest,
  });

  factory SmartListRules.fromJson(Map<String, dynamic> json) {
    Set<T> parseSet<T>(Object? raw, T? Function(Object?) parse) {
      if (raw is! List<dynamic>) return <T>{};
      return <T>{
        for (final Object? value in raw)
          if (parse(value) case final T parsed) parsed,
      };
    }

    return SmartListRules(
      mediaTypes: parseSet<MediaType>(
        json['media_types'],
        (Object? v) => v is String ? _mediaType(v) : null,
      ),
      statuses: parseSet<ItemStatus>(
        json['statuses'],
        (Object? v) => v is String ? ItemStatus.tryFromString(v) : null,
      ),
      tagIds: parseSet<int>(json['tag_ids'], (Object? v) => v is int ? v : null),
      collectionIds: parseSet<int>(
        json['collection_ids'],
        (Object? v) => v is int ? v : null,
      ),
      minMinutes: json['min_minutes'] as int?,
      maxMinutes: json['max_minutes'] as int?,
      maxUnitsLeft: json['max_units_left'] as int?,
      minRating: (json['min_rating'] as num?)?.toDouble(),
      minAgeDays: json['min_age_days'] as int?,
      favoritesOnly: json['favorites_only'] == true,
      neverStarted: json['never_started'] == true,
      text: json['text'] as String?,
      sort: SmartListSort.fromString(json['sort'] as String?),
    );
  }

  static MediaType? _mediaType(String value) {
    for (final MediaType type in MediaType.values) {
      if (type.value == value) return type;
    }
    return null;
  }

  final Set<MediaType> mediaTypes;
  final Set<ItemStatus> statuses;

  /// An item matches when it carries any of these tags.
  final Set<int> tagIds;
  final Set<int> collectionIds;

  /// Estimated length bounds, in minutes.
  final int? minMinutes;
  final int? maxMinutes;

  /// Episodes, chapters or pages still to go; only items with a known total.
  final int? maxUnitsLeft;

  final double? minRating;

  /// Waiting in the library at least this long.
  final int? minAgeDays;

  final bool favoritesOnly;
  final bool neverStarted;

  /// Case-insensitive match on title, genres and authors.
  final String? text;

  final SmartListSort sort;

  bool get needsLengths =>
      minMinutes != null ||
      maxMinutes != null ||
      sort == SmartListSort.shortestFirst;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      if (mediaTypes.isNotEmpty)
        'media_types': <String>[for (final MediaType t in mediaTypes) t.value],
      if (statuses.isNotEmpty)
        'statuses': <String>[for (final ItemStatus s in statuses) s.value],
      if (tagIds.isNotEmpty) 'tag_ids': tagIds.toList(),
      if (collectionIds.isNotEmpty) 'collection_ids': collectionIds.toList(),
      'min_minutes': ?minMinutes,
      'max_minutes': ?maxMinutes,
      'max_units_left': ?maxUnitsLeft,
      'min_rating': ?minRating,
      'min_age_days': ?minAgeDays,
      if (favoritesOnly) 'favorites_only': true,
      if (neverStarted) 'never_started': true,
      if (text?.trim().isNotEmpty ?? false) 'text': text?.trim(),
      'sort': sort.value,
    };
  }

  SmartListRules copyWith({
    Set<MediaType>? mediaTypes,
    Set<ItemStatus>? statuses,
    Set<int>? tagIds,
    Set<int>? collectionIds,
    int? minMinutes,
    bool clearMinMinutes = false,
    int? maxMinutes,
    bool clearMaxMinutes = false,
    int? maxUnitsLeft,
    bool clearMaxUnitsLeft = false,
    double? minRating,
    bool clearMinRating = false,
    int? minAgeDays,
    bool clearMinAgeDays = false,
    bool? favoritesOnly,
    bool? neverStarted,
    String? text,
    bool clearText = false,
    SmartListSort? sort,
  }) {
    return SmartListRules(
      mediaTypes: mediaTypes ?? this.mediaTypes,
      statuses: statuses ?? this.statuses,
      tagIds: tagIds ?? this.tagIds,
      collectionIds: collectionIds ?? this.collectionIds,
      minMinutes: clearMinMinutes ? null : (minMinutes ?? this.minMinutes),
      maxMinutes: clearMaxMinutes ? null : (maxMinutes ?? this.maxMinutes),
      maxUnitsLeft:
          clearMaxUnitsLeft ? null : (maxUnitsLeft ?? this.maxUnitsLeft),
      minRating: clearMinRating ? null : (minRating ?? this.minRating),
      minAgeDays: clearMinAgeDays ? null : (minAgeDays ?? this.minAgeDays),
      favoritesOnly: favoritesOnly ?? this.favoritesOnly,
      neverStarted: neverStarted ?? this.neverStarted,
      text: clearText ? null : (text ?? this.text),
      sort: sort ?? this.sort,
    );
  }
}

/// A saved, self-updating list such as "short games I own but never started".
class SmartList {
  const SmartList({
    required this.id,
    required this.name,
    required this.rules,
    required this.createdAt,
    required this.updatedAt,
    this.sortOrder = 0,
  });

  factory SmartList.fromDb(Map<String, dynamic> row) {
    Map<String, dynamic> rules = <String, dynamic>{};
    try {
      final Object? decoded = jsonDecode(row['rules'] as String? ?? '{}');
      if (decoded is Map<String, dynamic>) rules = decoded;
    } on FormatException {
      // A corrupt row degrades to "everything" instead of breaking the screen.
    }
    return SmartList(
      id: row['id'] as int,
      name: row['name'] as String,
      rules: SmartListRules.fromJson(rules),
      sortOrder: (row['sort_order'] as int?) ?? 0,
      createdAt: DateTime.fromMillisecondsSinceEpoch(row['created_at'] as int),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(row['updated_at'] as int),
    );
  }

  final int id;
  final String name;
  final SmartListRules rules;
  final int sortOrder;
  final DateTime createdAt;
  final DateTime updatedAt;

  Map<String, dynamic> toDb() {
    return <String, dynamic>{
      if (id != 0) 'id': id,
      'name': name,
      'rules': jsonEncode(rules.toJson()),
      'sort_order': sortOrder,
      'created_at': createdAt.millisecondsSinceEpoch,
      'updated_at': updatedAt.millisecondsSinceEpoch,
    };
  }

  SmartList copyWith({
    int? id,
    String? name,
    SmartListRules? rules,
    int? sortOrder,
    DateTime? updatedAt,
  }) {
    return SmartList(
      id: id ?? this.id,
      name: name ?? this.name,
      rules: rules ?? this.rules,
      sortOrder: sortOrder ?? this.sortOrder,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
