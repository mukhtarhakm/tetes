import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:tetes/data/db/store_seeder.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(sqfliteFfiInit);

  const valid = {
    'id': 'one',
    'name': 'Toko uji',
    'store_type': 'roastery',
    'latitude': -7.8,
    'longitude': 110.4,
  };

  test('seed hanya menerima jenis dan koordinat dalam batas', () {
    expect(StoreSeeder.validStore(valid), isNotNull);
    expect(StoreSeeder.validStore({...valid, 'store_type': 'kedai'}), isNull);
    expect(StoreSeeder.validStore({...valid, 'latitude': -8.06}), isNull);
    expect(StoreSeeder.validStore({...valid, 'longitude': 110.61}), isNull);
    expect(StoreSeeder.validStore({...valid, 'latitude': double.nan}), isNull);
    expect(StoreSeeder.validStore('bukan toko'), isNull);
  });

  test('seed bawaan idempoten dan tidak menimpa toko yang ada', () async {
    final database = await databaseFactoryFfi.openDatabase(inMemoryDatabasePath);
    addTearDown(database.close);
    await database.execute('''CREATE TABLE stores (
      id TEXT PRIMARY KEY, name TEXT NOT NULL, store_type TEXT NOT NULL,
      latitude REAL NOT NULL, longitude REAL NOT NULL,
      address TEXT, notes TEXT)''');
    const seeder = StoreSeeder();
    await seeder.seed(database);
    final first = await database.query('stores');
    expect(first.length, 15);
    await database.update('stores', {'name': 'Disunting lokal'},
        where: 'id = ?', whereArgs: [first.first['id']]);
    await seeder.seed(database);
    final second = await database.query('stores');
    expect(second.length, first.length);
    expect(second.first['name'], 'Disunting lokal');
  });
}
