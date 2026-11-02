import '../../models/media_type.dart';

enum GoalMetric {
  /// Items finished during the year.
  completed('completed'),

  /// Hours logged in sessions during the year.
  hours('hours'),

  /// Items finished during the year that were already waiting before it began.
  backlogCleared('backlog_cleared');

  const GoalMetric(this.value);

  final String value;

  static GoalMetric fromString(String? value) {
    for (final GoalMetric metric in GoalMetric.values) {
      if (metric.value == value) return metric;
    }
    return GoalMetric.completed;
  }
}

/// A yearly target such as "30 games finished" or "200 hours". A null
/// [mediaType] counts every type.
class YearlyGoal {
  const YearlyGoal({
    required this.id,
    required this.year,
    required this.metric,
    required this.target,
    required this.createdAt,
    required this.updatedAt,
    this.mediaType,
  });

  factory YearlyGoal.fromDb(Map<String, dynamic> row) {
    final String? type = row['media_type'] as String?;
    return YearlyGoal(
      id: row['id'] as int,
      year: row['year'] as int,
      metric: GoalMetric.fromString(row['metric'] as String?),
      mediaType: type == null ? null : MediaType.fromString(type),
      target: row['target'] as int,
      createdAt: DateTime.fromMillisecondsSinceEpoch(row['created_at'] as int),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(row['updated_at'] as int),
    );
  }

  static const int minTarget = 1;

  final int id;
  final int year;
  final GoalMetric metric;
  final MediaType? mediaType;
  final int target;
  final DateTime createdAt;
  final DateTime updatedAt;

  Map<String, dynamic> toDb() {
    return <String, dynamic>{
      if (id != 0) 'id': id,
      'year': year,
      'metric': metric.value,
      'media_type': mediaType?.value,
      'target': target < minTarget ? minTarget : target,
      'created_at': createdAt.millisecondsSinceEpoch,
      'updated_at': updatedAt.millisecondsSinceEpoch,
    };
  }

  YearlyGoal copyWith({
    int? id,
    int? year,
    GoalMetric? metric,
    MediaType? mediaType,
    bool clearMediaType = false,
    int? target,
    DateTime? updatedAt,
  }) {
    return YearlyGoal(
      id: id ?? this.id,
      year: year ?? this.year,
      metric: metric ?? this.metric,
      mediaType: clearMediaType ? null : (mediaType ?? this.mediaType),
      target: target ?? this.target,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
