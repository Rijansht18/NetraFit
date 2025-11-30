import 'package:flutter/material.dart';
import 'package:netrafit/screens/admin/admin_dashboard_screen.dart';
import 'package:netrafit/screens/onboarding/onboarding_screen.dart';
import 'package:netrafit/screens/home_screen.dart';
import 'package:netrafit/screens/auth/login_screen.dart';
import 'package:netrafit/screens/auth/register_screen.dart';
import 'package:netrafit/widgets/protected_route.dart';

class AppRoute {
  AppRoute._();
  static const String loginpageroute = '/login';
  static const String registerpageroute = '/register';
  static const String homeroute = '/home';
  static const String onboardingroute = '/onboard';
  static const String adminDashboardRoute = '/admin/dashboard';
  static const String adminUsersRoute = '/admin/users';
  static const String adminProductsRoute = '/admin/products';
  static const String adminOrdersRoute = '/admin/orders';
  static const String adminSettingsRoute = '/admin/settings';

  static Map<String, WidgetBuilder> getAppRoutes() {
    return {
      loginpageroute: (context) => const LoginScreen(),
      registerpageroute: (context) => const RegisterScreen(),
      homeroute: (context) => ProtectedRoute(child: const HomeScreen()),
      onboardingroute: (context) => const OnboardingScreen(),
      adminDashboardRoute: (context) => ProtectedRoute(
        child: const AdminDashboardScreen(),
        adminOnly: true,
      ),
    };
  }
}