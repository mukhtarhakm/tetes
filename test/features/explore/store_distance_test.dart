import 'package:flutter_test/flutter_test.dart';
import 'package:tetes/features/explore/store_distance.dart';
import 'package:tetes/features/explore/store_model.dart';

void main() {
  const near = StoreItem(id: 'near', name: 'Dekat', type: 'roastery',
      latitude: -7.8, longitude: 110.4);
  const far = StoreItem(id: 'far', name: 'Jauh', type: 'toko_alat',
      latitude: -7.7, longitude: 110.5);

  test('Haversine nol dan jarak satu derajat lintang', () {
    expect(StoreDistance.haversineMeters(-7.8, 110.4, -7.8, 110.4), 0);
    expect(StoreDistance.haversineMeters(0, 0, 1, 0), closeTo(111195, 100));
  });

  test('urut jarak dan urutan asli tanpa izin lokasi', () {
    expect(StoreDistance.sorted([far, near], latitude: -7.8,
        longitude: 110.4).map((e) => e.id), ['near', 'far']);
    expect(StoreDistance.sorted([far, near]).map((e) => e.id), ['far', 'near']);
  });

  test('pusat lokasi pengguna hanya di batas DIY', () {
    expect(StoreDistance.isInDiy(-7.8, 110.4), isTrue);
    expect(StoreDistance.isInDiy(-7.5, 110.4), isFalse);
  });
}
