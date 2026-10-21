import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme/tokens.dart';
import '../../features/auth/state/session_controller.dart';
import '../ui/app_button.dart';
import '../ui/app_card.dart';
import '../ui/app_chip.dart';
import '../ui/app_dialog.dart';
import '../ui/app_text_field.dart';
import '../ui/state_views.dart';
import 'notification_coordinator.dart';
import 'notification_service.dart';

class NotificationProfileCard extends ConsumerStatefulWidget {
  const NotificationProfileCard({super.key});
  @override
  ConsumerState<NotificationProfileCard> createState() =>
      _NotificationProfileCardState();
}

class _NotificationProfileCardState
    extends ConsumerState<NotificationProfileCard> {
  static const _days = ['Sen', 'Sel', 'Rab', 'Kam', 'Jum', 'Sab', 'Min'];
  final _threshold = TextEditingController();
  bool _loading = true;
  bool _saving = false;
  bool _enabled = false;
  bool? _permission;
  String? _error;
  TimeOfDay _time = const TimeOfDay(hour: 8, minute: 0);
  Set<int> _selectedDays = {1, 2, 3, 4, 5, 6, 7};

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _threshold.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final userId = ref.read(sessionControllerProvider).asData?.value.userId;
      if (userId == null) throw StateError('Sesi tidak tersedia.');
      final settings = await (await ref.read(
        notificationCoordinatorProvider.future,
      )).loadSettings(userId);
      final permission = await ref
          .read(notificationServiceProvider)
          .permissionGranted();
      if (!mounted) return;
      setState(() {
        _enabled = settings.enabled;
        _time = TimeOfDay(hour: settings.hour, minute: settings.minute);
        _selectedDays = {...settings.days};
        _threshold.text = settings.stockThresholdG.toStringAsFixed(0);
        _permission = permission;
        _loading = false;
      });
    } catch (_) {
      if (mounted) {
        setState(() {
          _error = 'Pengaturan notifikasi gagal dimuat.';
          _loading = false;
        });
      }
    }
  }

  Future<bool> _requestPermission() async {
    final agreed = await showDialog<bool>(
      context: context,
      builder: (dialog) => AppDialog(
        title: 'Aktifkan notifikasi?',
        message:
            'Tetes perlu izin untuk mengingatkan event, waktu seduh, dan stok biji.',
        primaryLabel: 'Lanjutkan',
        onPrimaryPressed: () => Navigator.pop(dialog, true),
        secondaryLabel: 'Nanti',
        onSecondaryPressed: () => Navigator.pop(dialog, false),
      ),
    );
    if (agreed != true || !mounted) return false;
    try {
      final granted = await ref
          .read(notificationServiceProvider)
          .requestPermission();
      if (mounted) setState(() => _permission = granted);
      if (!granted && mounted) {
        setState(
          () => _error =
              'Izin ditolak. Aktifkan notifikasi untuk Tetes di Pengaturan perangkat.',
        );
      }
      if (granted) {
        final userId = ref.read(sessionControllerProvider).asData?.value.userId;
        if (userId != null) {
          await (await ref.read(
            notificationCoordinatorProvider.future,
          )).refreshAll(userId);
        }
      }
      return granted;
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'Izin notifikasi gagal diminta. Coba lagi.');
      }
      return false;
    }
  }

  Future<void> _save() async {
    final threshold = double.tryParse(
      _threshold.text.trim().replaceAll(',', '.'),
    );
    if (threshold == null ||
        !threshold.isFinite ||
        threshold < 0 ||
        threshold > 500) {
      setState(() => _error = 'Ambang stok harus angka 0 sampai 500 gram.');
      return;
    }
    if (_enabled && _selectedDays.isEmpty) {
      setState(() => _error = 'Pilih minimal satu hari pengingat seduh.');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final userId = ref.read(sessionControllerProvider).asData?.value.userId;
      if (userId == null) throw StateError('Sesi tidak tersedia.');
      await (await ref.read(
        notificationCoordinatorProvider.future,
      )).saveSettings(
        userId,
        NotificationSettings(
          enabled: _enabled,
          hour: _time.hour,
          minute: _time.minute,
          days: _selectedDays,
          stockThresholdG: threshold,
        ),
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Pengaturan notifikasi tersimpan.')),
        );
      }
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'Pengaturan gagal disimpan. Coba lagi.');
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _test() async {
    if (_permission != true && !await _requestPermission()) return;
    try {
      await (await ref.read(notificationCoordinatorProvider.future)).showTest();
    } catch (_) {
      if (mounted) setState(() => _error = 'Notifikasi uji gagal dikirim.');
    }
  }

  @override
  Widget build(BuildContext context) => AppCard(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Notifikasi', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: AppSpacing.s12),
        if (_loading)
          const LoadingView()
        else if (_error != null && _permission == null)
          ErrorView(message: _error!, onRetry: _load)
        else ...[
          if (_permission != true) ...[
            const Text(
              'Izin belum aktif. Aktifkan notifikasi di Pengaturan perangkat jika pernah menolak.',
            ),
            const SizedBox(height: AppSpacing.s8),
            AppButton(
              label: 'Minta izin notifikasi',
              onPressed: _requestPermission,
            ),
            const SizedBox(height: AppSpacing.s12),
          ] else
            const Text(
              'Notifikasi diizinkan. Jadwal tak tepat dapat bergeser bila izin alarm tepat tidak tersedia.',
            ),
          Row(
            children: [
              const Expanded(child: Text('Pengingat seduh harian')),
              Switch(
                value: _enabled,
                onChanged: (value) => setState(() => _enabled = value),
              ),
            ],
          ),
          AppButton(
            label: 'Jam: ${_time.format(context)}',
            variant: AppButtonVariant.secondary,
            onPressed: () async {
              final selected = await showTimePicker(
                context: context,
                initialTime: _time,
              );
              if (selected != null) setState(() => _time = selected);
            },
          ),
          const SizedBox(height: AppSpacing.s8),
          Wrap(
            spacing: AppSpacing.s8,
            runSpacing: AppSpacing.s8,
            children: [
              for (var index = 0; index < 7; index++)
                AppChip(
                  label: _days[index],
                  selected: _selectedDays.contains(index + 1),
                  onSelected: (selected) => setState(() {
                    if (selected) {
                      _selectedDays.add(index + 1);
                    } else {
                      _selectedDays.remove(index + 1);
                    }
                  }),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.s12),
          AppTextField(
            controller: _threshold,
            label: 'Ambang stok (gram)',
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
          ),
          if (_error != null)
            Text(
              _error!,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.error,
              ),
            ),
          const SizedBox(height: AppSpacing.s12),
          AppButton(
            label: 'Simpan pengaturan',
            isLoading: _saving,
            onPressed: _saving ? null : _save,
          ),
          const SizedBox(height: AppSpacing.s8),
          AppButton(
            label: 'Kirim notifikasi uji',
            variant: AppButtonVariant.secondary,
            onPressed: _test,
          ),
        ],
      ],
    ),
  );
}
