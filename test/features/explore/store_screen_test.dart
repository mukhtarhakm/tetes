import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tetes/features/explore/store_location.dart';
import 'package:tetes/features/explore/store_screen.dart';
import 'package:tetes/features/explore/store_model.dart';
import 'package:tetes/features/explore/map_navigation.dart';
import 'package:tetes/features/explore/store_route.dart';
import 'package:tetes/core/ui/app_chip.dart';

class _DeniedLocation extends StoreLocationService {
  const _DeniedLocation();

  @override
  Future<StoreLocationResult> read({bool request = false}) async =>
      const StoreLocationResult(StoreLocationStatus.denied);
}

class _NoMapNavigation extends MapNavigation {
  const _NoMapNavigation();

  @override
  Future<bool> open(double latitude, double longitude, String name) async =>
      false;
}

class _AvailableLocation extends StoreLocationService {
  const _AvailableLocation();

  @override
  Future<StoreLocationResult> read({bool request = false}) async =>
      const StoreLocationResult(
        StoreLocationStatus.available,
        latitude: -7.8,
        longitude: 110.4,
      );
}

class _RouteSpy extends StoreRouteService {
  int calls = 0;

  @override
  Future<StoreRoute?> fetch({
    required double latitude,
    required double longitude,
    required double destinationLatitude,
    required double destinationLongitude,
    required bool walking,
  }) async {
    calls++;
    return null;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const stores = [
    StoreItem(
      id: 'far',
      name: 'A Toko Alat',
      type: 'toko_alat',
      latitude: -7.7,
      longitude: 110.5,
    ),
    StoreItem(
      id: 'near',
      name: 'B Roastery',
      type: 'roastery',
      latitude: -7.8,
      longitude: 110.4,
    ),
    StoreItem(
      id: 'bean',
      name: 'C Toko Biji',
      type: 'toko_biji',
      latitude: -7.81,
      longitude: 110.41,
    ),
  ];

  Future<void> showScreen(WidgetTester tester) async {
    tester.view.physicalSize = const Size(800, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          storeListProvider.overrideWithValue(const AsyncData(stores)),
          storeLocationProvider.overrideWithValue(const _DeniedLocation()),
          mapNavigationProvider.overrideWithValue(const _NoMapNavigation()),
        ],
        child: const MaterialApp(home: StoreScreen()),
      ),
    );
    await tester.pump();
    await tester.pump();
  }

  testWidgets(
    'izin ditolak menampilkan daftar tanpa jarak dan tombol pengaturan',
    (tester) async {
      await showScreen(tester);
      expect(find.textContaining('Izin lokasi ditolak.'), findsOneWidget);
      expect(find.text('Buka pengaturan'), findsOneWidget);
      expect(find.text('A Toko Alat'), findsWidgets);
      expect(find.text('B Roastery'), findsWidgets);
      expect(find.textContaining(' km'), findsNothing);
      expect(find.textContaining(' m'), findsNothing);
    },
  );

  testWidgets('filter jenis hanya menampilkan toko yang dipilih', (
    tester,
  ) async {
    await showScreen(tester);
    await tester.tap(find.widgetWithText(AppChip, 'Biji'));
    await tester.pump();
    expect(find.text('B Roastery'), findsWidgets);
    expect(find.text('C Toko Biji'), findsWidgets);
    expect(find.text('A Toko Alat'), findsNothing);
    await tester.tap(find.widgetWithText(AppChip, 'Alat'));
    await tester.pump();
    expect(find.text('A Toko Alat'), findsWidgets);
    expect(find.text('B Roastery'), findsNothing);
    expect(find.text('C Toko Biji'), findsNothing);
  });

  testWidgets('kontrol peta mengikuti tepi sheet saat sheet ditarik', (
    tester,
  ) async {
    await showScreen(tester);
    expect(find.byType(DraggableScrollableSheet), findsOneWidget);
    expect(find.byTooltip('Atribusi peta'), findsOneWidget);
    final button = find.byTooltip('Ke posisiku');
    final initialY = tester.getCenter(button).dy;
    await tester.drag(find.text('Daftar toko'), const Offset(0, -240));
    await tester.pumpAndSettle();
    expect(tester.getCenter(button).dy, lessThan(initialY));
  });

  testWidgets('tanpa aplikasi peta tombol navigasi memberi pesan', (
    tester,
  ) async {
    await showScreen(tester);
    await tester.tap(find.text('A Toko Alat'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Buka navigasi'));
    await tester.pump();
    expect(
      find.text('Tidak ada aplikasi peta yang dapat membuka navigasi.'),
      findsOneWidget,
    );
  });

  testWidgets('rute tidak meminta OSRM sebelum persetujuan', (tester) async {
    tester.view.physicalSize = const Size(800, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    final spy = _RouteSpy();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          storeListProvider.overrideWithValue(const AsyncData(stores)),
          storeLocationProvider.overrideWithValue(const _AvailableLocation()),
          storeRouteServiceProvider.overrideWithValue(spy),
        ],
        child: const MaterialApp(home: StoreScreen()),
      ),
    );
    await tester.pump();
    await tester.pump();
    await tester.tap(find.text('A Toko Alat'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Lihat rute'));
    await tester.pumpAndSettle();
    expect(find.text('Lihat rute?'), findsOneWidget);
    expect(spy.calls, 0);
    await tester.tap(find.text('Batal'));
    await tester.pumpAndSettle();
    expect(spy.calls, 0);
    await tester.tap(find.text('Lihat rute'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Lanjut'));
    await tester.pumpAndSettle();
    expect(spy.calls, 1);
    expect(find.text('Rute tidak ditemukan.'), findsOneWidget);
  });
}
