import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/ui/app_dialog.dart';
import '../../../data/repositories/user_repo.dart';
import '../biometric/biometric_authenticator.dart';
import '../state/auth_providers.dart';

enum _BiometricOfferChoice { enable, later, never }

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
      // Ditawarkan di setiap login dengan password selama biometrik mati,
      // kecuali pengguna memilih "Jangan tampilkan lagi".
      if (await repository.isBiometricEnabled(widget.userId) ||
          await repository.isBiometricOfferHidden(widget.userId)) {
        return;
      }

      final authenticator = ref.read(biometricAuthenticatorProvider);
      if (!await authenticator.isAvailable() || !mounted) {
        return;
      }

      final choice = await showDialog<_BiometricOfferChoice>(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) => const _BiometricOfferDialog(),
      );
      if (!mounted) {
        return;
      }
      if (choice == _BiometricOfferChoice.never) {
        await repository.hideBiometricOffer(widget.userId);
        return;
      }
      if (choice == _BiometricOfferChoice.later) {
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

class _BiometricOfferDialog extends StatefulWidget {
  const _BiometricOfferDialog();

  @override
  State<_BiometricOfferDialog> createState() => _BiometricOfferDialogState();
}

class _BiometricOfferDialogState extends State<_BiometricOfferDialog> {
  bool _neverAgain = false;

  @override
  Widget build(BuildContext context) {
    return AppDialog(
      title: 'Aktifkan biometrik?',
      message: 'Gunakan sidik jari untuk masuk setelah keluar dari Tetes.',
      content: CheckboxListTile(
        key: const Key('biometric-offer-never'),
        value: _neverAgain,
        onChanged: (value) => setState(() => _neverAgain = value ?? false),
        title: const Text('Jangan tampilkan lagi'),
        controlAffinity: ListTileControlAffinity.leading,
        contentPadding: EdgeInsets.zero,
        dense: true,
      ),
      primaryLabel: 'Ya',
      onPrimaryPressed: () =>
          Navigator.of(context).pop(_BiometricOfferChoice.enable),
      secondaryLabel: 'Nanti',
      onSecondaryPressed: () => Navigator.of(context).pop(
        _neverAgain ? _BiometricOfferChoice.never : _BiometricOfferChoice.later,
      ),
    );
  }
}
