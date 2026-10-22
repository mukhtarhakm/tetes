import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme/tokens.dart';
import '../../core/ui/app_button.dart';
import '../../core/ui/app_card.dart';
import '../../core/ui/app_chip.dart';
import '../../core/ui/app_dialog.dart';
import '../../core/ui/app_text_field.dart';
import '../../core/ui/state_views.dart';
import '../../core/ui/status_pill.dart';
import '../../core/notifications/notification_coordinator.dart';
import '../../core/utils/event_display.dart';
import '../../core/utils/event_time.dart';
import '../../data/db/database_provider.dart';
import '../../data/repositories/event_repo.dart';
import '../auth/state/session_controller.dart';
import '../game/game_prototype_screen.dart';
import 'event_model.dart';
import 'store_screen.dart';
import 'currency_calculator_screen.dart';

final eventRepositoryProvider = FutureProvider<EventRepository>(
  (ref) async => EventRepository(await ref.watch(databaseProvider.future)),
);

class ExploreScreen extends StatelessWidget {
  const ExploreScreen({super.key});

  @override
  Widget build(BuildContext context) => SafeArea(
    bottom: false,
    child: ListView(
      padding: AppInsets.screen,
      children: [
        Text('Eksplor', style: Theme.of(context).textTheme.headlineMedium),
        const SizedBox(height: AppSpacing.s20),
        _MenuCard(
          title: 'Agenda Event',
          description: 'Catat acara dan lihat jam di empat zona waktu.',
          icon: Icons.event_outlined,
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute<void>(builder: (_) => const EventAgendaScreen()),
          ),
        ),
        const SizedBox(height: AppSpacing.s12),
        _MenuCard(
          title: 'Toko Terdekat',
          description: 'Temukan roastery, toko biji, dan alat seduh.',
          icon: Icons.store_outlined,
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute<void>(builder: (_) => const StoreScreen()),
          ),
        ),
        const SizedBox(height: AppSpacing.s12),
        _MenuCard(
          title: 'Kalkulator Kurs',
          description: 'Hitung nilai mata uang dengan kurs terbaru.',
          icon: Icons.currency_exchange_outlined,
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => const CurrencyCalculatorScreen(),
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.s12),
        _MenuCard(
          title: 'Game',
          description: 'Coba kontrol tuangan dengan gyroscope.',
          icon: Icons.sports_esports_outlined,
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => const GamePrototypeScreen(),
            ),
          ),
        ),
      ],
    ),
  );
}

class _MenuCard extends StatelessWidget {
  const _MenuCard({
    required this.title,
    required this.description,
    required this.icon,
    this.onTap,
  });
  final String title;
  final String description;
  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    button: onTap != null,
    enabled: onTap != null,
    child: AppCard(
      child: InkWell(
        onTap: onTap,
        child: Row(
          children: [
            Icon(icon),
            const SizedBox(width: AppSpacing.s16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: Theme.of(context).textTheme.titleMedium),
                  Text(
                    description,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ],
              ),
            ),
            if (onTap != null) const Icon(Icons.chevron_right_rounded),
          ],
        ),
      ),
    ),
  );
}

class EventAgendaScreen extends ConsumerStatefulWidget {
  const EventAgendaScreen({super.key});
  @override
  ConsumerState<EventAgendaScreen> createState() => _EventAgendaScreenState();
}

