import 'package:flutter/foundation.dart' show setEquals;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme/tokens.dart';
import '../../features/auth/state/session_controller.dart';
import '../../features/profile/profile_format.dart';
import '../ui/app_button.dart';
import '../ui/app_card.dart';
import '../ui/app_dialog.dart';
import '../ui/app_switch.dart';
import '../ui/settings_row.dart';
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
  static const _thresholdStepG = 5.0;
  static const _thresholdMaxG = 500.0;

  bool _loading = true;
  bool _saving = false;
  bool _enabled = false;
  bool? _permission;
  String? _error;
  TimeOfDay _time = const TimeOfDay(hour: 8, minute: 0);
  Set<int> _selectedDays = {1, 2, 3, 4, 5, 6, 7};
  double _thresholdG = 15;
  NotificationSettings? _saved;

  bool get _dirty {
    final saved = _saved;
    if (saved == null) return false;
    return saved.enabled != _enabled ||
        saved.hour != _time.hour ||
        saved.minute != _time.minute ||
        saved.stockThresholdG != _thresholdG ||
        !setEquals(saved.days, _selectedDays);
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _apply(NotificationSettings settings) {
    _enabled = settings.enabled;
    _time = TimeOfDay(hour: settings.hour, minute: settings.minute);
    _selectedDays = {...settings.days};
    _thresholdG = settings.stockThresholdG;
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
        _apply(settings);
        _saved = settings;
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
    if (_thresholdG < 0 || _thresholdG > _thresholdMaxG) {
      setState(() => _error = 'Ambang stok harus 0 sampai 500 gram.');
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
      final settings = NotificationSettings(
        enabled: _enabled,
        hour: _time.hour,
        minute: _time.minute,
        days: {..._selectedDays},
        stockThresholdG: _thresholdG,
      );
      await (await ref.read(
        notificationCoordinatorProvider.future,
      )).saveSettings(userId, settings);
      if (mounted) {
        setState(() => _saved = settings);
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

  void _cancelChanges() {
    final saved = _saved;
    if (saved == null) return;
    setState(() {
      _apply(saved);
      _error = null;
    });
  }

  Future<void> _test() async {
    if (_permission != true && !await _requestPermission()) return;
    try {
      await (await ref.read(notificationCoordinatorProvider.future)).showTest();
    } catch (_) {
      if (mounted) setState(() => _error = 'Notifikasi uji gagal dikirim.');
    }
  }

  Future<void> _pickTime() async {
    final selected = await showTimePicker(
      context: context,
      initialTime: _time,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true),
        child: child!,
      ),
    );
    if (selected != null && mounted) setState(() => _time = selected);
  }

  void _changeThreshold(double delta) {
    setState(() {
      _thresholdG = (_thresholdG + delta).clamp(0, _thresholdMaxG).toDouble();
    });
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    if (_loading) return const AppCard(child: LoadingView());
    if (_error != null && _permission == null) {
      return AppCard(
        child: ErrorView(message: _error!, onRetry: _load),
      );
    }
    return AppCard(
      padding: AppInsets.settingsCard,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_permission != true) ...[
            Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.s12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Izin belum aktif. Aktifkan notifikasi di Pengaturan perangkat jika pernah menolak.',
                    style: textTheme.bodySmall?.copyWith(
                      color: AppColors.inkSoft,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.s8),
                  AppButton(
                    label: 'Minta izin notifikasi',
                    variant: AppButtonVariant.secondary,
                    onPressed: _requestPermission,
                  ),
                ],
              ),
            ),
            const SettingsDivider(),
          ],
          SettingsRow(
            icon: Icons.notifications_rounded,
            title: 'Pengingat seduh harian',
            subtitle: _enabled
                ? '${describeReminderDays(_selectedDays)}, ${formatClock(_time.hour, _time.minute)}'
                : 'Nonaktif',
            trailing: AppSwitch(
              value: _enabled,
              semanticLabel: 'Pengingat seduh harian',
              onChanged: (value) => setState(() => _enabled = value),
            ),
          ),
          if (_enabled) ...[
            _TimeRow(
              label: formatClock(_time.hour, _time.minute),
              onTap: _pickTime,
            ),
            const SizedBox(height: AppSpacing.s12),
            Row(
              children: [
                for (var index = 0; index < 7; index++) ...[
                  if (index > 0) const SizedBox(width: AppSpacing.s4),
                  Expanded(
                    child: _DayChip(
                      label: _days[index],
                      selected: _selectedDays.contains(index + 1),
                      onTap: () => setState(() {
                        final day = index + 1;
                        if (!_selectedDays.remove(day)) _selectedDays.add(day);
                      }),
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: AppSpacing.s12),
          ],
          const SettingsDivider(),
          SettingsRow(
            icon: Icons.inventory_2_rounded,
            tint: SettingsIconTint.accent,
            title: 'Ambang stok menipis',
            subtitle: 'Ingatkan bila sisa di bawah ini',
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton.outlined(
                  tooltip: 'Kurangi',
                  onPressed: _thresholdG <= 0
                      ? null
                      : () => _changeThreshold(-_thresholdStepG),
                  icon: const Icon(Icons.remove_rounded),
                  style: IconButton.styleFrom(
                    foregroundColor: AppColors.ink,
                    side: const BorderSide(color: AppColors.divider),
                    fixedSize: const Size.square(AppSizes.stepperButton),
                  ),
                ),
                SizedBox(
                  width: AppSizes.stepperValueWidth,
                  child: Text(
                    '${_thresholdG.toStringAsFixed(0)} g',
                    textAlign: TextAlign.center,
                    style: textTheme.titleLarge,
                  ),
                ),
                IconButton.outlined(
                  tooltip: 'Tambah',
                  onPressed: _thresholdG >= _thresholdMaxG
                      ? null
                      : () => _changeThreshold(_thresholdStepG),
                  icon: const Icon(Icons.add_rounded),
                  style: IconButton.styleFrom(
                    foregroundColor: AppColors.ink,
                    side: const BorderSide(color: AppColors.divider),
                    fixedSize: const Size.square(AppSizes.stepperButton),
                  ),
                ),
              ],
            ),
          ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.s8),
              child: Text(
                _error!,
                style: textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.error,
                ),
              ),
            ),
          if (_dirty)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.s12),
              child: Row(
                children: [
                  Expanded(
                    child: AppButton(
                      label: 'Simpan perubahan',
                      isLoading: _saving,
                      onPressed: _saving ? null : _save,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.s8),
                  AppButton(
                    label: 'Batal',
                    variant: AppButtonVariant.text,
                    expand: false,
                    onPressed: _saving ? null : _cancelChanges,
                  ),
                ],
              ),
            ),
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.s12),
            child: AppButton(
              label: 'Kirim notifikasi uji',
              variant: AppButtonVariant.secondary,
              icon: Icons.send_rounded,
              onPressed: _test,
            ),
          ),
        ],
      ),
    );
  }
}

