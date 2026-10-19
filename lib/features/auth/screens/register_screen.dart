import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/router/app_routes.dart';
import '../../../app/theme/tokens.dart';
import '../../../core/ui/app_button.dart';
import '../../../core/ui/app_text_field.dart';
import '../auth_validation.dart';
import '../state/auth_controller.dart';

class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmationController = TextEditingController();

  Map<String, String> _validationErrors = const {};
  bool _obscurePassword = true;
  bool _obscureConfirmation = true;

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    _confirmationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authControllerProvider);

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: AppInsets.screen,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Buat akun Tetes',
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: AppSpacing.s8),
              Text(
                'Simpan jurnal seduhmu dengan akun yang dibuat di server Tetes.',
                style: Theme.of(
                  context,
                ).textTheme.bodyLarge?.copyWith(color: AppColors.inkSoft),
              ),
              const SizedBox(height: AppSpacing.s32),
              AppTextField(
                controller: _usernameController,
                label: 'Username',
                hintText: '3-30 huruf kecil, angka, titik, atau garis bawah',
                errorText:
                    _validationErrors['username'] ??
                    authState.fieldErrors['username'],
                prefixIcon: Icons.person_add_alt_1_outlined,
                enabled: !authState.isLoading,
                textInputAction: TextInputAction.next,
                onChanged: (_) => _clearFieldError('username'),
              ),
              const SizedBox(height: AppSpacing.s20),
              AppTextField(
                controller: _passwordController,
                label: 'Password',
                hintText: '8-128 karakter',
                errorText:
                    _validationErrors['password'] ??
                    authState.fieldErrors['password'],
                prefixIcon: Icons.lock_outline_rounded,
                suffixIcon: _passwordVisibilityButton(
                  obscured: _obscurePassword,
                  enabled: !authState.isLoading,
                  onPressed: () {
                    setState(() {
                      _obscurePassword = !_obscurePassword;
                    });
                  },
                ),
                obscureText: _obscurePassword,
                enabled: !authState.isLoading,
                keyboardType: TextInputType.visiblePassword,
                textInputAction: TextInputAction.next,
                onChanged: (_) => _clearFieldError('password'),
              ),
              const SizedBox(height: AppSpacing.s20),
              AppTextField(
                controller: _confirmationController,
                label: 'Konfirmasi password',
                errorText: _validationErrors['confirmation'],
                prefixIcon: Icons.lock_reset_rounded,
                suffixIcon: _passwordVisibilityButton(
                  obscured: _obscureConfirmation,
                  enabled: !authState.isLoading,
                  onPressed: () {
                    setState(() {
                      _obscureConfirmation = !_obscureConfirmation;
                    });
                  },
                ),
                obscureText: _obscureConfirmation,
                enabled: !authState.isLoading,
                keyboardType: TextInputType.visiblePassword,
                textInputAction: TextInputAction.done,
                onChanged: (_) => _clearFieldError('confirmation'),
              ),
              if (authState.errorMessage != null) ...[
                const SizedBox(height: AppSpacing.s16),
                Semantics(
                  liveRegion: true,
                  child: Text(
                    authState.errorMessage!,
                    style: Theme.of(
                      context,
                    ).textTheme.bodyMedium?.copyWith(color: AppColors.error),
                  ),
                ),
              ],
              const SizedBox(height: AppSpacing.s24),
              AppButton(
                label: 'Daftar',
                isLoading: authState.isLoading,
                onPressed: authState.isLoading ? null : _submit,
              ),
              const SizedBox(height: AppSpacing.s12),
              AppButton(
                label: 'Sudah punya akun? Masuk',
                variant: AppButtonVariant.text,
                onPressed: authState.isLoading
                    ? null
                    : () {
                        ref.read(authControllerProvider.notifier).clearErrors();
                        Navigator.of(
                          context,
                        ).pushReplacementNamed(AppRoutes.login);
                      },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _passwordVisibilityButton({
    required bool obscured,
    required bool enabled,
    required VoidCallback onPressed,
  }) {
    return IconButton(
      tooltip: obscured ? 'Tampilkan password' : 'Sembunyikan password',
      onPressed: enabled ? onPressed : null,
      icon: Icon(
        obscured ? Icons.visibility_outlined : Icons.visibility_off_outlined,
      ),
    );
  }

  Future<void> _submit() async {
    final username = _usernameController.text;
    final password = _passwordController.text;
    final confirmation = _confirmationController.text;
    final errors = <String, String>{};
    final usernameError = AuthValidation.username(username);
    final passwordError = AuthValidation.password(password);
    final confirmationError = AuthValidation.confirmation(
      password,
      confirmation,
    );
    if (usernameError != null) {
      errors['username'] = usernameError;
    }
    if (passwordError != null) {
      errors['password'] = passwordError;
    }
    if (confirmationError != null) {
      errors['confirmation'] = confirmationError;
    }

    if (errors.isNotEmpty) {
      setState(() {
        _validationErrors = errors;
      });
      return;
    }

    if (_validationErrors.isNotEmpty) {
      setState(() {
        _validationErrors = const {};
      });
    }

    final succeeded = await ref
        .read(authControllerProvider.notifier)
        .register(username: username, password: password);
    if (succeeded && mounted) {
      Navigator.of(
        context,
      ).pushNamedAndRemoveUntil(AppRoutes.home, (_) => false);
    }
  }

  void _clearFieldError(String field) {
    final fieldsToClear = {field, if (field == 'password') 'confirmation'};
    if (fieldsToClear.any(_validationErrors.containsKey)) {
      setState(() {
        _validationErrors = Map.of(_validationErrors)
          ..removeWhere((key, _) => fieldsToClear.contains(key));
      });
    }
    ref.read(authControllerProvider.notifier).clearErrors();
  }
}
