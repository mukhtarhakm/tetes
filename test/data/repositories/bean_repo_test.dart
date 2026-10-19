import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:tetes/data/db/app_database.dart';
import 'package:tetes/data/db/database_migrations.dart';
import 'package:tetes/data/repositories/bean_repo.dart';
import 'package:tetes/features/beans/bean_model.dart';
import 'package:tetes/features/beans/fx_conversion.dart';

void main() {
  late Database database;
  late BeanRepository repository;

  setUpAll(sqfliteFfiInit);

  setUp(() async {
    database = await databaseFactoryFfi.openDatabase(
      inMemoryDatabasePath,
      options: OpenDatabaseOptions(
        version: DatabaseMigrations.schemaVersion,
        onConfigure: AppDatabase.configureDatabase,
        onCreate: DatabaseMigrations.create,
      ),
    );
    repository = BeanRepository(database);
  });

  tearDown(() async {
    await database.close();
  });

  test('stok tersisa mengurangi hanya dosis seduhan aktif', () async {
    final beanId = await repository.create(
      userId: 'user-1',
      draft: _draft(stock: 100),
    );
    await database.insert('brews', _brew(id: 'brew-active', beanId: beanId));
    await database.insert(
      'brews',
      _brew(id: 'brew-canceled', beanId: beanId, seq: 2, canceled: true),
    );

    final bean = await repository.findById(userId: 'user-1', id: beanId);

    expect(bean, isNotNull);
    expect(bean!.remainingStockG, 85);
    expect(bean.brewCount, 2);
  });

  test('daftar dibatasi user dan menyembunyikan biji terarsip', () async {
    final activeId = await repository.create(
      userId: 'user-1',
      draft: _draft(name: 'Aktif'),
    );
    final archivedId = await repository.create(
      userId: 'user-1',
      draft: _draft(name: 'Arsip'),
    );
    await repository.create(
      userId: 'user-2',
      draft: _draft(name: 'Milik lain'),
    );
    await repository.archive(userId: 'user-1', id: archivedId);

    final beans = await repository.listActive('user-1');

    expect(beans.map((bean) => bean.id), [activeId]);
  });

  test('simpan mengurutkan tag dan menyimpan hasil kurs', () async {
    final beanId = await repository.create(
      userId: 'user-1',
      draft: BeanDraft(
        name: 'Campuran',
        species: BeanSpecies.campuran,
        arabicaPercent: 70,
        isSelfRoasted: true,
        process: BeanProcess.lainnya,
        processCustom: 'anaerobik',
        packSizeG: 250,
        priceOriginal: 100000,
        currency: 'IDR',
        fxRate: 1,
        fxDate: '2026-10-19',
        priceIdrPerKg: 400000,
        initialStockG: 250,
        roasteryNotesTags: const ['manis', 'beri merah', 'asam'],
      ),
    );

    final row = (await database.query(
      'beans',
      where: 'id = ?',
      whereArgs: [beanId],
    )).single;

    expect(row['is_self_roasted'], 1);
    expect(row['roastery'], BeanDefaults.selfRoasteryName);
    expect(row['pack_size_g'], 250);
    expect(row['process'], 'lainnya');
    expect(row['process_custom'], 'anaerobik');
    expect(row['roastery_notes_tags'], 'asam,beri merah,manis');
    expect(row['fx_rate'], 1);
    expect(row['fx_date'], '2026-10-19');
    expect(row['price_idr_per_kg'], 400000);
    expect(row['sync_status'], 'pending');

    final bean = await repository.findById(userId: 'user-1', id: beanId);
    expect(bean!.roasteryNotesTags, ['asam', 'beri merah', 'manis']);

    await database.update(
      'beans',
      {'sync_status': 'synced'},
      where: 'id = ?',
      whereArgs: [beanId],
    );
    await repository.update(
      userId: 'user-1',
      id: beanId,
      draft: _draft(name: 'Nama baru'),
    );
    final updatedRow = (await database.query(
      'beans',
      where: 'id = ?',
      whereArgs: [beanId],
    )).single;
    expect(updatedRow['sync_status'], 'pending');
  });

  test(
    'biji lama dengan harga tanpa ukuran kemasan tetap dapat dibaca',
    () async {
      await database.insert('beans', {
        'id': 'legacy-bean',
        'user_id': 'user-1',
        'name': 'Biji lama',
        'species': 'arabika',
        'price_original': 75000,
        'currency': 'IDR',
        'initial_stock_g': 200,
        'roastery_notes_tags': 'cokelat,unik lama',
        'created_at': '2026-10-19T00:00:00Z',
        'updated_at': '2026-10-19T00:00:00Z',
      });

      final bean = await repository.findById(
        userId: 'user-1',
        id: 'legacy-bean',
      );

      expect(bean, isNotNull);
      expect(bean!.packSizeG, isNull);
      expect(bean.priceOriginal, 75000);
      expect(bean.roasteryNotesTags, ['cokelat', 'unik lama']);
    },
  );

  test('cache kurs dipisahkan per pengguna dan mata uang', () async {
    await repository.writeFxCache(
      userId: 'user-1',
      quote: const FxQuote(
        currency: 'USD',
        rate: 18031,
        date: '2026-10-16',
        source: FxQuoteSource.network,
      ),
    );
    await repository.writeFxCache(
      userId: 'user-1',
      quote: const FxQuote(
        currency: 'EUR',
        rate: 20100,
        date: '2026-10-16',
        source: FxQuoteSource.network,
      ),
    );

    final usd = await repository.readFxCache(userId: 'user-1', currency: 'USD');
    final eur = await repository.readFxCache(userId: 'user-1', currency: 'EUR');
    final missingCurrency = await repository.readFxCache(
      userId: 'user-1',
      currency: 'JPY',
    );
    final otherUser = await repository.readFxCache(
      userId: 'user-2',
      currency: 'USD',
    );

    expect(usd?.rate, 18031);
    expect(eur?.rate, 20100);
    expect(missingCurrency, isNull);
    expect(otherUser, isNull);
  });
}

BeanDraft _draft({String name = 'Biji Uji', double stock = 200}) {
  return BeanDraft(
    name: name,
    species: BeanSpecies.arabika,
    isSelfRoasted: false,
    initialStockG: stock,
    roasteryNotesTags: const [],
  );
}

Map<String, Object> _brew({
  required String id,
  required String beanId,
  int seq = 1,
  bool canceled = false,
}) {
  return {
    'id': id,
    'user_id': 'user-1',
    'seq': seq,
    'bean_id': beanId,
    'brewed_at_utc': '2026-10-19T00:00:00Z',
    'dose_g': 15.0,
    'ratio': 15.0,
    'water_temp_c': 92,
    'grind': 'sedang',
    'total_time_s': 180,
    'taste_score': 4,
    'taste_tags': 'manis',
    'status': canceled ? 'dibatalkan' : 'aktif',
    'prev_hash': '0',
    'hash': 'hash-$id',
    'created_at': '2026-10-19T00:00:00Z',
  };
}
