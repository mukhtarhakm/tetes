import 'dart:io';

import 'package:flutter/material.dart';

import '../../app/theme/tokens.dart';

class AppAvatar extends StatelessWidget {
  const AppAvatar({
    required this.username,
    this.photo,
    this.size = AppSizes.stateIconContainer,
    super.key,
  });

  final String username;
  final File? photo;
  final double size;

  @override
  Widget build(BuildContext context) {
    final initial = username.trim().isEmpty
        ? '?'
        : username.trim().substring(0, 1).toUpperCase();
    final fallback = Center(
      child: Text(
        initial,
        style: size >= AppSizes.stateIconContainer
            ? Theme.of(context).textTheme.headlineMedium
            : Theme.of(context).textTheme.labelLarge,
      ),
    );
    return ClipOval(
      child: Container(
        width: size,
        height: size,
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
