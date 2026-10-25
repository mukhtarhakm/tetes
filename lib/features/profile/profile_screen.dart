import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as path;

import '../../app/theme/tokens.dart';
import '../../core/notifications/notification_profile_card.dart';
import '../../core/ui/app_avatar.dart';
import '../../core/ui/app_card.dart';
import '../../core/ui/app_dialog.dart';
import '../../core/ui/app_switch.dart';
import '../../core/ui/settings_row.dart';
import '../../core/ui/state_views.dart';
import '../../data/sync/sync_service.dart';
import '../../data/repositories/user_repo.dart';
import '../auth/biometric/biometric_authenticator.dart';
import '../auth/state/auth_providers.dart';
import '../auth/state/session_controller.dart';
import '../brew/state/brew_setup_controller.dart';
import 'profile_format.dart';
import 'profile_photo_service.dart';
import 'profile_stats.dart';
import 'sync_profile_card.dart';

Future<BiometricAuthenticationOutcome?> updateBiometricSetting({
  required UserRepository repository,
  required BiometricAuthenticator authenticator,
  required String userId,
  required bool enabled,
}) async {
  if (!enabled) {
    await repository.disableBiometric(userId);
    return null;
  }
  final outcome = await authenticator.authenticate();
  if (outcome == BiometricAuthenticationOutcome.success) {
    await repository.enableBiometric(userId);
  }
  return outcome;
}

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({
    required this.syncStatus,
    required this.syncError,
    required this.syncLoading,
    required this.onSync,
    required this.onPull,
    this.onPhotoChanged,
    this.photoService,
    super.key,
  });

  final SyncStatus? syncStatus;
  final String? syncError;
  final bool syncLoading;
  final VoidCallback onSync;
  final VoidCallback onPull;
  final VoidCallback? onPhotoChanged;
  final ProfilePhotoService? photoService;

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  late final ProfilePhotoService _photos;
  bool _loading = true;
  bool _busy = false;
  bool _biometricAvailable = false;
  bool _biometricEnabled = false;
  String? _error;
  Map<String, Object?>? _profile;
  File? _photo;

  @override
  void initState() {
    super.initState();
    _photos = widget.photoService ?? ProfilePhotoService();
    _load();
  }

  String? get _userId =>
      ref.read(sessionControllerProvider).asData?.value.userId;

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final userId = _userId;
      if (userId == null) throw StateError('Sesi tidak tersedia.');
      final repository = await ref.read(userRepositoryProvider.future);
      final profile = await repository.profile(userId);
      final enabled = await repository.isBiometricEnabled(userId);
      final available = await ref
          .read(biometricAuthenticatorProvider)
          .isAvailable();
      File? photo;
      final name = profile?['photo_path'] as String?;
      if (name != null) {
        try {
          final directory = await _photos.directory();
          final candidate = File(
            path.join(directory.path, path.basename(name)),
          );
          if (await candidate.exists()) photo = candidate;
        } catch (_) {
          // Initials remain available if local storage is unavailable.
        }
      }
      if (!mounted) return;
      setState(() {
        _profile = profile;
        _photo = photo;
        _biometricEnabled = enabled;
        _biometricAvailable = available;
        _loading = false;
      });
    } catch (_) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = 'Profil gagal dimuat. Coba lagi.';
        });
      }
    }
  }

  Future<void> _choosePhoto() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (sheet) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: const Text('Kamera'),
              onTap: () => Navigator.pop(sheet, ImageSource.camera),
            ),
            ListTile(
              title: const Text('Galeri'),
              onTap: () => Navigator.pop(sheet, ImageSource.gallery),
            ),
          ],
        ),
      ),
    );
    if (source == null || _busy) return;
    setState(() => _busy = true);
    try {
      final userId = _userId;
      if (userId == null) throw StateError('Sesi tidak tersedia.');
      final name = await _photos.replace(
        userId: userId,
        previousName: _profile?['photo_path'] as String?,
        source: source,
        repository: await ref.read(userRepositoryProvider.future),
      );
      if (name != null && mounted) {
        await _load();
        widget.onPhotoChanged?.call();
      }
    } catch (_) {
      _message(
        'Foto belum dapat dipilih atau disimpan. Periksa izin Kamera/Foto Tetes di Pengaturan perangkat, lalu coba lagi.',
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _setBiometric(bool enabled) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final userId = _userId;
      if (userId == null) throw StateError('Sesi tidak tersedia.');
      final repository = await ref.read(userRepositoryProvider.future);
      final result = await updateBiometricSetting(
        repository: repository,
        authenticator: ref.read(biometricAuthenticatorProvider),
        userId: userId,
        enabled: enabled,
      );
      if (enabled) {
        if (result != BiometricAuthenticationOutcome.success) {
          _message(
            result == BiometricAuthenticationOutcome.canceled
                ? 'Pemeriksaan biometrik dibatalkan.'
                : 'Biometrik belum berhasil. Pengaturan tidak diaktifkan.',
          );
          return;
        }
      }
      if (mounted) setState(() => _biometricEnabled = enabled);
    } catch (_) {
      _message('Pengaturan biometrik gagal disimpan. Coba lagi.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _verify() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final userId = _userId;
      if (userId == null) throw StateError('Sesi tidak tersedia.');
      final result = await (await ref.read(
        brewRepositoryProvider.future,
      )).verifyUserChain(userId);
      if (!mounted) return;
      final empty = result == 'utuh (0 entri)';
      final message = empty
          ? 'Belum ada seduhan untuk diverifikasi.'
          : result.startsWith('utuh')
          ? 'Jurnal utuh (${result.substring(6).replaceFirst(')', ' terverifikasi)')}'
          : '${result.replaceFirst('rantai', 'Rantai')}. Periksa data jurnal sebelum menyinkronkan.';
      await showDialog<void>(
        context: context,
        builder: (dialog) => AppDialog(
          title: 'Verifikasi Integritas Jurnal',
          message: message,
          primaryLabel: 'Tutup',
          onPrimaryPressed: () => Navigator.pop(dialog),
        ),
      );
    } catch (_) {
      _message('Jurnal gagal diverifikasi. Coba lagi.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _message(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  void _showAbout() {
    showModalBottomSheet<void>(
      context: context,
      builder: (sheet) => SafeArea(
        child: Padding(
          padding: AppInsets.dialog,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Tentang & atribusi',
                style: Theme.of(sheet).textTheme.titleLarge,
              ),
              const SizedBox(height: AppSpacing.s12),
              const Text('Tetes: jurnal dan pendamping seduh kopi V60.'),
              const SizedBox(height: AppSpacing.s12),
              const Text(
                'Data peta © OpenStreetMap contributors. Gaya dan tile vektor © OpenFreeMap bila tersedia; tile OSM standar dipakai sebagai cadangan.',
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const LoadingView(message: 'Memuat profil...');
    if (_error != null) return ErrorView(message: _error!, onRetry: _load);
    if (_profile == null) {
      return const EmptyView(message: 'Profil belum tersedia di perangkat.');
    }
    final username = _profile!['username'] as String;
    final created = DateTime.tryParse(
      _profile!['created_at'] as String? ?? '',
    )?.toLocal();
    final stats = ref.watch(profileStatsProvider).asData?.value;
    return SafeArea(
      bottom: false,
      child: ListView(
        padding: AppInsets.screen,
        children: [
          _ProfileHeader(
            username: username,
            joined: created,
            photo: _photo,
            stats: stats,
            busy: _busy,
            onChangePhoto: _choosePhoto,
          ),
          const SizedBox(height: AppSpacing.s24),
          const SettingsSectionTitle('Keamanan'),
          AppCard(
            padding: AppInsets.settingsCard,
            child: Column(
              children: [
                SettingsRow(
                  icon: Icons.fingerprint_rounded,
                  title: 'Biometrik',
                  subtitle: _biometricAvailable
                      ? 'Masuk dengan sidik jari'
                      : 'Tidak tersedia atau belum terdaftar di perangkat',
                  trailing: AppSwitch(
                    value: _biometricEnabled,
                    semanticLabel: 'Biometrik',
                    onChanged: _busy || !_biometricAvailable
                        ? null
                        : _setBiometric,
                  ),
                ),
                const SettingsDivider(),
                SettingsRow(
                  icon: Icons.verified_user_rounded,
                  tint: SettingsIconTint.accent,
                  title: 'Verifikasi integritas jurnal',
                  subtitle: 'Periksa rantai hash seduhan',
                  trailing: _busy
                      ? const SizedBox.square(
                          dimension: AppSizes.navigationIcon,
                          child: CircularProgressIndicator(
                            strokeWidth: AppSizes.progressStroke,
                          ),
                        )
                      : const Icon(
                          Icons.chevron_right_rounded,
                          color: AppColors.inkSoft,
                        ),
                  onTap: _busy ? null : _verify,
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.s24),
          const SettingsSectionTitle('Sinkronisasi'),
          SyncProfileCard(
            status: widget.syncStatus,
            error: widget.syncError,
            loading: widget.syncLoading,
            onSync: widget.onSync,
            onPull: widget.onPull,
          ),
          const SizedBox(height: AppSpacing.s24),
          const SettingsSectionTitle('Pengingat'),
          const NotificationProfileCard(),
          const SizedBox(height: AppSpacing.s24),
          AppCard(
            padding: AppInsets.settingsCard,
            child: SettingsRow(
              icon: Icons.info_outline_rounded,
              tint: SettingsIconTint.neutral,
              title: 'Tentang & atribusi',
              subtitle: 'Tetes 1.0 · OpenStreetMap, OpenFreeMap',
              trailing: const Icon(
                Icons.chevron_right_rounded,
                color: AppColors.inkSoft,
              ),
              onTap: _showAbout,
            ),
          ),
        ],
      ),
    );
  }
}

class _ProfileHeader extends StatelessWidget {
  const _ProfileHeader({
    required this.username,
    required this.joined,
    required this.photo,
    required this.stats,
    required this.busy,
    required this.onChangePhoto,
  });

  final String username;
  final DateTime? joined;
  final File? photo;
  final ProfileStats? stats;
  final bool busy;
  final VoidCallback onChangePhoto;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Stack(
                children: [
                  AppAvatar(
                    username: username,
                    photo: photo,
                    size: AppSizes.profileAvatar,
                  ),
                  Positioned(
                    right: 0,
                    bottom: 0,
                    child: Semantics(
                      button: true,
                      label: 'Ganti foto profil',
                      child: Material(
                        color: AppColors.ink,
                        shape: const CircleBorder(
                          side: BorderSide(
                            color: AppColors.surface,
                            width: AppSizes.profileBadgeBorder,
                          ),
                        ),
                        child: InkWell(
                          customBorder: const CircleBorder(),
                          onTap: busy ? null : onChangePhoto,
                          child: const SizedBox.square(
                            dimension: AppSizes.profileBadge,
                            child: Icon(
                              Icons.photo_camera_rounded,
                              size: AppSizes.profileBadgeIcon,
                              color: AppColors.onDark,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(width: AppSpacing.s16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      username.replaceAll('_', '_​'),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.s4),
                    Text(
                      joined == null
                          ? 'Tanggal bergabung belum tersedia.'
                          : 'Bergabung sejak ${formatJoinedDate(joined!)}',
                      style: textTheme.bodySmall?.copyWith(
                        color: AppColors.inkSoft,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.s16),
          Container(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.s12),
            decoration: BoxDecoration(
              color: AppColors.background,
              borderRadius: BorderRadius.circular(AppRadius.innerCard),
            ),
            child: IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    child: _Stat(
                      label: 'Seduhan',
                      value: Text(
                        stats?.brewCount.toString() ?? '-',
                        style: textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),
                  const _StatDivider(),
                  Expanded(
                    child: _Stat(
                      label: 'Biji',
                      value: Text(
                        stats?.beanCount.toString() ?? '-',
                        style: textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),
                  const _StatDivider(),
                  Expanded(
                    child: _Stat(
                      label: 'Rata-rata skor',
                      value: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            formatAverageScore(stats?.averageScore),
                            style: textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          if (stats?.averageScore != null) ...[
                            const SizedBox(width: AppSpacing.s4),
                            const Icon(
                              Icons.star_rounded,
                              color: AppColors.rating,
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value});

  final String label;
  final Widget value;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        value,
        Text(
          label,
          textAlign: TextAlign.center,
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(color: AppColors.inkSoft),
        ),
      ],
    );
  }
}

class _StatDivider extends StatelessWidget {
  const _StatDivider();

  @override
  Widget build(BuildContext context) => const SizedBox(
    width: AppSizes.dividerThickness,
    child: ColoredBox(color: AppColors.divider),
  );
}
