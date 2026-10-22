import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:sqflite/sqflite.dart';

class StoreSeeder {
  const StoreSeeder({this.assetPath = 'assets/data/stores.json'});

  final String assetPath;

  Future<void> seed(Database database) async {
    final source = await rootBundle.loadString(assetPath);
    final Object? decoded;
    try {
      decoded = jsonDecode(source);
    } on FormatException {
      return;
    }
    if (decoded is! List) return;
    final items = decoded;

    await database.transaction((transaction) async {
      for (final item in items) {
        final values = validStore(item);
        if (values == null) continue;
        await transaction.insert(
          'stores',
          values,
          conflictAlgorithm: ConflictAlgorithm.ignore,
        );
      }
    });
  }

  static Map<String, Object?>? validStore(Object? item) {
    if (item is! Map) return null;
    final id = item['id'];
    final name = item['name'];
    final type = item['store_type'];
    final latitude = item['latitude'];
    final longitude = item['longitude'];
    final address = item['address'];
    final notes = item['notes'];
    if (id is! String ||
        id.trim().isEmpty ||
        name is! String ||
        name.trim().isEmpty ||
        type is! String ||
        !const {'roastery', 'toko_biji', 'toko_alat'}.contains(type) ||
        latitude is! num ||
        !latitude.isFinite ||
        latitude < -8.05 ||
        latitude > -7.6 ||
        longitude is! num ||
        !longitude.isFinite ||
        longitude < 110.2 ||
        longitude > 110.6 ||
        address != null && address is! String ||
        notes != null && notes is! String) {
      return null;
    }
    return {
      'id': id,
      'name': name,
      'store_type': type,
      'latitude': latitude.toDouble(),
      'longitude': longitude.toDouble(),
      'address': address,
      'notes': notes,
    };
  }
}
