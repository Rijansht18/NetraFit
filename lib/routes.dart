import 'package:flutter/material.dart';
import 'package:netrafit/screens/onboarding/onboarding_screen.dart';
import 'screens/home_screen.dart';
import 'screens/auth/login_screen.dart';
import 'screens/auth/register_screen.dart';

class AppRoute {
  AppRoute._();
  static const String loginpageroute = '/login';
  static const String registerpageroute = '/register';
  static const String homeroute = '/home';
  static const String onboardingroute = '/onboard';

  static Map<String, WidgetBuilder> getAppRoutes() {
    return {
      loginpageroute: (context) => const LoginScreen(),
      registerpageroute: (context) => const RegisterScreen(),
      homeroute: (context) => const HomeScreen(),
      onboardingroute: (context) => const OnboardingScreen(),
    };
  }
}