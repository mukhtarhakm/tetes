import 'package:flutter/material.dart';

import '../database_gate.dart';
import '../foundation_preview_screen.dart';
import '../navigation/app_shell.dart';

abstract final class AppRoutes {
  static const home = '/';
  static const foundationPreview = '/foundation-preview';
}

abstract final class AppRouter {
  static final Map<String, WidgetBuilder> routes = {
    AppRoutes.home: (_) => const DatabaseGate(child: AppShell()),
    AppRoutes.foundationPreview: (_) => const FoundationPreviewScreen(),
  };
}
