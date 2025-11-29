import 'package:flutter/material.dart';
import 'package:netrafit/routes.dart';
import 'onboarding1_screen.dart';
import 'onboarding2_screen.dart';
import 'onboarding3_screen.dart';
import '../../../widgets/onboarding/onboarding_indicator.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({Key? key}) : super(key: key);

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  void _handleLogin() {
    // Navigate to login screen
    Navigator.pushReplacementNamed(context, AppRoute.loginpageroute);
  }

  void _handleSignup() {
    // Navigate to signup screen
    Navigator.pushReplacementNamed(context, AppRoute.registerpageroute);
  }

  void _goBack() {
    if (_currentPage > 0) {
      _pageController.previousPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          PageView(
            controller: _pageController,
            onPageChanged: (int page) {
              setState(() {
                _currentPage = page;
              });
            },
            physics: const NeverScrollableScrollPhysics(), // Disable swipe
            children: [
              Onboarding1Screen(
                onNext: _nextPage,
                onLogin: _handleLogin,
              ),
              Onboarding2Screen(
                onNext: _nextPage,
                onLogin: _handleLogin,
                onBack: _goBack,
              ),
              Onboarding3Screen(
                onGetStarted: _handleSignup, // Changed to signup navigation
                onLogin: _handleLogin,
                onBack: _goBack,
              ),
            ],
          ),

          // Indicator
          Positioned(
            bottom: 100,
            left: 0,
            right: 0,
            child: OnboardingIndicator(
              currentPage: _currentPage,
              totalPages: 3,
            ),
          ),
        ],
      ),
    );
  }

  void _nextPage() {
    if (_currentPage < 2) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  void _getStarted() {
    // Navigate to main app or home screen using routes
    Navigator.pushReplacementNamed(context, AppRoute.homeroute);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }
}