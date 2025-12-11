import 'package:flutter/material.dart';
import 'package:netrafit/providers/cart_provider.dart';
import 'package:netrafit/providers/favorites_provider.dart';
import 'package:netrafit/screens/admin/admin_dashboard_screen.dart';
import 'package:netrafit/screens/home_screen.dart';
import 'package:netrafit/screens/onboarding/onboarding_screen.dart';
import 'package:provider/provider.dart';
import 'package:netrafit/routes.dart';
import 'package:netrafit/core/themes/app_theme.dart';
import 'package:netrafit/providers/auth_provider.dart';
import 'package:netrafit/providers/frame_provider.dart';

Future<void> main() async {
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  bool _isAppInitializing = true;

  @override
  void initState() {
    super.initState();
    _initializeApp();
  }

  Future<void> _initializeApp() async {
    // Add any app initialization logic here
    await Future.delayed(const Duration(milliseconds: 100));
    setState(() {
      _isAppInitializing = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => FrameProvider()),
        ChangeNotifierProvider(create: (_) => CartProvider()),
        ChangeNotifierProvider(create: (_) => FavoritesProvider()),
      ],
      child: MaterialApp(
        title: 'Virtual Try-On',
        theme: AppTheme.lightTheme,
        debugShowCheckedModeBanner: false,
        routes: AppRoute.getAppRoutes(),
        home: _isAppInitializing
            ? Scaffold(
          backgroundColor: const Color(0xFFF5F8FF),
          body: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF275BCD)),
                ),
                SizedBox(height: 20),
                Text('Initializing app...'),
              ],
            ),
          ),
        )
            : Consumer<AuthProvider>(
          builder: (context, authProvider, child) {

            // Auto-login if remember me is enabled and user is logged in
            if (authProvider.isLoggedIn) {
              print('Auto-login detected: ${authProvider.user?.username} (${authProvider.user?.role})');

              // Load user data on app start
              _loadUserData(context);

              return authProvider.isAdmin
                  ? const AdminDashboardScreen()
                  : const HomeScreen();
            }

            // Otherwise show onboarding
            return const OnboardingScreen();
          },
        ),
      ),
    );
  }

  void _loadUserData(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final favoritesProvider = Provider.of<FavoritesProvider>(context, listen: false);
    final cartProvider = Provider.of<CartProvider>(context, listen: false);

    if (authProvider.token != null) {
      final token = authProvider.token!;

      // Load favorites
      favoritesProvider.loadFavorites(token).then((_) {
        print('Favorites loaded: ${favoritesProvider.favoritesCount}');
      }).catchError((e) {
        print('Error loading favorites: $e');
      });

      // Load cart
      cartProvider.loadCart(token).then((_) {
        print('Cart loaded: ${cartProvider.cartItemCount}');
      }).catchError((e) {
        print('Error loading cart: $e');
      });
    }
  }
}