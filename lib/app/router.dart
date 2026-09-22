import 'package:flutter/material.dart';

import '../features/account/account_screen.dart';
import '../features/auth/authenticated_screen.dart';
import '../features/auth/code_screen.dart';
import '../features/auth/controllers/auth_controller.dart';
import '../features/auth/login_page.dart';
import '../features/auth/password_screen.dart';
import '../features/auth/phone_screen.dart';
import '../features/auth/startup_screen.dart';
import '../features/auth/widgets/onboarding_screen.dart';
import '../features/home/home_screen.dart';

/// Central route names for Nuvex.
abstract class NuvexRoutes {
  static const String initial = '/';
  static const String gettingStarted = '/getting-started';
  static const String credentials = '/credentials';
  static const String phone = '/phone';
  static const String code = '/code';
  static const String password = '/password';
  static const String authenticated = '/authenticated';
  static const String home = '/home';
  static const String account = '/account';
}

/// Simple declarative navigation route generator.
abstract class NuvexRouter {
  static Route<dynamic> onGenerateRoute(RouteSettings settings) {
    switch (settings.name) {
      case NuvexRoutes.account:
        return MaterialPageRoute(
          settings: settings,
          builder: (_) => const AccountScreen(),
        );
      case NuvexRoutes.gettingStarted:
        return MaterialPageRoute(
          settings: settings,
          builder: (_) => const OnboardingScreen(),
        );
      case NuvexRoutes.credentials:
        final controller = settings.arguments as AuthController?;
        return MaterialPageRoute(
          settings: settings,
          builder: (_) => LoginPage(controller: controller),
        );
      case NuvexRoutes.phone:
        final controller =
            settings.arguments as AuthController? ?? AuthController();
        return MaterialPageRoute(
          settings: settings,
          builder: (_) => PhoneScreen(controller: controller),
        );
      case NuvexRoutes.code:
        final controller =
            settings.arguments as AuthController? ?? AuthController();
        return MaterialPageRoute(
          settings: settings,
          builder: (_) => CodeScreen(controller: controller),
        );
      case NuvexRoutes.password:
        final controller =
            settings.arguments as AuthController? ?? AuthController();
        return MaterialPageRoute(
          settings: settings,
          builder: (_) => Password2FAScreen(controller: controller),
        );
      case NuvexRoutes.authenticated:
        final controller =
            settings.arguments as AuthController? ?? AuthController();
        return MaterialPageRoute(
          settings: settings,
          builder: (_) => AuthenticatedScreen(controller: controller),
        );
      case NuvexRoutes.home:
        final controller =
            settings.arguments as AuthController? ?? AuthController();
        return MaterialPageRoute(
          settings: settings,
          builder: (_) => HomeScreen(controller: controller),
        );
      case NuvexRoutes.initial:
      default:
        final controller = settings.arguments as AuthController?;
        return MaterialPageRoute(
          settings: settings,
          builder: (_) => StartupScreen(controller: controller),
        );
    }
  }
}
