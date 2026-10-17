import 'package:flutter/material.dart';

import 'app/router/app_routes.dart';
import 'app/theme/app_theme.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Tetes',
      theme: AppTheme.light,
      themeMode: ThemeMode.light,
      initialRoute: AppRoutes.home,
      routes: AppRouter.routes,
    );
  }
}
