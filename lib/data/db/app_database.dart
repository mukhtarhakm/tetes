import 'package:path/path.dart' as path;
import 'package:sqflite/sqflite.dart';

import 'database_migrations.dart';
import 'store_seeder.dart';

class AppDatabase {
  AppDatabase._();

  static final AppDatabase instance = AppDatabase._();
  static const databaseName = 'tetes.db';

  Database? _database;

  Future<Database> open() async {
    final existingDatabase = _database;
    if (existingDatabase != null && existingDatabase.isOpen) {
      return existingDatabase;
    }

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
