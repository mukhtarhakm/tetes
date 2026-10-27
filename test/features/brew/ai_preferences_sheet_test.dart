import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tetes/features/brew/ai_brew.dart';
import 'package:tetes/features/brew/widgets/ai_preferences_sheet.dart';

void main() {
  late Future<AiRecommendPreferences?> result;

  Future<void> openSheet(WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => result = showAiPreferencesSheet(context),
              child: const Text('buka'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('buka'));
    await tester.pumpAndSettle();
  }

  testWidgets('Lewati mengembalikan preferensi kosong', (tester) async {
    await openSheet(tester);
    expect(find.text('Sebelum AI menyarankan'), findsOneWidget);
    await tester.tap(find.text('Lewati'));
    await tester.pumpAndSettle();
    expect((await result)!.isEmpty, isTrue);
  });

  testWidgets('isian terkirim dan dosis salah menonaktifkan tombol', (
    tester,
  ) async {
    await openSheet(tester);
    await tester.enterText(find.byKey(const Key('ai-pref-dose')), '70');
    await tester.pump();
    expect(find.text('Dosis harus antara 5 dan 60 gram.'), findsOneWidget);
    await tester.ensureVisible(find.text('Minta saran'));
    await tester.tap(find.text('Minta saran'));
    await tester.pumpAndSettle();
    expect(find.text('Sebelum AI menyarankan'), findsOneWidget);

    await tester.enterText(find.byKey(const Key('ai-pref-dose')), '17');
    await tester.ensureVisible(find.text('4'));
    await tester.tap(find.text('4'));
    await tester.enterText(find.byKey(const Key('ai-pref-wish')), ' lebih manis ');
    await tester.pump();
    await tester.ensureVisible(find.text('Minta saran'));
    await tester.tap(find.text('Minta saran'));
    await tester.pumpAndSettle();
    final prefs = (await result)!;
    expect(prefs.doseG, 17);
    expect(prefs.pouringCount, 4);
    expect(prefs.wish, 'lebih manis');
  });
}
