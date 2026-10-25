import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/router/app_routes.dart';
import '../../../app/theme/tokens.dart';
import '../../../core/config/app_config.dart';
import '../../../core/ui/app_button.dart';
import '../../../core/ui/app_text_field.dart';
import '../auth_validation.dart';
import '../state/auth_controller.dart';
import '../state/auth_providers.dart';
import '../widgets/biometric_login_button.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({this.sessionMessage, super.key});

  final String? sessionMessage;

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();

  Map<String, String> _validationErrors = const {};
  bool _obscurePassword = true;
  String? _biometricUsername;

  @override
  void initState() {
    super.initState();
    _refreshBiometric();
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authControllerProvider);
    const configurationMissing =
        AppConfig.supabaseUrl == '' || AppConfig.supabaseAnonKey == '';

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: AppInsets.screen,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Masuk ke Tetes',
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: AppSpacing.s8),
              Text(
                'Lanjutkan jurnal dan panduan seduh V60 milikmu.',
                style: Theme.of(
                  context,
                ).textTheme.bodyLarge?.copyWith(color: AppColors.inkSoft),
              ),
              const SizedBox(height: AppSpacing.s32),
              AppTextField(
                controller: _usernameController,
                label: 'Username',
                hintText: 'contoh: rais_mukhtar',
                errorText:
                    _validationErrors['username'] ??
                    authState.fieldErrors['username'],
                prefixIcon: Icons.person_outline_rounded,
                enabled: !authState.isLoading,
                textInputAction: TextInputAction.next,
                onChanged: (_) {
                  _clearFieldError('username');
                  _refreshBiometric();
                },
              ),
              const SizedBox(height: AppSpacing.s20),
              AppTextField(
                controller: _passwordController,
                label: 'Password',
                errorText:
                    _validationErrors['password'] ??
                    authState.fieldErrors['password'],
                prefixIcon: Icons.lock_outline_rounded,
                suffixIcon: IconButton(
                  tooltip: _obscurePassword
                      ? 'Tampilkan password'
                      : 'Sembunyikan password',
                  onPressed: authState.isLoading
                      ? null
                      : () {
                          setState(() {
                            _obscurePassword = !_obscurePassword;
                          });
                        },
                  icon: Icon(
                    _obscurePassword
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined,
                  ),
                ),
                obscureText: _obscurePassword,
                enabled: !authState.isLoading,
                keyboardType: TextInputType.visiblePassword,
                textInputAction: TextInputAction.done,
                onChanged: (_) => _clearFieldError('password'),
              ),
              if (authState.errorMessage != null ||
                  widget.sessionMessage != null ||
                  configurationMissing) ...[
                const SizedBox(height: AppSpacing.s16),
                Semantics(
                  liveRegion: true,
                  child: Text(
                    authState.errorMessage ??
                        widget.sessionMessage ??
                        'Konfigurasi Supabase belum tersedia. Isi env/app.json lalu jalankan ulang aplikasi.',
                    style: Theme.of(
                      context,
                    ).textTheme.bodyMedium?.copyWith(color: AppColors.error),
                  ),
                ),
              ],
              const SizedBox(height: AppSpacing.s24),
              AppButton(
                label: 'Masuk',
                isLoading: authState.isLoading,
                onPressed: authState.isLoading ? null : _submit,
              ),
              if (_biometricUsername != null) ...[
                const SizedBox(height: AppSpacing.s12),
                BiometricLoginButton(
                  onPressed: authState.isLoading ? null : _loginBiometric,
                ),
              ],
              const SizedBox(height: AppSpacing.s12),
              AppButton(
                label: 'Belum punya akun? Daftar',
                variant: AppButtonVariant.text,
                onPressed: authState.isLoading
                    ? null
                    : () {
                        ref.read(authControllerProvider.notifier).clearErrors();
                        Navigator.of(
                          context,
                        ).pushReplacementNamed(AppRoutes.register);
                      },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _refreshBiometric() async {
    try {
      final available = await ref
          .read(biometricAuthenticatorProvider)
          .isAvailable();
      final typed = _usernameController.text.trim();
      final username = available
          ? await (await ref.read(
              userRepositoryProvider.future,
            )).availableBiometricUsername(typed.isEmpty ? null : typed)
          : null;
      if (mounted && _usernameController.text.trim() == typed) {
        setState(() => _biometricUsername = username);
      }
    } catch (_) {
      if (mounted) setState(() => _biometricUsername = null);
    }
  }

  Future<void> _loginBiometric() async {
    final username = _biometricUsername;
    if (username == null) return;
    final succeeded = await ref
        .read(authControllerProvider.notifier)
        .loginBiometric(username);
    if (succeeded && mounted) {
      Navigator.of(
        context,
      ).pushNamedAndRemoveUntil(AppRoutes.home, (_) => false);
    } else {
      _refreshBiometric();
    }
  }

  Future<void> _submit() async {
    final username = _usernameController.text;
    final password = _passwordController.text;
    final errors = <String, String>{};
    final usernameError = AuthValidation.username(username);
    final passwordError = AuthValidation.password(password);
    if (usernameError != null) {
      errors['username'] = usernameError;
    }
    if (passwordError != null) {
      errors['password'] = passwordError;
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
        .login(username: username, password: password);
    if (succeeded && mounted) {
      Navigator.of(
        context,
      ).pushNamedAndRemoveUntil(AppRoutes.home, (_) => false);
    }
  }

  void _clearFieldError(String field) {
    if (_validationErrors.containsKey(field)) {
      setState(() {
        _validationErrors = Map.of(_validationErrors)..remove(field);
      });
    }
    ref.read(authControllerProvider.notifier).clearErrors();
  }
}
