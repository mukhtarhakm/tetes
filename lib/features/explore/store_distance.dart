import 'dart:math' as math;

import 'store_model.dart';

abstract final class StoreDistance {
  static const earthRadiusMeters = 6371000.0;

  static double haversineMeters(
    double latitudeA,
    double longitudeA,
    double latitudeB,
    double longitudeB,
  ) {
    final latA = latitudeA * math.pi / 180;
    final latB = latitudeB * math.pi / 180;
    final latDelta = (latitudeB - latitudeA) * math.pi / 180;
    final lonDelta = (longitudeB - longitudeA) * math.pi / 180;
    final a =
        math.pow(math.sin(latDelta / 2), 2) +
        math.cos(latA) * math.cos(latB) * math.pow(math.sin(lonDelta / 2), 2);
    return 2 * earthRadiusMeters * math.asin(math.sqrt(a.clamp(0, 1)));
  }

  static List<StoreItem> sorted(
    Iterable<StoreItem> stores, {
    double? latitude,
    double? longitude,
  }) {
    final items = stores.toList();
    if (latitude == null || longitude == null) return items;
    items.sort(
      (a, b) => haversineMeters(latitude, longitude, a.latitude, a.longitude)
          .compareTo(
            haversineMeters(latitude, longitude, b.latitude, b.longitude),
          ),
    );
    return items;
  }

  static bool isInDiy(double latitude, double longitude) =>
      latitude >= -8.05 &&
      latitude <= -7.6 &&
      longitude >= 110.2 &&
      longitude <= 110.6;

  static String label(double meters) => meters < 1000
      ? '${meters.round()} m'
      : '${(meters / 1000).toStringAsFixed(1)} km';
}
