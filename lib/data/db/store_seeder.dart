import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:sqflite/sqflite.dart';

class StoreSeeder {
  const StoreSeeder({this.assetPath = 'assets/data/stores.json'});

  final String assetPath;

  Future<void> seed(Database database) async {
    final source = await rootBundle.loadString(assetPath);
    final decoded = jsonDecode(source);
    if (decoded is! List) {
      throw const FormatException('Seed stores harus berupa daftar JSON.');
    }

    await database.transaction((transaction) async {
      for (final item in decoded) {
        if (item is! Map<String, dynamic>) {
          throw const FormatException('Entri seed stores tidak valid.');
        }
        await transaction.insert(
          'stores',
          item,
          conflictAlgorithm: ConflictAlgorithm.ignore,
        );
      }
    });
  }
}
