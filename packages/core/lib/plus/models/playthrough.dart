enum PlaythroughStatus {
  inProgress('in_progress'),
  completed('completed'),
  dropped('dropped');

  const PlaythroughStatus(this.value);

  final String value;

  /// Unknown values (a newer build, a hand-edited file) read as in progress.
  static PlaythroughStatus fromString(String? value) {
    for (final PlaythroughStatus status in PlaythroughStatus.values) {
      if (status.value == value) return status;
    }
    return PlaythroughStatus.inProgress;
  }
}

/// One run through an item — first playthrough, NG+, a reread years later —
/// each with its own dates, platform, rating and review.
class Playthrough {
  const Playthrough({
    required this.id,
    required this.itemId,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
    this.label,
    this.platformId,
    this.startedAt,
    this.finishedAt,
    this.rating,
    this.review,
  });

  factory Playthrough.fromDb(Map<String, dynamic> row) {
    return Playthrough(
      id: row['id'] as int,
      itemId: row['item_id'] as int,
      label: row['label'] as String?,
      platformId: row['platform_id'] as int?,
      status: PlaythroughStatus.fromString(row['status'] as String?),
      startedAt: _dateOrNull(row['started_at']),
      finishedAt: _dateOrNull(row['finished_at']),
      rating: (row['rating'] as num?)?.toDouble(),
      review: row['review'] as String?,
      createdAt: DateTime.fromMillisecondsSinceEpoch(row['created_at'] as int),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(row['updated_at'] as int),
    );
  }

  static DateTime? _dateOrNull(Object? ms) =>
      ms is int ? DateTime.fromMillisecondsSinceEpoch(ms) : null;

  static const double minRating = 1.0;
  static const double maxRating = 10.0;

  static bool isValidRating(double? rating) =>
      rating == null ||
      (rating.isFinite && rating >= minRating && rating <= maxRating);

  final int id;
  final int itemId;
  final String? label;
  final int? platformId;
  final PlaythroughStatus status;
  final DateTime? startedAt;
  final DateTime? finishedAt;
  final double? rating;
  final String? review;
  final DateTime createdAt;
  final DateTime updatedAt;

  bool get hasReview => review?.trim().isNotEmpty ?? false;

  Map<String, dynamic> toDb() {
    return <String, dynamic>{
      if (id != 0) 'id': id,
      'item_id': itemId,
      'label': label,
      'platform_id': platformId,
      'status': status.value,
      'started_at': startedAt?.millisecondsSinceEpoch,
      'finished_at': finishedAt?.millisecondsSinceEpoch,
      'rating': rating,
      'review': review,
      'created_at': createdAt.millisecondsSinceEpoch,
      'updated_at': updatedAt.millisecondsSinceEpoch,
    };
  }

  Playthrough copyWith({
    int? id,
    String? label,
    bool clearLabel = false,
    int? platformId,
    bool clearPlatform = false,
    PlaythroughStatus? status,
    DateTime? startedAt,
    bool clearStartedAt = false,
    DateTime? finishedAt,
    bool clearFinishedAt = false,
    double? rating,
    bool clearRating = false,
    String? review,
    bool clearReview = false,
    DateTime? updatedAt,
  }) {
    return Playthrough(
      id: id ?? this.id,
      itemId: itemId,
      label: clearLabel ? null : (label ?? this.label),
      platformId: clearPlatform ? null : (platformId ?? this.platformId),
      status: status ?? this.status,
      startedAt: clearStartedAt ? null : (startedAt ?? this.startedAt),
      finishedAt: clearFinishedAt ? null : (finishedAt ?? this.finishedAt),
      rating: clearRating ? null : (rating ?? this.rating),
      review: clearReview ? null : (review ?? this.review),
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
