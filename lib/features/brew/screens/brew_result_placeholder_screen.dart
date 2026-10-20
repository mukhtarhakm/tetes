import 'package:flutter/material.dart';

import '../../../app/theme/tokens.dart';
import '../../../core/ui/state_views.dart';
import '../brew_session_result.dart';

class BrewResultPlaceholderScreen extends StatelessWidget {
  const BrewResultPlaceholderScreen({required this.result, super.key});

  final BrewSessionResult result;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Hasil seduh')),
      body: SafeArea(
        top: false,
        child: Padding(
          padding: AppInsets.screen,
          child: EmptyView(
            title: 'Hasil seduh',
            message:
                'Hasil seduh (dikerjakan di sesi berikutnya). Waktu total ${_formatTime(result.totalTimeS)}. Drawdown ${result.drawdownS == null ? 'dilewati' : _formatTime(result.drawdownS!)}.',
            icon: Icons.check_circle_outline_rounded,
          ),
        ),
      ),
    );
  }
}

String _formatTime(int totalSeconds) {
  final minutes = totalSeconds ~/ 60;
  final seconds = totalSeconds % 60;
  return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
}
