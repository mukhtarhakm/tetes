import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tetes/features/explore/store_map_tiles.dart';

void main() {
  testWidgets('gaya vektor gagal tetap memakai tile OSM', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: FlutterMap(
            children: [
              StoreMapTiles(styleLoader: () async => throw StateError('gagal')),
            ],
          ),
        ),
      ),
    );
    await tester.pump();
    expect(find.byType(TileLayer), findsOneWidget);
    expect(find.byType(StoreMapTiles), findsOneWidget);
  });
}
