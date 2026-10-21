import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:tetes/core/ui/focus_dark_theme.dart';
import 'package:tetes/data/repositories/game_repo.dart';
import 'package:tetes/features/game/game_tutorial_screen.dart';

void main() {
  test('tutorial marker is per user and persists in settings', () async {
    sqfliteFfiInit();
    final database = await databaseFactoryFfi.openDatabase(
      inMemoryDatabasePath,
    );
    addTearDown(database.close);
    await database.execute('''
      CREATE TABLE settings (
        user_id TEXT NOT NULL, key TEXT NOT NULL, value TEXT NOT NULL,
        PRIMARY KEY (user_id, key)
      )
    ''');
    final repository = GameRepository(database);
    expect(await repository.hasSeenTutorial('a'), isFalse);
    await repository.markTutorialSeen('a');
    await repository.markTutorialSeen('a');
    expect(await repository.hasSeenTutorial('a'), isTrue);
    expect(await repository.hasSeenTutorial('b'), isFalse);
    expect(await database.query('settings'), hasLength(1));
  });

  testWidgets('tutorial shows instructions and disposes animation', (
    tester,
  ) async {
    var understood = false;
    await tester.pumpWidget(
      MaterialApp(
        home: FocusDarkTheme(
          child: Scaffold(
            body: GameTutorialScreen(
              active: true,
              onUnderstood: () => understood = true,
            ),
          ),
        ),
      ),
    );
    expect(
      find.text('Pegang HP datar seperti memegang piring.'),
      findsOneWidget,
    );
    expect(find.text('Miringkan HP ke arah zona hijau.'), findsOneWidget);
    expect(
      find.text('Jaga titik tetap di dalam zona sampai bar penuh.'),
      findsOneWidget,
    );
    await tester.tap(find.text('Mengerti'));
    expect(understood, isTrue);
    await tester.pumpWidget(const MaterialApp(home: SizedBox.shrink()));
    await tester.pump(const Duration(seconds: 5));
    expect(tester.takeException(), isNull);
  });
}
