enum JournalEntryKind {
  note('note'),
  quote('quote'),
  impression('impression'),
  milestone('milestone'),
  screenshot('screenshot');

  const JournalEntryKind(this.value);

  final String value;

  static JournalEntryKind fromString(String? value) {
    for (final JournalEntryKind kind in JournalEntryKind.values) {
      if (kind.value == value) return kind;
    }
    return JournalEntryKind.note;
  }
}

/// A dated moment in the experience diary: a thought, a quote, a screenshot.
/// [progressLabel] says where it happened ("Chapter 12", "Act II").
class JournalEntry {
  const JournalEntry({
    required this.id,
    required this.itemId,
    required this.kind,
    required this.isSpoiler,
    required this.occurredAt,
    required this.createdAt,
    required this.updatedAt,
    this.playthroughId,
    this.sessionId,
    this.body,
    this.imagePath,
    this.progressLabel,
  });

  factory JournalEntry.fromDb(Map<String, dynamic> row) {
    return JournalEntry(
      id: row['id'] as int,
      itemId: row['item_id'] as int,
      playthroughId: row['playthrough_id'] as int?,
      sessionId: row['session_id'] as int?,
      kind: JournalEntryKind.fromString(row['kind'] as String?),
      body: row['body'] as String?,
      imagePath: row['image_path'] as String?,
      progressLabel: row['progress_label'] as String?,
      isSpoiler: (row['is_spoiler'] as int?) == 1,
      occurredAt: DateTime.fromMillisecondsSinceEpoch(
        row['occurred_at'] as int,
      ),
      createdAt: DateTime.fromMillisecondsSinceEpoch(row['created_at'] as int),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(row['updated_at'] as int),
    );
  }

  final int id;
  final int itemId;
  final int? playthroughId;
  final int? sessionId;
  final JournalEntryKind kind;
  final String? body;
  final String? imagePath;
  final String? progressLabel;
  final bool isSpoiler;
  final DateTime occurredAt;
  final DateTime createdAt;
  final DateTime updatedAt;

  bool get isEmpty =>
      (body?.trim().isEmpty ?? true) && (imagePath?.isEmpty ?? true);

  Map<String, dynamic> toDb() {
    return <String, dynamic>{
      if (id != 0) 'id': id,
      'item_id': itemId,
      'playthrough_id': playthroughId,
      'session_id': sessionId,
      'kind': kind.value,
      'body': body,
      'image_path': imagePath,
      'progress_label': progressLabel,
      'is_spoiler': isSpoiler ? 1 : 0,
      'occurred_at': occurredAt.millisecondsSinceEpoch,
      'created_at': createdAt.millisecondsSinceEpoch,
      'updated_at': updatedAt.millisecondsSinceEpoch,
    };
  }

  JournalEntry copyWith({
    int? id,
    int? playthroughId,
    bool clearPlaythrough = false,
    int? sessionId,
    bool clearSession = false,
    JournalEntryKind? kind,
    String? body,
    bool clearBody = false,
    String? imagePath,
    bool clearImage = false,
    String? progressLabel,
    bool clearProgressLabel = false,
    bool? isSpoiler,
    DateTime? occurredAt,
    DateTime? updatedAt,
  }) {
    return JournalEntry(
      id: id ?? this.id,
      itemId: itemId,
      playthroughId: clearPlaythrough
          ? null
          : (playthroughId ?? this.playthroughId),
      sessionId: clearSession ? null : (sessionId ?? this.sessionId),
      kind: kind ?? this.kind,
      body: clearBody ? null : (body ?? this.body),
      imagePath: clearImage ? null : (imagePath ?? this.imagePath),
      progressLabel: clearProgressLabel
          ? null
          : (progressLabel ?? this.progressLabel),
      isSpoiler: isSpoiler ?? this.isSpoiler,
      occurredAt: occurredAt ?? this.occurredAt,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