class _TimeRow extends StatelessWidget {
  const _TimeRow({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Semantics(
      button: true,
      label: 'Jam pengingat $label',
      onTap: onTap,
      child: Material(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(AppRadius.innerCard),
        child: InkWell(
          borderRadius: BorderRadius.circular(AppRadius.innerCard),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.s16,
              vertical: AppSpacing.s12,
            ),
            child: Row(
              children: [
                const Icon(Icons.schedule_rounded),
                const SizedBox(width: AppSpacing.s12),
                Expanded(
                  child: Text(
                    'Jam',
                    style: textTheme.bodyLarge?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                Text(
                  label,
                  style: textTheme.bodyLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const Icon(
                  Icons.chevron_right_rounded,
                  color: AppColors.inkSoft,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DayChip extends StatelessWidget {
  const _DayChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      onTap: onTap,
      child: ExcludeSemantics(
        child: Material(
          color: selected ? AppColors.primary : AppColors.surface,
          shape: StadiumBorder(
            side: selected
                ? BorderSide.none
                : const BorderSide(color: AppColors.divider),
          ),
          child: InkWell(
            customBorder: const StadiumBorder(),
            onTap: onTap,
            child: SizedBox(
              height: AppSizes.dayChipHeight,
              child: Center(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    label,
                    style: textTheme.bodySmall?.copyWith(
                      color: selected ? AppColors.ink : AppColors.inkSoft,
                      fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
