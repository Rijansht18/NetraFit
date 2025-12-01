import 'package:flutter/material.dart';
import 'package:netrafit/screens/admin/admin_dashboard_screen.dart';
import 'package:netrafit/screens/home_screen.dart';
import 'package:netrafit/screens/onboarding/onboarding_screen.dart';
import 'package:provider/provider.dart';
import 'package:netrafit/routes.dart';
import 'package:netrafit/core/themes/app_theme.dart';
import 'package:netrafit/providers/auth_provider.dart';
import 'package:netrafit/providers/frame_provider.dart';
import 'package:netrafit/widgets/protected_route.dart';

Future<void> main() async {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => FrameProvider()),
      ],
      child: MaterialApp(
        title: 'Virtual Try-On',
        theme: AppTheme.lightTheme,
        debugShowCheckedModeBanner: false,
        // Use getAppRoutes() method from AppRoute class
        routes: AppRoute.getAppRoutes(),
        home: Consumer<AuthProvider>(
          builder: (context, authProvider, child) {
            // Show loading while checking auth state
            if (authProvider.isLoading) {
              return Scaffold(
                backgroundColor: Color(0xFFF5F8FF),
                body: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      CircularProgressIndicator(),
                      SizedBox(height: 20),
                      Text('Checking authentication...'),
                    ],
                  ),
                ),
              );
            }

            // Auto-login if remember me is enabled and user is logged in
            if (authProvider.isLoggedIn) {
              print('Auto-login detected: ${authProvider.user?.username} (${authProvider.user?.role})');
              if (authProvider.isAdmin) {
                return const AdminDashboardScreen();
              } else {
                return const HomeScreen();
              }
            }

            // Otherwise show onboarding
            return const OnboardingScreen();
          },
        ),
      ),
    );
  }
}