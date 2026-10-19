import 'package:flutter/material.dart';

import '../../../app/theme/tokens.dart';
import '../../../core/ui/state_views.dart';
import '../brew_plan.dart';

class BrewSessionPlaceholderScreen extends StatelessWidget {
  const BrewSessionPlaceholderScreen({required this.plan, super.key});

  final BrewPlan plan;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Sesi seduh')),
      body: SafeArea(
        top: false,
        child: Padding(
          padding: AppInsets.screen,
          child: EmptyView(
            title: 'Sesi seduh',
            message:
                'Sesi seduh (dikerjakan di sesi berikutnya). Rencana ${_formatNumber(plan.totalWaterG)} g sudah diterima.',
            icon: Icons.coffee_maker_outlined,
          ),
        ),
      ),
    );
  }
}

String _formatNumber(double value) {
  return value == value.roundToDouble()
      ? value.toStringAsFixed(0)
      : value.toStringAsFixed(1);
}
