import 'dart:io';

import 'package:core/database/database_opener.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// A real file through [openAppDatabase], so both chains and the foreign-key
/// pragma are exactly what the app gets.
class PlusTestDb {
  PlusTestDb._(this.db, this._dir);

  final Database db;
  final Directory _dir;

  static Future<PlusTestDb> open() async {
    sqfliteFfiInit();
    final Directory dir = Directory.systemTemp.createTempSync('plus_test');
    final Database db = await openAppDatabase(
      factory: databaseFactoryFfi,
      path: '${dir.path}/test.db',
    );
    return PlusTestDb._(db, dir);
  }

  Future<int> newItem({int externalId = 1}) async {
    final int collectionId = await db.insert('collections', <String, Object?>{
      'name': 'c$externalId',
      'author': 'a',
      'created_at': 1,
    });
    return db.insert('collection_items', <String, Object?>{
      'collection_id': collectionId,
      'external_id': externalId,
      'added_at': 1,
    });
  }

  Future<void> close() async {
    await db.close();
    if (_dir.existsSync()) _dir.deleteSync(recursive: true);
  }
}
