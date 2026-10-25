import 'package:flutter/material.dart';

import '../../../core/ui/app_button.dart';

class BiometricLoginButton extends StatelessWidget {
  const BiometricLoginButton({required this.onPressed, super.key});

  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) => AppButton(
    label: 'Masuk dengan sidik jari',
    variant: AppButtonVariant.text,
    onPressed: onPressed,
  );
}
