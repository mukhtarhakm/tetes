import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as path;

import '../../app/theme/tokens.dart';
import '../../core/notifications/notification_profile_card.dart';
import '../../core/ui/app_avatar.dart';
import '../../core/ui/app_button.dart';
import '../../core/ui/app_card.dart';
import '../../core/ui/app_dialog.dart';
import '../../core/ui/state_views.dart';
import '../../data/sync/sync_service.dart';
import '../../data/repositories/user_repo.dart';
import '../auth/biometric/biometric_authenticator.dart';
import '../auth/state/auth_providers.dart';
import '../auth/state/session_controller.dart';
import '../brew/state/brew_setup_controller.dart';
import 'profile_photo_service.dart';
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
    this.photoService,
    super.key,
  });

  final SyncStatus? syncStatus;
  final String? syncError;
  final bool syncLoading;
  final VoidCallback onSync;
  final VoidCallback onPull;
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
      if (name != null && mounted) await _load();
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
    return SafeArea(
      bottom: false,
      child: ListView(
        padding: AppInsets.screen,
        children: [
          AppCard(
            child: Row(
              children: [
                AppAvatar(username: username, photo: _photo),
                const SizedBox(width: AppSpacing.s16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        username,
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      AppButton(
                        label: 'Ganti foto',
                        variant: AppButtonVariant.text,
                        expand: false,
                        onPressed: _busy ? null : _choosePhoto,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.s12),
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Akun', style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: AppSpacing.s8),
                Text('Username: $username'),
                Text(
                  created == null
                      ? 'Tanggal bergabung belum tersedia.'
                      : 'Bergabung: ${MaterialLocalizations.of(context).formatMediumDate(created)}',
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.s12),
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Keamanan', style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: AppSpacing.s8),
                if (_biometricAvailable)
                  SwitchListTile(
                    title: const Text('Biometrik'),
                    value: _biometricEnabled,
                    onChanged: _busy ? null : _setBiometric,
                  )
                else
                  const Text(
                    'Biometrik tidak tersedia atau belum terdaftar di perangkat.',
                  ),
                const SizedBox(height: AppSpacing.s8),
                AppButton(
                  label: 'Verifikasi Integritas Jurnal',
                  isLoading: _busy,
                  onPressed: _busy ? null : _verify,
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.s12),
          SyncProfileCard(
            status: widget.syncStatus,
            error: widget.syncError,
            loading: widget.syncLoading,
            onSync: widget.onSync,
            onPull: widget.onPull,
          ),
          const SizedBox(height: AppSpacing.s12),
          const NotificationProfileCard(),
          const SizedBox(height: AppSpacing.s12),
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Tentang', style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: AppSpacing.s8),
                const Text(
                  'Data peta © OpenStreetMap contributors. Gaya dan tile vektor © OpenFreeMap bila tersedia; tile OSM standar dipakai sebagai cadangan.',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
