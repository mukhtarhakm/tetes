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

  testWidgets('menampilkan login setelah database siap', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [databaseProvider.overrideWithValue(AsyncData(database))],
        child: const MyApp(),
      ),
    );
    await tester.pump();

    expect(find.text('Masuk ke Tetes'), findsOneWidget);
    expect(find.text('Username'), findsOneWidget);
    expect(find.text('Masuk'), findsOneWidget);
  });
}
