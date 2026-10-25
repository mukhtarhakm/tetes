import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/ui/app_dialog.dart';
import '../../../data/repositories/user_repo.dart';
import '../biometric/biometric_authenticator.dart';
import '../state/auth_providers.dart';

enum _BiometricOfferChoice { enable, later }

class PostAuthBiometricOffer extends ConsumerStatefulWidget {
  const PostAuthBiometricOffer({
    required this.userId,
    required this.child,
    super.key,
  });

  final String userId;
  final Widget child;

  @override
  ConsumerState<PostAuthBiometricOffer> createState() =>
      _PostAuthBiometricOfferState();
}

class _PostAuthBiometricOfferState
    extends ConsumerState<PostAuthBiometricOffer> {
  bool _offerScheduled = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _offerScheduled) {
        return;
      }
      _offerScheduled = true;
      unawaited(_offerBiometricIfNeeded());
    });
  }

  @override
  Widget build(BuildContext context) => widget.child;

  Future<void> _offerBiometricIfNeeded() async {
    try {
      final repository = await ref.read(userRepositoryProvider.future);
      if (await repository.wasBiometricPrompted(widget.userId)) {
        return;
      }

      final authenticator = ref.read(biometricAuthenticatorProvider);
      if (!await authenticator.isAvailable() || !mounted) {
        return;
      }

      final choice = await showDialog<_BiometricOfferChoice>(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) => AppDialog(
          title: 'Aktifkan biometrik?',
          message: 'Gunakan sidik jari untuk masuk setelah keluar dari Tetes.',
          primaryLabel: 'Ya',
          onPrimaryPressed: () =>
              Navigator.of(dialogContext).pop(_BiometricOfferChoice.enable),
          secondaryLabel: 'Nanti',
          onSecondaryPressed: () =>
              Navigator.of(dialogContext).pop(_BiometricOfferChoice.later),
        ),
      );
      if (!mounted) {
        return;
      }
      if (choice == _BiometricOfferChoice.later) {
        await repository.markBiometricPrompted(widget.userId);
        return;
      }
      if (choice != _BiometricOfferChoice.enable) {
        return;
      }

      await _verifyAndEnable(repository, authenticator);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            const SnackBar(
              content: Text('Pengaturan biometrik belum dapat disimpan.'),
            ),
          );
      }
    }
  }

  Future<void> _verifyAndEnable(
    UserRepository repository,
    BiometricAuthenticator authenticator,
  ) async {
    while (mounted) {
      final outcome = await authenticator.authenticate();
      if (!mounted) {
        return;
      }
      if (outcome == BiometricAuthenticationOutcome.success) {
        await repository.enableBiometric(widget.userId);
        return;
      }
      if (outcome == BiometricAuthenticationOutcome.unavailable) {
        await _showUnavailableMessage();
        return;
      }

      final retry = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) => AppDialog(
          title: 'Biometrik belum aktif',
          message: _messageFor(outcome),
          primaryLabel: 'Coba lagi',
          onPrimaryPressed: () => Navigator.of(dialogContext).pop(true),
          secondaryLabel: 'Nanti',
          onSecondaryPressed: () => Navigator.of(dialogContext).pop(false),
        ),
      );
      if (retry != true) {
        await repository.markBiometricPrompted(widget.userId);
        return;
      }
    }
  }

  Future<void> _showUnavailableMessage() {
    return showDialog<void>(
      context: context,
      builder: (dialogContext) => AppDialog(
        title: 'Biometrik tidak tersedia',
        message:
            'Biometrik tidak lagi tersedia atau terdaftar. Pengaturan tidak diaktifkan.',
        primaryLabel: 'Lanjutkan',
        onPrimaryPressed: () => Navigator.of(dialogContext).pop(),
      ),
    );
  }

  String _messageFor(BiometricAuthenticationOutcome outcome) {
    return switch (outcome) {
      BiometricAuthenticationOutcome.canceled =>
        'Pemeriksaan biometrik dibatalkan.',
      BiometricAuthenticationOutcome.lockedOut =>
        'Biometrik sedang dikunci oleh sistem. Coba lagi nanti.',
      BiometricAuthenticationOutcome.failed =>
        'Biometrik tidak dikenali. Silakan coba lagi.',
      _ => 'Biometrik tidak dapat diperiksa. Silakan coba lagi.',
    };
  }
}
