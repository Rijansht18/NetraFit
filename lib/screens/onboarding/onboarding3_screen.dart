import 'package:flutter/material.dart';
import '../../../widgets/onboarding/onboarding_layout.dart';

class Onboarding3Screen extends StatelessWidget {
  final VoidCallback onGetStarted;
  final VoidCallback onLogin;
  final VoidCallback onBack;

  const Onboarding3Screen({
    Key? key,
    required this.onGetStarted,
    required this.onLogin,
    required this.onBack,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return OnboardingLayout(
      title: "Find Your Perfect Fit",
      subtitle: "Custom frame suggestions",
      description: "Get frames tailored to your face shape",
      buttonText: "Get Started",
      onButtonPressed: onGetStarted,
      onLoginPressed: onLogin,
      imageAsset: 'assets/images/onboarding3.png',
      showBackButton: true,
      onBackPressed: onBack,
    );
  }
}