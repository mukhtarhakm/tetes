import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tetes/core/ui/app_chip.dart';
import 'package:tetes/core/ui/app_text_field.dart';
import 'package:tetes/features/beans/bean_model.dart';
import 'package:tetes/features/beans/screens/bean_form_screen.dart';

void main() {
  testWidgets('ukuran kemasan mengisi stok sampai stok diubah manual', (
    tester,
  ) async {
    await tester.pumpWidget(_app(const BeanFormScreen()));
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('250 g'));
    await tester.tap(find.text('250 g'));
    await tester.pump();

    final stockField = tester.widget<AppTextField>(
      find.byKey(const Key('bean-stock-field')),
    );
    expect(stockField.controller!.text, '250');

    await tester.enterText(
      find.descendant(
        of: find.byKey(const Key('bean-stock-field')),
        matching: find.byType(TextFormField),
      ),
      '180',
    );
    await tester.ensureVisible(find.text('500 g'));
    await tester.tap(find.text('500 g'));
    await tester.pump();

    expect(stockField.controller!.text, '180');
  });

  testWidgets('tag lama yang bukan bawaan tampil dan dapat dihapus', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(
        BeanFormScreen(initialBean: _bean(tags: const ['manis', 'unik lama'])),
      ),
    );
    await tester.pumpAndSettle();

    final customChipFinder = find.widgetWithText(AppChip, 'unik lama');
    expect(customChipFinder, findsOneWidget);
    expect(tester.widget<AppChip>(customChipFinder).onDeleted, isNotNull);

    await tester.ensureVisible(customChipFinder);
    await tester.tap(customChipFinder);
    await tester.pump();

    expect(find.widgetWithText(AppChip, 'unik lama'), findsNothing);
  });

  testWidgets(
    'sepuluh tag menonaktifkan tambah sendiri dan menampilkan pesan',
    (tester) async {
      final tags = [
        ...RoasteryNoteTag.values.take(9).map((tag) => tag.databaseValue),
        'tag sendiri',
      ];
      await tester.pumpWidget(
        _app(BeanFormScreen(initialBean: _bean(tags: tags))),
      );
      await tester.pumpAndSettle();

      final addChipFinder = find.widgetWithText(AppChip, '+ Tambah sendiri');
      expect(tester.widget<AppChip>(addChipFinder).onSelected, isNull);
      expect(find.text('Maksimal 10 tag per biji.'), findsOneWidget);
    },
  );
}

Widget _app(Widget home) {
  return ProviderScope(child: MaterialApp(home: home));
}

Bean _bean({required List<String> tags}) {
  return Bean(
    id: 'bean-1',
    userId: 'user-1',
    name: 'Biji lama',
    species: BeanSpecies.arabika,
    isSelfRoasted: false,
    initialStockG: 200,
    remainingStockG: 200,
    roasteryNotesTags: tags,
    archived: false,
    createdAt: '2026-10-19T00:00:00Z',
    updatedAt: '2026-10-19T00:00:00Z',
    syncStatus: 'pending',
    brewCount: 0,
  );
}
