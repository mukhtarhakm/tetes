import 'package:flutter/material.dart';

import '../database_gate.dart';
import '../../features/auth/screens/login_screen.dart';
import '../../features/auth/screens/register_screen.dart';
import '../../features/auth/widgets/session_gate.dart';

abstract final class AppRoutes {
  static const home = '/';
  static const login = '/login';
  static const register = '/register';
}

abstract final class AppRouter {
  static final navigatorKey = GlobalKey<NavigatorState>();

  static final Map<String, WidgetBuilder> routes = {
    AppRoutes.home: (_) => const DatabaseGate(child: SessionGate()),
    AppRoutes.login: (_) => const DatabaseGate(child: LoginScreen()),
    AppRoutes.register: (_) => const DatabaseGate(child: RegisterScreen()),
  };
}
