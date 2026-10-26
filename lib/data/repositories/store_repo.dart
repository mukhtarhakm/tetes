import 'package:sqflite/sqflite.dart';

import '../../features/explore/store_model.dart';

class StoreRepository {
  const StoreRepository(this._database);

  final Database _database;

  Future<List<StoreItem>> list() async {
    final rows = await _database.query(
      'stores',
      orderBy: 'name COLLATE NOCASE',
    );
    return rows.map(StoreItem.fromMap).toList(growable: false);
  }
}
