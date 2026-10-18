import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/ui/state_views.dart';
import '../data/db/database_provider.dart';
import 'theme/tokens.dart';

class DatabaseGate extends ConsumerWidget {
  const DatabaseGate({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final database = ref.watch(databaseProvider);

    return database.when(
      loading: () =>
          const Scaffold(body: LoadingView(message: 'Menyiapkan data...')),
      error: (_, _) => Scaffold(
        body: SafeArea(
          child: Padding(
            padding: AppInsets.screen,
            child: ErrorView(
              message: 'Database tidak dapat dibuka. Silakan coba lagi.',
              onRetry: () => ref.invalidate(databaseProvider),
            ),
          ),
        ),
      ),
      data: (_) => child,
    );
  }
}
