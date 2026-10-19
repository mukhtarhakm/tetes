import '../../../app/router/app_routes.dart';
import '../state/session_controller.dart';

Future<void> forceLogoutOnUnauthorized(
  SessionController sessionController,
) async {
  try {
    await sessionController.forceLogout();
  } finally {
    AppRouter.navigatorKey.currentState?.pushNamedAndRemoveUntil(
      AppRoutes.home,
      (_) => false,
    );
  }
}
