import 'package:flutter/material.dart';
import 'package:netrafit/routes.dart';
import 'package:netrafit/screens/home_screen.dart';
import 'core/themes/app_theme.dart';
import 'screens/onboarding/onboarding_screen.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Virtual Try-On',
      theme: AppTheme.lightTheme,
      debugShowCheckedModeBanner: false,
      initialRoute: AppRoute.onboardingroute,
      routes: AppRoute.getAppRoutes(),
    );
  }
}