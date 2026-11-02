import 'media_path.dart';

/// A tag the user put on a work under one aspect: "melancholic" atmosphere,
/// "orbital station" setting.
class ItemAspectTag {
  const ItemAspectTag({
    required this.id,
    required this.itemId,
    required this.aspect,
    required this.label,
    required this.createdAt,
  });

  factory ItemAspectTag.fromDb(Map<String, dynamic> row) {
    return ItemAspectTag(
      id: row['id'] as int,
      itemId: row['item_id'] as int,
      aspect:
          PathAspect.tryFromString(row['aspect'] as String?) ??
          PathAspect.themes,
      label: row['label'] as String,
      createdAt: DateTime.fromMillisecondsSinceEpoch(row['created_at'] as int),
    );
  }

  final int id;
  final int itemId;
  final PathAspect aspect;
  final String label;
  final DateTime createdAt;

  Map<String, dynamic> toDb() {
    return <String, dynamic>{
      if (id != 0) 'id': id,
      'item_id': itemId,
      'aspect': aspect.value,
      'label': label,
      'created_at': createdAt.millisecondsSinceEpoch,
    };
  }
}
