class StoreItem {
  const StoreItem({
    required this.id,
    required this.name,
    required this.type,
    required this.latitude,
    required this.longitude,
    this.address,
    this.notes,
  });

  final String id;
  final String name;
  final String type;
  final double latitude;
  final double longitude;
  final String? address;
  final String? notes;

  factory StoreItem.fromMap(Map<String, Object?> row) => StoreItem(
    id: row['id'] as String,
    name: row['name'] as String,
    type: row['store_type'] as String,
    latitude: (row['latitude'] as num).toDouble(),
    longitude: (row['longitude'] as num).toDouble(),
    address: row['address'] as String?,
    notes: row['notes'] as String?,
  );

  String get typeLabel => switch (type) {
    'roastery' => 'Roastery',
    'toko_biji' => 'Toko biji',
    'toko_alat' => 'Toko alat',
    _ => 'Toko',
  };
}
