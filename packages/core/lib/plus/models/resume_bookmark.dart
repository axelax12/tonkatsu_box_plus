/// "Where was I?": what you need to pick an item back up after months away.
/// One per item; every field is optional free text.
class ResumeBookmark {
  const ResumeBookmark({
    required this.itemId,
    required this.updatedAt,
    this.position,
    this.objective,
    this.reminders,
    this.characters,
    this.notes,
  });

  factory ResumeBookmark.fromDb(Map<String, dynamic> row) {
    return ResumeBookmark(
      itemId: row['item_id'] as int,
      position: row['position'] as String?,
      objective: row['objective'] as String?,
      reminders: row['reminders'] as String?,
      characters: row['characters'] as String?,
      notes: row['notes'] as String?,
      updatedAt: DateTime.fromMillisecondsSinceEpoch(row['updated_at'] as int),
    );
  }

  final int itemId;

  /// Where you got to: a chapter, an episode, a mission.
  final String? position;

  /// What you were about to do next.
  final String? objective;

  /// Controls, mechanics or rules you would otherwise forget.
  final String? reminders;

  /// People and events worth remembering.
  final String? characters;

  final String? notes;

  final DateTime updatedAt;

  bool get isEmpty => <String?>[
        position,
        objective,
        reminders,
        characters,
        notes,
      ].every((String? field) => field == null || field.trim().isEmpty);

  Map<String, dynamic> toDb() {
    return <String, dynamic>{
      'item_id': itemId,
      'position': _blankToNull(position),
      'objective': _blankToNull(objective),
      'reminders': _blankToNull(reminders),
      'characters': _blankToNull(characters),
      'notes': _blankToNull(notes),
      'updated_at': updatedAt.millisecondsSinceEpoch,
    };
  }

  static String? _blankToNull(String? value) {
    final String? trimmed = value?.trim();
    return (trimmed == null || trimmed.isEmpty) ? null : trimmed;
  }

  ResumeBookmark copyWith({
    String? position,
    String? objective,
    String? reminders,
    String? characters,
    String? notes,
    DateTime? updatedAt,
  }) {
    return ResumeBookmark(
      itemId: itemId,
      position: position ?? this.position,
      objective: objective ?? this.objective,
      reminders: reminders ?? this.reminders,
      characters: characters ?? this.characters,
      notes: notes ?? this.notes,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
