import 'package:sqflite_common/sqlite_api.dart';

/// One step of the fork's own schema chain. Takes a [DatabaseExecutor] so
/// each step runs inside the transaction that also stamps its version.
abstract class PlusMigration {
  const PlusMigration();

  int get version;

  String get description;

  Future<void> migrate(DatabaseExecutor db);
}
