import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../routes.dart';

class ProtectedRoute extends StatelessWidget {
  final Widget child;
  final bool adminOnly;

  const ProtectedRoute({
    Key? key,
    required this.child,
    this.adminOnly = false,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);

    // Check if user is authenticated
    if (!authProvider.isLoggedIn) {
      // Redirect to login after a brief delay to allow build to complete
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Navigator.pushReplacementNamed(context, AppRoute.onboardingroute);
      });
      return _buildLoadingScreen();
    }

    // Check if admin access is required
    if (adminOnly && !authProvider.isAdmin) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Navigator.pushReplacementNamed(context, AppRoute.homeroute);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Access denied. Admin privileges required.')),
        );
      });
      return _buildLoadingScreen();
    }

    return child;
  }

  Widget _buildLoadingScreen() {
    return Scaffold(
      backgroundColor: Color(0xFFF5F8FF),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 20),
            Text('Loading...'),
          ],
        ),
      ),
    );
  }
}