class _EventAgendaScreenState extends ConsumerState<EventAgendaScreen> {
  late Future<List<EventItem>> _events;
  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    _events = _load();
  }

  Future<List<EventItem>> _load() async {
    final userId = ref.read(sessionControllerProvider).asData?.value.userId;
    if (userId == null) throw StateError('Sesi tidak tersedia.');
    return (await ref.read(eventRepositoryProvider.future)).listActive(userId);
  }

  Future<void> _openForm([EventItem? event]) async {
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => EventFormScreen(event: event)),
    );
    if (changed == true && mounted) setState(_reload);
  }

  Future<void> _openDetail(EventItem event) async {
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => EventDetailScreen(event: event)),
    );
    if (changed == true && mounted) setState(_reload);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Agenda Event')),
    body: FutureBuilder<List<EventItem>>(
      future: _events,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const LoadingView();
        }
        if (snapshot.hasError) {
          return ErrorView(
            message: 'Agenda gagal dimuat. Coba lagi.',
            onRetry: () => setState(_reload),
          );
        }
        final events = snapshot.data!;
        if (events.isEmpty) {
          return EmptyView(
            title: 'Belum ada event',
            message: 'Tambahkan event pertama Anda.',
            icon: Icons.event_outlined,
            actionLabel: 'Tambah event',
            onActionPressed: () => _openForm(),
          );
        }
        final now = DateTime.now().toUtc();
        final upcoming = events
            .where((event) => !event.startUtc.isBefore(now))
            .toList();
        final past = events
            .where((event) => event.startUtc.isBefore(now))
            .toList()
            .reversed;
        return ListView(
          padding: AppInsets.screen,
          children: [
            Text('Mendatang', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: AppSpacing.s12),
            if (upcoming.isEmpty) const Text('Belum ada event mendatang.'),
            for (final event in upcoming) ...[
              _EventCard(
                event: event,
                now: now,
                onTap: () => _openDetail(event),
              ),
              const SizedBox(height: AppSpacing.s12),
            ],
            ExpansionTile(
              title: const Text('Event lampau'),
              children: [
                if (past.isEmpty) const Text('Belum ada event lampau.'),
                for (final event in past)
                  Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.s12),
                    child: _EventCard(
                      event: event,
                      now: now,
                      onTap: () => _openDetail(event),
                    ),
                  ),
              ],
            ),
          ],
        );
      },
    ),
    floatingActionButton: FloatingActionButton(
      tooltip: 'Tambah event',
      onPressed: () => _openForm(),
      child: const Icon(Icons.add_rounded),
    ),
  );
}

