/// One sitting with an item: a game session, a reading or a viewing.
/// [endedAt] is null while the timer is still running.
class PlaySession {
  const PlaySession({
    required this.id,
    required this.itemId,
    required this.startedAt,
    required this.durationSeconds,
    required this.createdAt,
    this.playthroughId,
    this.endedAt,
    this.note,
    this.progressLabel,
  });

  factory PlaySession.fromDb(Map<String, dynamic> row) {
    final int? endedAtMs = row['ended_at'] as int?;
    return PlaySession(
      id: row['id'] as int,
      itemId: row['item_id'] as int,
      playthroughId: row['playthrough_id'] as int?,
      startedAt: DateTime.fromMillisecondsSinceEpoch(row['started_at'] as int),
      endedAt: endedAtMs != null
          ? DateTime.fromMillisecondsSinceEpoch(endedAtMs)
          : null,
      durationSeconds: (row['duration_seconds'] as int?) ?? 0,
      note: row['note'] as String?,
      progressLabel: row['progress_label'] as String?,
      createdAt: DateTime.fromMillisecondsSinceEpoch(row['created_at'] as int),
    );
  }

  final int id;
  final int itemId;
  final int? playthroughId;
  final DateTime startedAt;
  final DateTime? endedAt;
  final int durationSeconds;
  final String? note;
  final String? progressLabel;
  final DateTime createdAt;

  bool get isRunning => endedAt == null;

  /// A running session reports live time; a finished one its stored duration.
  Duration elapsed(DateTime now) {
    if (!isRunning) return Duration(seconds: durationSeconds);
    final Duration live = now.difference(startedAt);
    return live.isNegative ? Duration.zero : live;
  }

  /// Minutes this session adds to the item's total. Rounded, not floored, so
  /// a 59-second session still counts and deleting it subtracts the same.
  int get countedMinutes => roundToMinutes(durationSeconds);

  static int roundToMinutes(int seconds) =>
      seconds <= 0 ? 0 : (seconds + 30) ~/ 60;

  Map<String, dynamic> toDb() {
    return <String, dynamic>{
      if (id != 0) 'id': id,
      'item_id': itemId,
      'playthrough_id': playthroughId,
      'started_at': startedAt.millisecondsSinceEpoch,
      'ended_at': endedAt?.millisecondsSinceEpoch,
      'duration_seconds': durationSeconds,
      'note': note,
      'progress_label': progressLabel,
      'created_at': createdAt.millisecondsSinceEpoch,
    };
  }

  PlaySession copyWith({
    int? id,
    int? playthroughId,
    bool clearPlaythrough = false,
    DateTime? startedAt,
    DateTime? endedAt,
    int? durationSeconds,
    String? note,
    bool clearNote = false,
    String? progressLabel,
    bool clearProgressLabel = false,
  }) {
    return PlaySession(
      id: id ?? this.id,
      itemId: itemId,
      playthroughId:
          clearPlaythrough ? null : (playthroughId ?? this.playthroughId),
      startedAt: startedAt ?? this.startedAt,
      endedAt: endedAt ?? this.endedAt,
      durationSeconds: durationSeconds ?? this.durationSeconds,
      note: clearNote ? null : (note ?? this.note),
      progressLabel:
          clearProgressLabel ? null : (progressLabel ?? this.progressLabel),
      createdAt: createdAt,
    );
  }
}
