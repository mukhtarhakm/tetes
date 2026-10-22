import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

class StoreRoute {
  const StoreRoute(this.points, this.distanceMeters, this.durationSeconds, this.steps);

  final List<LatLng> points;
  final double distanceMeters;
  final double durationSeconds;
  final List<String> steps;

  static StoreRoute? parse(Object? json) {
    if (json is! Map || json['code'] != 'Ok') return null;
    final routes = json['routes'];
    if (routes is! List || routes.isEmpty || routes.first is! Map) return null;
    final route = routes.first as Map;
    final geometry = route['geometry'];
    final coordinates = geometry is Map ? geometry['coordinates'] : null;
    final distance = route['distance'];
    final duration = route['duration'];
    if (coordinates is! List || coordinates.isEmpty || distance is! num || duration is! num) return null;
    final points = <LatLng>[];
    for (final coordinate in coordinates) {
      if (coordinate is! List || coordinate.length < 2 || coordinate[0] is! num || coordinate[1] is! num) return null;
      points.add(LatLng((coordinate[1] as num).toDouble(), (coordinate[0] as num).toDouble()));
    }
    final steps = <String>[];
    final legs = route['legs'];
    if (legs is List) {
      for (final leg in legs) {
        if (leg is! Map || leg['steps'] is! List) continue;
        for (final step in leg['steps'] as List) {
          if (step is! Map) continue;
          final maneuver = step['maneuver'];
          if (maneuver is Map) steps.add(instruction(maneuver['type'], maneuver['modifier'], step['name']));
        }
      }
    }
    return StoreRoute(points, distance.toDouble(), duration.toDouble(), steps);
  }

  static String instruction(Object? type, Object? modifier, Object? road) {
    final direction = switch (modifier) {
      'left' => 'kiri', 'slight left' => 'sedikit ke kiri', 'sharp left' => 'tajam ke kiri',
      'right' => 'kanan', 'slight right' => 'sedikit ke kanan', 'sharp right' => 'tajam ke kanan',
      'uturn' => 'putar balik', _ => 'lurus',
    };
    final action = switch (type) {
      'depart' => 'Mulai perjalanan',
      'arrive' => 'Tiba di tujuan',
      'turn' || 'end of road' => 'Belok $direction',
      'roundabout' || 'rotary' => 'Masuk bundaran',
      'merge' => 'Bergabung $direction',
      'fork' => 'Ambil cabang $direction',
      'on ramp' || 'off ramp' => 'Ambil jalan $direction',
      _ => 'Lanjut $direction',
    };
    final name = road is String ? road.trim() : '';
    return name.isEmpty || type == 'arrive' ? action : '$action ke $name';
  }
}

class StoreRouteService {
  const StoreRouteService();

  Future<StoreRoute?> fetch({required double latitude, required double longitude,
      required double destinationLatitude, required double destinationLongitude,
      required bool walking}) async {
    final profile = walking ? 'foot' : 'driving';
    final uri = Uri.parse('https://router.project-osrm.org/route/v1/$profile/'
        '$longitude,$latitude;$destinationLongitude,$destinationLatitude'
        '?overview=full&geometries=geojson&steps=true');
    final response = await http.get(uri, headers: const {'User-Agent': 'com.raismukhtar.tetes'})
        .timeout(const Duration(seconds: 10));
    if (response.statusCode != 200) throw const FormatException('route unavailable');
    return StoreRoute.parse(jsonDecode(response.body));
  }
}