class _EventCard extends StatelessWidget {
  const _EventCard({
    required this.event,
    required this.now,
    required this.onTap,
  });
  final EventItem event;
  final DateTime now;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final source = EventTime.fromUtc(event.startUtc, event.sourceZone);
    final wib = EventTime.fromUtc(event.startUtc, EventTime.zones['WIB']!);
    final dayOffset = EventDisplay.dayOffset(source, wib);
    final past = !event.startUtc.isAfter(now);
    return AppCard(
      backgroundColor: past ? AppColors.background : null,
      child: InkWell(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(event.name, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: AppSpacing.s8),
            Wrap(
              spacing: AppSpacing.s8,
              runSpacing: AppSpacing.s8,
              children: [
                AppChip(label: event.eventType),
                StatusPill(
                  label: EventDisplay.countdown(event.startUtc, now),
                  variant: StatusPillVariant.pending,
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.s12),
            Text(
              EventDisplay.eventTime(event.startUtc, event.sourceZone),
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            Text(
              '${EventDisplay.clock(wib)} WIB${dayOffset.isEmpty ? '' : ' · $dayOffset'}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            if (event.location != null && event.location!.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.s8),
              Row(
                children: [
                  const Icon(
                    Icons.place_outlined,
                    size: AppSizes.navigationIcon,
                  ),
                  const SizedBox(width: AppSpacing.s4),
                  Expanded(child: Text(event.location!)),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class EventDetailScreen extends ConsumerWidget {
  const EventDetailScreen({required this.event, super.key});
  final EventItem event;

  Future<void> _delete(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialog) => AppDialog(
        title: 'Hapus event?',
        message: 'Event akan dihapus dari agenda.',
        primaryLabel: 'Hapus',
        onPrimaryPressed: () => Navigator.pop(dialog, true),
        secondaryLabel: 'Batal',
        onSecondaryPressed: () => Navigator.pop(dialog, false),
      ),
    );
    if (confirmed != true || !context.mounted) {
      return;
    }
    try {
      final userId = ref.read(sessionControllerProvider).asData?.value.userId;
      if (userId == null) throw StateError('Sesi tidak tersedia.');
      await (await ref.read(
        eventRepositoryProvider.future,
      )).softDelete(userId, event.id);
      try {
        await (await ref.read(
          notificationCoordinatorProvider.future,
        )).rescheduleEvent(userId, event.notifBaseId);
      } catch (_) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Event dihapus, tetapi pengingat belum diperbarui.',
              ),
            ),
          );
        }
      }
      if (context.mounted) Navigator.pop(context, true);
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Event gagal dihapus. Coba lagi.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final source = EventTime.fromUtc(event.startUtc, event.sourceZone);
    return Scaffold(
      appBar: AppBar(title: const Text('Detail Event')),
      body: ListView(
        padding: AppInsets.screen,
        children: [
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(event.name, style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: AppSpacing.s8),
                Text('Jenis: ${event.eventType}'),
                Text('Lokasi: ${event.location ?? 'Belum diisi'}'),
                Text(EventDisplay.eventTime(event.startUtc, event.sourceZone)),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.s12),
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Waktu di zona lain',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: AppSpacing.s12),
                for (final entry in EventTime.zones.entries) ...[
                  Builder(
                    builder: (context) {
                      final local = EventTime.fromUtc(
                        event.startUtc,
                        entry.value,
                      );
                      final offset = EventDisplay.dayOffset(source, local);
                      return Padding(
                        padding: const EdgeInsets.only(bottom: AppSpacing.s12),
                        child: Row(
                          children: [
                            AppChip(
                              label: entry.key,
                              selected: entry.value == event.sourceZone,
                            ),
                            const SizedBox(width: AppSpacing.s12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    EventDisplay.clock(local),
                                    style: Theme.of(
                                      context,
                                    ).textTheme.titleLarge,
                                  ),
                                  Text(
                                    '${EventDisplay.date(local)}${offset.isEmpty ? '' : ' · $offset'}',
                                    style: Theme.of(
                                      context,
                                    ).textTheme.bodySmall,
                                  ),
                                  if (entry.value == event.sourceZone)
                                    Text(
                                      'Zona event',
                                      style: Theme.of(
                                        context,
                                      ).textTheme.labelSmall,
                                    ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.s12),
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Catatan', style: Theme.of(context).textTheme.titleMedium),
                Text(event.notes ?? 'Belum diisi'),
                const SizedBox(height: AppSpacing.s8),
                Text(
                  'Pengingat',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                Text('${event.reminderMinutes} menit sebelum mulai'),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.s20),
          AppButton(
            label: 'Ubah',
            onPressed: () async {
              final changed = await Navigator.of(context).push<bool>(
                MaterialPageRoute(
                  builder: (_) => EventFormScreen(event: event),
                ),
              );
              if (changed == true && context.mounted) {
                Navigator.pop(context, true);
              }
            },
          ),
          const SizedBox(height: AppSpacing.s8),
          AppButton(
            label: 'Hapus',
            variant: AppButtonVariant.secondary,
            onPressed: () => _delete(context, ref),
          ),
        ],
      ),
    );
  }
}

class EventFormScreen extends ConsumerStatefulWidget {
  const EventFormScreen({this.event, super.key});
  final EventItem? event;
  @override
  ConsumerState<EventFormScreen> createState() => _EventFormScreenState();
}

class _EventFormScreenState extends ConsumerState<EventFormScreen> {
  late final TextEditingController _name;
  late final TextEditingController _location;
  late final TextEditingController _notes;
  late String _type;
  late String _zone;
  late Set<int> _reminders;
  DateTime? _date;
  TimeOfDay? _time;
  String? _error;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final event = widget.event;
    _name = TextEditingController(text: event?.name);
    _location = TextEditingController(text: event?.location);
    _notes = TextEditingController(text: event?.notes);
    _type = event?.eventType ?? 'pameran';
    _zone = event?.sourceZone ?? 'Asia/Jakarta';
    _reminders = event == null
        ? {1440}
        : event.reminderMinutes.split(',').map(int.parse).toSet();
    if (event != null) {
      final local = EventTime.fromUtc(event.startUtc, event.sourceZone);
      _date = DateTime(local.year, local.month, local.day);
      _time = TimeOfDay(hour: local.hour, minute: local.minute);
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _location.dispose();
    _notes.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() {
      _error = null;
      _saving = true;
    });
    try {
      if (_date == null || _time == null) {
        throw ArgumentError('Pilih tanggal dan jam mulai event.');
      }
      final utc = EventTime.toUtc(_date!, _time!.hour, _time!.minute, _zone);
      final draft = EventDraft(
        name: _name.text,
        eventType: _type,
        location: _location.text,
        notes: _notes.text,
        startUtc: utc,
        sourceZone: _zone,
        reminders: _reminders,
      );
      draft.validate();
      if (_reminders.any(
        (minutes) => !utc
            .subtract(Duration(minutes: minutes))
            .isAfter(DateTime.now().toUtc()),
      )) {
        throw ArgumentError(
          'Pengingat sudah lewat. Pilih waktu event yang lebih jauh.',
        );
      }
      final userId = ref.read(sessionControllerProvider).asData?.value.userId;
      if (userId == null) throw StateError('Sesi tidak tersedia.');
      final repo = await ref.read(eventRepositoryProvider.future);
      String eventId;
      if (widget.event == null) {
        eventId = await repo.create(userId, draft);
      } else {
        await repo.update(userId, widget.event!.id, draft);
        eventId = widget.event!.id;
      }
      try {
        final current = await repo.findById(userId, eventId);
        await (await ref.read(
          notificationCoordinatorProvider.future,
        )).rescheduleEvent(userId, current?.notifBaseId);
      } catch (_) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Event tersimpan, tetapi pengingat belum diperbarui.',
              ),
            ),
          );
        }
      }
      if (mounted) Navigator.pop(context, true);
    } on ArgumentError catch (error) {
      if (mounted) {
        setState(
          () => _error = error.message?.toString() ?? 'Periksa isian event.',
        );
      }
    } catch (_) {
      if (mounted) setState(() => _error = 'Event gagal disimpan. Coba lagi.');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(widget.event == null ? 'Tambah Event' : 'Ubah Event'),
    ),
    body: ListView(
      padding: AppInsets.screen,
      children: [
        AppTextField(controller: _name, label: 'Nama event', maxLength: 80),
        const SizedBox(height: AppSpacing.s16),
        Text('Jenis', style: Theme.of(context).textTheme.labelLarge),
        Wrap(
          spacing: AppSpacing.s8,
          runSpacing: AppSpacing.s8,
          children: [
            for (final type in EventDraft.types)
              AppChip(
                label: type,
                selected: _type == type,
                onSelected: (_) => setState(() => _type = type),
              ),
          ],
        ),
        const SizedBox(height: AppSpacing.s16),
        AppButton(
          label: _date == null
              ? 'Pilih tanggal'
              : 'Tanggal: ${_date!.day}/${_date!.month}/${_date!.year}',
          variant: AppButtonVariant.secondary,
          onPressed: () async {
            final picked = await showDatePicker(
              context: context,
              initialDate: _date ?? DateTime.now(),
              firstDate: DateTime(1900),
              lastDate: DateTime(2100),
            );
            if (picked != null) setState(() => _date = picked);
          },
        ),
        const SizedBox(height: AppSpacing.s8),
        AppButton(
          label: _time == null
              ? 'Pilih jam mulai'
              : 'Jam: ${_time!.format(context)}',
          variant: AppButtonVariant.secondary,
          onPressed: () async {
            final picked = await showTimePicker(
              context: context,
              initialTime: _time ?? TimeOfDay.now(),
            );
            if (picked != null) setState(() => _time = picked);
          },
        ),
        const SizedBox(height: AppSpacing.s16),
        Text('Zona waktu event', style: Theme.of(context).textTheme.labelLarge),
        Wrap(
          spacing: AppSpacing.s8,
          runSpacing: AppSpacing.s8,
          children: [
            for (final zone in EventTime.zones.entries)
              AppChip(
                label: zone.key,
                selected: _zone == zone.value,
                onSelected: (_) => setState(() => _zone = zone.value),
              ),
          ],
        ),
        const SizedBox(height: AppSpacing.s16),
        AppTextField(
          controller: _location,
          label: 'Lokasi (opsional)',
          maxLength: 120,
        ),
        const SizedBox(height: AppSpacing.s16),
        AppTextField(
          controller: _notes,
          label: 'Catatan (opsional)',
          maxLength: 500,
          maxLines: 3,
        ),
        const SizedBox(height: AppSpacing.s16),
        Text('Pengingat', style: Theme.of(context).textTheme.labelLarge),
        Wrap(
          spacing: AppSpacing.s8,
          runSpacing: AppSpacing.s8,
          children: [
            for (final option in const [
              (1440, '1 hari'),
              (180, '3 jam'),
              (30, '30 menit'),
            ])
              AppChip(
                label: option.$2,
                selected: _reminders.contains(option.$1),
                onSelected: (selected) => setState(() {
                  if (selected) {
                    _reminders.add(option.$1);
                  } else {
                    _reminders.remove(option.$1);
                  }
                }),
              ),
          ],
        ),
        if (_error != null) ...[
          const SizedBox(height: AppSpacing.s12),
          Text(
            _error!,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.error,
            ),
          ),
        ],
        const SizedBox(height: AppSpacing.s24),
        AppButton(
          label: 'Simpan event',
          isLoading: _saving,
          onPressed: _saving ? null : _save,
        ),
      ],
    ),
  );
}
