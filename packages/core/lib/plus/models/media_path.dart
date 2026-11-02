enum PathKind {
  /// One franchise across media: "Gundam", "The Witcher".
  universe('universe'),

  /// A thread through unrelated works: "cosmic horror", "rural Japan".
  theme('theme');

  const PathKind(this.value);

  final String value;

  static PathKind fromString(String? value) =>
      value == theme.value ? theme : universe;
}

enum PathOrder {
  release('release'),
  chronological('chronological'),
  recommended('recommended');

  const PathOrder(this.value);

  final String value;

  static PathOrder fromString(String? value) {
    for (final PathOrder o in PathOrder.values) {
      if (o.value == value) return o;
    }
    return PathOrder.recommended;
  }
}

/// What a theme path is about for one of its works.
enum PathAspect {
  atmosphere('atmosphere'),
  setting('setting'),
  themes('themes'),
  structure('structure');

  const PathAspect(this.value);

  final String value;

  static PathAspect? tryFromString(String? value) {
    for (final PathAspect a in PathAspect.values) {
      if (a.value == value) return a;
    }
    return null;
  }
}

class MediaPath {
  const MediaPath({
    required this.id,
    required this.name,
    required this.kind,
    required this.defaultOrder,
    required this.createdAt,
    required this.updatedAt,
    this.description,
  });

  factory MediaPath.fromDb(Map<String, dynamic> row) {
    return MediaPath(
      id: row['id'] as int,
      name: row['name'] as String,
      kind: PathKind.fromString(row['kind'] as String?),
      description: row['description'] as String?,
      defaultOrder: PathOrder.fromString(row['default_order'] as String?),
      createdAt: DateTime.fromMillisecondsSinceEpoch(row['created_at'] as int),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(row['updated_at'] as int),
    );
  }

  final int id;
  final String name;
  final PathKind kind;
  final String? description;
  final PathOrder defaultOrder;
  final DateTime createdAt;
  final DateTime updatedAt;

  Map<String, dynamic> toDb() {
    return <String, dynamic>{
      if (id != 0) 'id': id,
      'name': name,
      'kind': kind.value,
      'description': description,
      'default_order': defaultOrder.value,
      'created_at': createdAt.millisecondsSinceEpoch,
      'updated_at': updatedAt.millisecondsSinceEpoch,
    };
  }

  MediaPath copyWith({
    int? id,
    String? name,
    PathKind? kind,
    String? description,
    bool clearDescription = false,
    PathOrder? defaultOrder,
    DateTime? updatedAt,
  }) {
    return MediaPath(
      id: id ?? this.id,
      name: name ?? this.name,
      kind: kind ?? this.kind,
      description: clearDescription ? null : (description ?? this.description),
      defaultOrder: defaultOrder ?? this.defaultOrder,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

/// One stop on a path. Each order keeps its own position, so the same works
/// can be walked by release date, in story order or as recommended.
class PathEntry {
  const PathEntry({
    required this.id,
    required this.pathId,
    required this.itemId,
    required this.releasePos,
    required this.chronoPos,
    required this.recommendedPos,
    this.optional = false,
    this.spoiler = false,
    this.note,
    this.aspect,
  });

  factory PathEntry.fromDb(Map<String, dynamic> row) {
    return PathEntry(
      id: row['id'] as int,
      pathId: row['path_id'] as int,
      itemId: row['item_id'] as int,
      releasePos: (row['release_pos'] as int?) ?? 0,
      chronoPos: (row['chrono_pos'] as int?) ?? 0,
      recommendedPos: (row['recommended_pos'] as int?) ?? 0,
      optional: (row['optional'] as int?) == 1,
      spoiler: (row['spoiler'] as int?) == 1,
      note: row['note'] as String?,
      aspect: PathAspect.tryFromString(row['aspect'] as String?),
    );
  }

  final int id;
  final int pathId;
  final int itemId;
  final int releasePos;
  final int chronoPos;
  final int recommendedPos;

  /// Side stories: shown, but not needed for the path to count as done.
  final bool optional;

  /// Kept as "???" until every earlier required stop is finished.
  final bool spoiler;

  /// Why this work is here, or where it fits.
  final String? note;
  final PathAspect? aspect;

  int positionFor(PathOrder order) {
    switch (order) {
      case PathOrder.release:
        return releasePos;
      case PathOrder.chronological:
        return chronoPos;
      case PathOrder.recommended:
        return recommendedPos;
    }
  }

  Map<String, dynamic> toDb() {
    return <String, dynamic>{
      if (id != 0) 'id': id,
      'path_id': pathId,
      'item_id': itemId,
      'release_pos': releasePos,
      'chrono_pos': chronoPos,
      'recommended_pos': recommendedPos,
      'optional': optional ? 1 : 0,
      'spoiler': spoiler ? 1 : 0,
      'note': note,
      'aspect': aspect?.value,
    };
  }

  PathEntry copyWith({
    int? id,
    int? releasePos,
    int? chronoPos,
    int? recommendedPos,
    bool? optional,
    bool? spoiler,
    String? note,
    bool clearNote = false,
    PathAspect? aspect,
    bool clearAspect = false,
  }) {
    return PathEntry(
      id: id ?? this.id,
      pathId: pathId,
      itemId: itemId,
      releasePos: releasePos ?? this.releasePos,
      chronoPos: chronoPos ?? this.chronoPos,
      recommendedPos: recommendedPos ?? this.recommendedPos,
      optional: optional ?? this.optional,
      spoiler: spoiler ?? this.spoiler,
      note: clearNote ? null : (note ?? this.note),
      aspect: clearAspect ? null : (aspect ?? this.aspect),
    );
  }

  PathEntry withPosition(PathOrder order, int position) {
    switch (order) {
      case PathOrder.release:
        return copyWith(releasePos: position);
      case PathOrder.chronological:
        return copyWith(chronoPos: position);
      case PathOrder.recommended:
        return copyWith(recommendedPos: position);
    }
  }
}
