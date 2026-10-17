import 'package:flutter/material.dart';

import '../../app/theme/tokens.dart';
import 'app_button.dart';

class LoadingView extends StatelessWidget {
  const LoadingView({this.message = 'Memuat...', super.key});

  final String? message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CircularProgressIndicator(),
          if (message != null) ...[
            const SizedBox(height: AppSpacing.s16),
            Text(message!, style: Theme.of(context).textTheme.bodyLarge),
          ],
        ],
      ),
    );
  }
}

class EmptyView extends StatelessWidget {
  const EmptyView({
    required this.message,
    this.title = 'Belum ada isi',
    this.icon = Icons.inbox_outlined,
    this.actionLabel,
    this.onActionPressed,
    super.key,
  });

  final String title;
  final String message;
  final IconData icon;
  final String? actionLabel;
  final VoidCallback? onActionPressed;

  @override
  Widget build(BuildContext context) {
    return _StateView(
      icon: icon,
      title: title,
      message: message,
      actionLabel: actionLabel,
      onActionPressed: onActionPressed,
    );
  }
}

class ErrorView extends StatelessWidget {
  const ErrorView({
    required this.message,
    required this.onRetry,
    this.title = 'Terjadi masalah',
    super.key,
  });

  final String title;
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return _StateView(
      icon: Icons.error_outline_rounded,
      iconColor: AppColors.error,
      title: title,
      message: message,
      actionLabel: 'Coba lagi',
      onActionPressed: onRetry,
    );
  }
}

class _StateView extends StatelessWidget {
  const _StateView({
    required this.icon,
    required this.title,
    required this.message,
    this.iconColor = AppColors.ink,
    this.actionLabel,
    this.onActionPressed,
  });

  final IconData icon;
  final Color iconColor;
  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onActionPressed;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: AppSizes.stateIconContainer,
            height: AppSizes.stateIconContainer,
            decoration: const BoxDecoration(
              color: AppColors.primaryContainer,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: AppSizes.stateIcon, color: iconColor),
          ),
          const SizedBox(height: AppSpacing.s16),
          Text(
            title,
            style: Theme.of(context).textTheme.titleLarge,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.s8),
          Text(
            message,
            style: Theme.of(
              context,
            ).textTheme.bodyLarge?.copyWith(color: AppColors.inkSoft),
            textAlign: TextAlign.center,
          ),
          if (actionLabel != null) ...[
            const SizedBox(height: AppSpacing.s20),
            AppButton(
              label: actionLabel!,
              onPressed: onActionPressed,
              expand: false,
            ),
          ],
        ],
      ),
    );
  }
}
