import 'package:flutter/material.dart';
import 'package:netrafit/screens/admin/admin_dashboard_screen.dart';
import 'package:netrafit/screens/admin/user_management_screen.dart';
import 'package:netrafit/screens/auth/reset_password1_screen.dart';
import 'package:netrafit/screens/auth/reset_password2_screen.dart';
import 'package:netrafit/screens/auth/reset_password3_screen.dart';
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
  static const String userManagementRoute = '/admin/users';
  static const String adminProductsRoute = '/admin/products';
  static const String adminOrdersRoute = '/admin/orders';
  static const String adminSettingsRoute = '/admin/settings';
  static const String resetPassword1Route = '/reset-password-1';
  static const String resetPassword2Route = '/reset-password-2';
  static const String resetPassword3Route = '/reset-password-3';

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
      resetPassword1Route: (context) => const ResetPassword1Screen(),
      resetPassword2Route: (context) {
        final args = ModalRoute.of(context)!.settings.arguments as Map<String, String>?;
        return ResetPassword2Screen(email: args?['email'] ?? '');
      },
      resetPassword3Route: (context) {
        final args = ModalRoute.of(context)!.settings.arguments as Map<String, String>?;
        return ResetPassword3Screen(
          email: args?['email'] ?? '',
          code: args?['code'] ?? '',
          tempToken: args?['tempToken'] ?? "",
        );
      },
      userManagementRoute: (context) => ProtectedRoute(
        child: UserManagementScreen(),
        adminOnly: true,
      ),
    };
  }
}