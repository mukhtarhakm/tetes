import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:tetes/data/db/database_provider.dart';
import 'package:tetes/main.dart';

void main() {
  late Database database;

  setUpAll(sqfliteFfiInit);

  setUp(() async {
    database = await databaseFactoryFfi.openDatabase(inMemoryDatabasePath);
  });

  tearDown(() async {
    await database.close();
  });

  testWidgets('menampilkan navigasi setelah database siap', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [databaseProvider.overrideWithValue(AsyncData(database))],
        child: const MyApp(),
      ),
    );
    await tester.pump();

    expect(find.text('Seduh'), findsWidgets);
    expect(
      find.text('Belum ada seduhan. Alat bantu seduh akan hadir di sini.'),
      findsOneWidget,
    );
  });
}
