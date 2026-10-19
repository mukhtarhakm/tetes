import 'package:flutter/material.dart';

import '../database_gate.dart';
import '../foundation_preview_screen.dart';
import '../navigation/app_shell.dart';
import '../../features/auth/screens/login_screen.dart';
import '../../features/auth/screens/register_screen.dart';

abstract final class AppRoutes {
  static const home = '/';
  static const login = '/login';
  static const register = '/register';
  static const foundationPreview = '/foundation-preview';
}

abstract final class AppRouter {
  static final Map<String, WidgetBuilder> routes = {
    AppRoutes.home: (_) => const DatabaseGate(child: AppShell()),
    AppRoutes.login: (_) => const DatabaseGate(child: LoginScreen()),
    AppRoutes.register: (_) => const DatabaseGate(child: RegisterScreen()),
    AppRoutes.foundationPreview: (_) => const FoundationPreviewScreen(),
  };
}
