class EventItem {
  const EventItem({
    required this.id,
    required this.name,
    required this.eventType,
    required this.startUtc,
    required this.sourceZone,
    required this.reminderMinutes,
    this.notifBaseId,
    this.location,
    this.notes,
  });

  final String id;
  final String name;
  final String eventType;
  final String? location;
  final String? notes;
  final DateTime startUtc;
  final String sourceZone;
  final String reminderMinutes;
  final int? notifBaseId;

  factory EventItem.fromMap(Map<String, Object?> row) => EventItem(
    id: row['id'] as String,
    name: row['name'] as String,
    eventType: row['event_type'] as String? ?? 'lainnya',
    location: row['location'] as String?,
    notes: row['notes'] as String?,
    startUtc: DateTime.parse(row['start_utc'] as String),
    sourceZone: row['source_zone'] as String,
    reminderMinutes: row['reminder_minutes'] as String,
    notifBaseId: (row['notif_base_id'] as num?)?.toInt(),
  );
}

class EventDraft {
  const EventDraft({
    required this.name,
    required this.eventType,
    required this.startUtc,
    required this.sourceZone,
    required this.reminders,
    this.location,
    this.notes,
  });

  final String name;
  final String eventType;
  final String? location;
  final String? notes;
  final DateTime startUtc;
  final String sourceZone;
  final Set<int> reminders;

  static const types = {'pameran', 'lomba', 'cupping', 'workshop', 'lainnya'};
  static const reminderOptions = {1440, 180, 30};

  void validate() {
    if (name.trim().isEmpty || name.trim().length > 80) {
      throw ArgumentError('Isi nama event, maksimal 80 karakter.');
    }
    if (!types.contains(eventType)) {
      throw ArgumentError('Pilih jenis event.');
    }
    if (location != null && location!.trim().length > 120) {
      throw ArgumentError('Lokasi maksimal 120 karakter.');
    }
    if (notes != null && notes!.trim().length > 500) {
      throw ArgumentError('Catatan maksimal 500 karakter.');
    }
    if (!{
      'Asia/Jakarta',
      'Asia/Makassar',
      'Asia/Jayapura',
      'Europe/London',
    }.contains(sourceZone)) {
      throw ArgumentError('Pilih zona waktu event.');
    }
    if (reminders.isEmpty ||
        reminders.length > 3 ||
        !reminderOptions.containsAll(reminders)) {
      throw ArgumentError('Pilih satu sampai tiga pengingat.');
    }
  }

  String get reminderText =>
      (reminders.toList()..sort((a, b) => b.compareTo(a))).join(',');
}
