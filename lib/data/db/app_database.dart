import 'package:path/path.dart' as path;
import 'package:sqflite/sqflite.dart';

import 'database_migrations.dart';
import 'store_seeder.dart';

class AppDatabase {
  AppDatabase._();

  static final AppDatabase instance = AppDatabase._();
  static const databaseName = 'tetes.db';

  Database? _database;
  Future<Database>? _opening;

  Future<Database> open() {
    final existingDatabase = _database;
    if (existingDatabase != null && existingDatabase.isOpen) {
      return Future.value(existingDatabase);
    }

    final existingOpening = _opening;
    if (existingOpening != null) {
      return existingOpening;
    }

    final opening = _openDatabase();
    _opening = opening;
    return opening.whenComplete(() {
      if (identical(_opening, opening)) {
        _opening = null;
      }
    });
  }

  Future<Database> _openDatabase() async {
    final databasePath = path.join(await getDatabasesPath(), databaseName);
    final database = await openDatabase(
      databasePath,
      version: DatabaseMigrations.schemaVersion,
      onConfigure: configureDatabase,
      onCreate: DatabaseMigrations.create,
      onUpgrade: DatabaseMigrations.migrate,
    );

    try {
      await const StoreSeeder().seed(database);
    } catch (_) {
      await database.close();
      rethrow;
    }

    _database = database;
    return database;
  }

  static Future<void> configureDatabase(Database database) async {
    await database.execute('PRAGMA foreign_keys = ON');
  }
}
