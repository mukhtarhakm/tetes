import 'package:flutter/material.dart';

import '../core/ui/state_views.dart';
import '../data/db/app_database.dart';
import 'theme/tokens.dart';

class DatabaseGate extends StatefulWidget {
  const DatabaseGate({required this.child, super.key});

  final Widget child;

  @override
  State<DatabaseGate> createState() => _DatabaseGateState();
}

class _DatabaseGateState extends State<DatabaseGate> {
  late Future<void> _opening;

  @override
  void initState() {
    super.initState();
    _opening = _openDatabase();
  }

  Future<void> _openDatabase() async {
    await AppDatabase.instance.open();
  }

  void _retry() {
    setState(() {
      _opening = _openDatabase();
    });
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<void>(
      future: _opening,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Scaffold(
            body: LoadingView(message: 'Menyiapkan data...'),
          );
        }

        if (snapshot.hasError) {
          return Scaffold(
            body: SafeArea(
              child: Padding(
                padding: AppInsets.screen,
                child: ErrorView(
                  message: 'Database tidak dapat dibuka. Silakan coba lagi.',
                  onRetry: _retry,
                ),
              ),
            ),
          );
        }

        return widget.child;
      },
    );
  }
}
