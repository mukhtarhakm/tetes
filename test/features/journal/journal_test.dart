import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:tetes/core/utils/hash.dart';
import 'package:tetes/data/db/app_database.dart';
import 'package:tetes/data/db/database_migrations.dart';
import 'package:tetes/data/repositories/bean_repo.dart';
import 'package:tetes/data/repositories/brew_repo.dart';
import 'package:tetes/features/beans/bean_model.dart';
import 'package:tetes/features/journal/journal_model.dart';

void main() {
  late Database database;
  late BeanRepository beanRepository;
  late BrewRepository brewRepository;

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
    beanRepository = BeanRepository(database);
    brewRepository = BrewRepository(database);
  });

  tearDown(() async {
    await database.close();
  });

  Future<String> createTestBean({
    String userId = 'user-1',
    String name = 'Gayo Arabica',
    String? roastery = 'Roastery Utama',
    double initialStockG = 250,
    double? priceOriginal = 100000,
    double? packSizeG = 250,
  }) {
    return beanRepository.create(
      userId: userId,
      draft: BeanDraft(
        name: name,
        species: BeanSpecies.arabika,
        isSelfRoasted: false,
        roastery: roastery,
        initialStockG: initialStockG,
        packSizeG: packSizeG,
        priceOriginal: priceOriginal,
        currency: priceOriginal == null ? null : 'IDR',
        priceIdrPerKg:
            priceOriginal != null && packSizeG != null && packSizeG > 0
                ? priceOriginal / packSizeG * 1000
                : null,
        roasteryNotesTags: const ['asam', 'buah'],
      ),
    );
  }

  Future<void> insertTestBrew({
    required String id,
    String userId = 'user-1',
    required int seq,
    required String beanId,
    required String brewedAtUtc,
    double doseG = 15.0,
    double ratio = 16.0,
    int waterTempC = 92,
    String grind = 'sedang',
    int totalTimeS = 180,
    int tasteScore = 3,
    String tasteTags = 'asam,cokelat',
    String? notes,
    double? costIdr,
    String status = 'aktif',
    String prevHash = '0',
  }) async {
    final hashData = (
      beanId: beanId,
      doseG: doseG,
      ratio: ratio,
      waterTempC: waterTempC,
      grind: grind,
      totalTimeS: totalTimeS,
      tasteScore: tasteScore,
      tasteTags: tasteTags.split(','),
      brewedAtUtc: brewedAtUtc,
    );
    final calculatedHash = hashEntry(hashData, prevHash);

    await database.insert('brews', {
      'id': id,
      'user_id': userId,
      'seq': seq,
      'bean_id': beanId,
      'brewed_at_utc': brewedAtUtc,
      'dose_g': doseG,
      'ratio': ratio,
      'water_temp_c': waterTempC,
      'grind': grind,
      'total_time_s': totalTimeS,
      'taste_score': tasteScore,
      'taste_tags': tasteTags,
      'notes': notes,
      'ai_advice': null,
      'cost_idr': costIdr,
      'status': status,
      'prev_hash': prevHash,
      'hash': calculatedHash,
      'created_at': brewedAtUtc,
      'sync_status': 'synced',
    });
  }

  group('Pencarian dengan escaping % dan _', () {
    test('karakter % dan _ dicocokkan sebagai literal bukan wildcard', () async {
      final beanA = await createTestBean(name: 'Gayo 100% Arabica', roastery: 'Kopi_Kita');
      final beanB = await createTestBean(name: 'Gayo 1000 Arabica', roastery: 'KopiXKita');

      await insertTestBrew(
        id: 'brew-1',
        seq: 1,
        beanId: beanA,
        brewedAtUtc: '2026-10-18T10:00:00Z',
        notes: 'catatan rasa 50% manis',
      );
      await insertTestBrew(
        id: 'brew-2',
        seq: 2,
        beanId: beanB,
        brewedAtUtc: '2026-10-18T11:00:00Z',
        notes: 'catatan rasa 500 manis',
        prevHash: (await database.query('brews', where: 'id = ?', whereArgs: ['brew-1'])).single['hash'] as String,
      );

      // Cari "100%"
      final resultPercent = await brewRepository.findJournalBrews(
        userId: 'user-1',
        searchQuery: '100%',
      );
      expect(resultPercent.length, 1);
      expect(resultPercent.first.id, 'brew-1');

      // Cari "Kopi_"
      final resultUnderscore = await brewRepository.findJournalBrews(
        userId: 'user-1',
        searchQuery: 'Kopi_',
      );
      expect(resultUnderscore.length, 1);
      expect(resultUnderscore.first.id, 'brew-1');

      // Cari di catatan "50%"
      final resultNotesPercent = await brewRepository.findJournalBrews(
        userId: 'user-1',
        searchQuery: '50%',
      );
      expect(resultNotesPercent.length, 1);
      expect(resultNotesPercent.first.id, 'brew-1');
    });
  });

  group('Filter', () {
    test('filter biji: mencocokkan salah satu dari yang dipilih (OR)', () async {
      final bean1 = await createTestBean(name: 'Bean 1');
      final bean2 = await createTestBean(name: 'Bean 2');
      final bean3 = await createTestBean(name: 'Bean 3');

      await insertTestBrew(id: 'b-1', seq: 1, beanId: bean1, brewedAtUtc: '2026-10-18T10:00:00Z');
      await insertTestBrew(id: 'b-2', seq: 2, beanId: bean2, brewedAtUtc: '2026-10-18T11:00:00Z');
      await insertTestBrew(id: 'b-3', seq: 3, beanId: bean3, brewedAtUtc: '2026-10-18T12:00:00Z');

      final result = await brewRepository.findJournalBrews(
        userId: 'user-1',
        beanIds: {bean1, bean3},
      );

      expect(result.map((b) => b.id).toSet(), {'b-1', 'b-3'});
    });

    test('filter skor minimal', () async {
      final bean = await createTestBean();
      await insertTestBrew(id: 'b-1', seq: 1, beanId: bean, brewedAtUtc: '2026-10-18T10:00:00Z', tasteScore: 2);
      await insertTestBrew(id: 'b-2', seq: 2, beanId: bean, brewedAtUtc: '2026-10-18T11:00:00Z', tasteScore: 4);
      await insertTestBrew(id: 'b-3', seq: 3, beanId: bean, brewedAtUtc: '2026-10-18T12:00:00Z', tasteScore: 5);

      final result = await brewRepository.findJournalBrews(
        userId: 'user-1',
        minTasteScore: 4,
      );

      expect(result.map((b) => b.id).toSet(), {'b-2', 'b-3'});
    });

    test('filter tag rasa utuh: tag asam cocok dengan asam,cokelat tapi tidak cocok dengan asam-manis', () async {
      final bean = await createTestBean();
      await insertTestBrew(
        id: 'b-1',
        seq: 1,
        beanId: bean,
        brewedAtUtc: '2026-10-18T10:00:00Z',
        tasteTags: 'asam,cokelat',
      );
      await insertTestBrew(
        id: 'b-2',
        seq: 2,
        beanId: bean,
        brewedAtUtc: '2026-10-18T11:00:00Z',
        tasteTags: 'asam-manis,buah',
      );
      await insertTestBrew(
        id: 'b-3',
        seq: 3,
        beanId: bean,
        brewedAtUtc: '2026-10-18T12:00:00Z',
        tasteTags: 'cokelat,manis',
      );

      // Filter hanya tag 'asam'
      final resultAsam = await brewRepository.findJournalBrews(
        userId: 'user-1',
        tasteTags: {'asam'},
      );
      expect(resultAsam.map((b) => b.id).toList(), ['b-1']);

      // Filter memuat salah satu tag terpilih: 'asam' atau 'buah'
      final resultMultiple = await brewRepository.findJournalBrews(
        userId: 'user-1',
        tasteTags: {'asam', 'buah'},
      );
      expect(resultMultiple.map((b) => b.id).toSet(), {'b-1', 'b-2'});
    });

    test('filter rentang tanggal: batas waktu lokal diubah ke UTC inklusif sampai akhir hari', () async {
      final bean = await createTestBean();
      await insertTestBrew(id: 'b-1', seq: 1, beanId: bean, brewedAtUtc: '2026-10-15T12:00:00Z');
      await insertTestBrew(id: 'b-2', seq: 2, beanId: bean, brewedAtUtc: '2026-10-18T05:00:00Z');
      await insertTestBrew(id: 'b-3', seq: 3, beanId: bean, brewedAtUtc: '2026-10-20T14:00:00Z');
      await insertTestBrew(id: 'b-4', seq: 4, beanId: bean, brewedAtUtc: '2026-10-22T08:00:00Z');

      // Rentang tanggal dari 18 Okt sampai 20 Okt (inklusif akhir hari)
      final result = await brewRepository.findJournalBrews(
        userId: 'user-1',
        startBrewedAtUtc: '2026-10-18T00:00:00Z',
        endBrewedAtUtc: '2026-10-20T23:59:59Z',
      );

      expect(result.map((b) => b.id).toSet(), {'b-2', 'b-3'});
    });

    test('kombinasi filter: biji, skor, tag, dan tanggal', () async {
      final beanA = await createTestBean(name: 'Bean A');
      final beanB = await createTestBean(name: 'Bean B');

      await insertTestBrew(
        id: 'match-1',
        seq: 1,
        beanId: beanA,
        brewedAtUtc: '2026-10-19T10:00:00Z',
        tasteScore: 4,
        tasteTags: 'asam,floral',
      );
      await insertTestBrew(
        id: 'no-match-score',
        seq: 2,
        beanId: beanA,
        brewedAtUtc: '2026-10-19T11:00:00Z',
        tasteScore: 2,
        tasteTags: 'asam,floral',
      );
      await insertTestBrew(
        id: 'no-match-bean',
        seq: 3,
        beanId: beanB,
        brewedAtUtc: '2026-10-19T12:00:00Z',
        tasteScore: 5,
        tasteTags: 'asam,floral',
      );
      await insertTestBrew(
        id: 'no-match-tag',
        seq: 4,
        beanId: beanA,
        brewedAtUtc: '2026-10-19T13:00:00Z',
        tasteScore: 5,
        tasteTags: 'cokelat,manis',
      );

      final result = await brewRepository.findJournalBrews(
        userId: 'user-1',
        beanIds: {beanA},
        minTasteScore: 3,
        tasteTags: {'asam'},
        startBrewedAtUtc: '2026-10-19T00:00:00Z',
        endBrewedAtUtc: '2026-10-19T23:59:59Z',
      );

      expect(result.map((b) => b.id).toList(), ['match-1']);
    });
  });

  group('Pengurutan', () {
    test('urutan terbaru, skor tertinggi, dan biaya dengan cost_idr null di akhir', () async {
      final bean = await createTestBean();
      await insertTestBrew(
        id: 'b-1',
        seq: 1,
        beanId: bean,
        brewedAtUtc: '2026-10-18T10:00:00Z',
        tasteScore: 3,
        costIdr: 4500,
      );
      await insertTestBrew(
        id: 'b-2',
        seq: 2,
        beanId: bean,
        brewedAtUtc: '2026-10-19T10:00:00Z',
        tasteScore: 5,
        costIdr: null,
      );
      await insertTestBrew(
        id: 'b-3',
        seq: 3,
        beanId: bean,
        brewedAtUtc: '2026-10-20T10:00:00Z',
        tasteScore: 4,
        costIdr: 6000,
      );

      // Terbaru
      final newest = await brewRepository.findJournalBrews(
        userId: 'user-1',
        sortOption: BrewSortOption.newest,
      );
      expect(newest.map((b) => b.id).toList(), ['b-3', 'b-2', 'b-1']);

      // Skor tertinggi
      final highestScore = await brewRepository.findJournalBrews(
        userId: 'user-1',
        sortOption: BrewSortOption.highestScore,
      );
      expect(highestScore.map((b) => b.id).toList(), ['b-2', 'b-3', 'b-1']);

      // Biaya (costIdr null di akhir, seq DESC pemutus seri)
      final cost = await brewRepository.findJournalBrews(
        userId: 'user-1',
        sortOption: BrewSortOption.cost,
      );
      expect(cost.map((b) => b.id).toList(), ['b-3', 'b-1', 'b-2']);
    });
  });

  group('Pembatalan seduhan (cancelBrew)', () {
    test('pembatalan tidak mengubah hash, prev_hash, dan rantai tetap utuh', () async {
      final bean = await createTestBean();
      await insertTestBrew(
        id: 'brew-seq-1',
        seq: 1,
        beanId: bean,
        brewedAtUtc: '2026-10-18T10:00:00Z',
        tasteScore: 4,
        prevHash: '0',
      );
      final brew1Row = (await database.query('brews', where: 'id = ?', whereArgs: ['brew-seq-1'])).single;
      final hash1 = brew1Row['hash'] as String;

      await insertTestBrew(
        id: 'brew-seq-2',
        seq: 2,
        beanId: bean,
        brewedAtUtc: '2026-10-19T10:00:00Z',
        tasteScore: 5,
        prevHash: hash1,
      );
      final brew2Row = (await database.query('brews', where: 'id = ?', whereArgs: ['brew-seq-2'])).single;
      final hash2 = brew2Row['hash'] as String;

      // Batalkan seduhan kedua
      final success = await brewRepository.cancelBrew(userId: 'user-1', brewId: 'brew-seq-2');
      expect(success, isTrue);

      final cancelledRow = (await database.query('brews', where: 'id = ?', whereArgs: ['brew-seq-2'])).single;
      expect(cancelledRow['status'], 'dibatalkan');
      expect(cancelledRow['sync_status'], 'pending');
      expect(cancelledRow['hash'], hash2);
      expect(cancelledRow['prev_hash'], hash1);
      expect(cancelledRow['seq'], 2);

      // Verifikasi rantai tetap utuh
      final chainStatus = await brewRepository.verifyUserChain('user-1');
      expect(chainStatus, 'utuh (2 entri)');
    });

    test('best_brew_id dihitung ulang otomatis dan NULL jika habis', () async {
      final bean = await createTestBean();
      await insertTestBrew(
        id: 'brew-lower',
        seq: 1,
        beanId: bean,
        brewedAtUtc: '2026-10-18T10:00:00Z',
        tasteScore: 3,
      );
      await insertTestBrew(
        id: 'brew-higher',
        seq: 2,
        beanId: bean,
        brewedAtUtc: '2026-10-19T10:00:00Z',
        tasteScore: 5,
      );
      await database.update('beans', {'best_brew_id': 'brew-higher'}, where: 'id = ?', whereArgs: [bean]);

      // Batalkan yang tertinggi
      await brewRepository.cancelBrew(userId: 'user-1', brewId: 'brew-higher');

      final beanAfterFirstCancel = await beanRepository.findById(userId: 'user-1', id: bean);
      expect(beanAfterFirstCancel!.bestBrewId, 'brew-lower');
      expect(beanAfterFirstCancel.syncStatus, 'pending');

      // Batalkan juga yang terakhir
      await brewRepository.cancelBrew(userId: 'user-1', brewId: 'brew-lower');

      final beanAfterSecondCancel = await beanRepository.findById(userId: 'user-1', id: bean);
      expect(beanAfterSecondCancel!.bestBrewId, isNull);
      expect(beanAfterSecondCancel.syncStatus, 'pending');
    });

    test('stok bertambah kembali setelah pembatalan', () async {
      final bean = await createTestBean(initialStockG: 100);
      await insertTestBrew(
        id: 'brew-1',
        seq: 1,
        beanId: bean,
        brewedAtUtc: '2026-10-18T10:00:00Z',
        doseG: 20,
      );

      final stockBefore = await brewRepository.remainingStockG(userId: 'user-1', beanId: bean);
      expect(stockBefore, 80);

      await brewRepository.cancelBrew(userId: 'user-1', brewId: 'brew-1');

      final stockAfter = await brewRepository.remainingStockG(userId: 'user-1', beanId: bean);
      expect(stockAfter, 100);
    });

    test('pembatalan hanya untuk entri aktif milik user_id aktif', () async {
      final bean = await createTestBean(userId: 'user-2');
      await insertTestBrew(
        id: 'brew-other-user',
        userId: 'user-2',
        seq: 1,
        beanId: bean,
        brewedAtUtc: '2026-10-18T10:00:00Z',
      );

      // Coba batalkan pakai user-1
      final cancelOther = await brewRepository.cancelBrew(userId: 'user-1', brewId: 'brew-other-user');
      expect(cancelOther, isFalse);

      final row = (await database.query('brews', where: 'id = ?', whereArgs: ['brew-other-user'])).single;
      expect(row['status'], 'aktif');

      // Batalkan pakai user-2 (berhasil)
      final cancelSelf = await brewRepository.cancelBrew(userId: 'user-2', brewId: 'brew-other-user');
      expect(cancelSelf, isTrue);

      // Batalkan kembali entri yang sudah dibatalkan (harus no-op / false)
      final cancelAgain = await brewRepository.cancelBrew(userId: 'user-2', brewId: 'brew-other-user');
      expect(cancelAgain, isFalse);
    });
  });

  group('Isolasi pengguna', () {
    test('semua query tidak mengembalikan data milik user_id lain', () async {
      final bean1 = await createTestBean(userId: 'user-1', name: 'Bean User 1');
      final bean2 = await createTestBean(userId: 'user-2', name: 'Bean User 2');

      await insertTestBrew(id: 'u1-brew', userId: 'user-1', seq: 1, beanId: bean1, brewedAtUtc: '2026-10-19T10:00:00Z');
      await insertTestBrew(id: 'u2-brew', userId: 'user-2', seq: 1, beanId: bean2, brewedAtUtc: '2026-10-19T11:00:00Z');

      final brewsUser1 = await brewRepository.findJournalBrews(userId: 'user-1');
      expect(brewsUser1.length, 1);
      expect(brewsUser1.first.id, 'u1-brew');

      final detailOther = await brewRepository.findBrewDetail(userId: 'user-1', brewId: 'u2-brew');
      expect(detailOther, isNull);
    });
  });
}
