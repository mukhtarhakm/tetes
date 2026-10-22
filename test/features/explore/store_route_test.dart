import 'package:flutter_test/flutter_test.dart';
import 'package:tetes/features/explore/store_route.dart';

void main() {
  test('membaca rute GeoJSON dan langkah OSRM', () {
    final route = StoreRoute.parse({
      'code': 'Ok',
      'routes': [{
        'distance': 1450, 'duration': 240,
        'geometry': {'coordinates': [[110.4, -7.8], [110.41, -7.81]]},
        'legs': [{'steps': [
          {'maneuver': {'type': 'depart'}, 'name': 'Jalan A'},
          {'maneuver': {'type': 'turn', 'modifier': 'left'}, 'name': 'Jalan B'},
          {'maneuver': {'type': 'arrive'}, 'name': ''},
        ]}],
      }],
    });
    expect(route?.distanceMeters, 1450);
    expect(route?.points.first.latitude, -7.8);
    expect(route?.steps, ['Mulai perjalanan ke Jalan A', 'Belok kiri ke Jalan B', 'Tiba di tujuan']);
    expect(StoreRoute.parse({'code': 'NoRoute'}), isNull);
    expect(StoreRoute.parse({'code': 'Ok', 'routes': []}), isNull);
  });
}
