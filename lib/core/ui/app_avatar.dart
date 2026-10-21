import 'dart:io';

import 'package:flutter/material.dart';

import '../../app/theme/tokens.dart';

class AppAvatar extends StatelessWidget {
  const AppAvatar({required this.username, this.photo, super.key});

  final String username;
  final File? photo;

  @override
  Widget build(BuildContext context) {
    final initial = username.trim().isEmpty
        ? '?'
        : username.trim().substring(0, 1).toUpperCase();
    final fallback = Center(
      child: Text(initial, style: Theme.of(context).textTheme.headlineMedium),
    );
    return ClipOval(
      child: Container(
        width: AppSizes.stateIconContainer,
        height: AppSizes.stateIconContainer,
        color: Theme.of(context).colorScheme.primaryContainer,
        child: photo == null || !photo!.existsSync()
            ? fallback
            : Image.file(
                photo!,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => fallback,
              ),
      ),
    );
  }
}
