import 'package:flutter/material.dart';
import '../../../widgets/onboarding/onboarding_layout.dart';

class Onboarding1Screen extends StatelessWidget {
  final VoidCallback onNext;
  final VoidCallback onLogin;

  const Onboarding1Screen({
    Key? key,
    required this.onNext,
    required this.onLogin,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return OnboardingLayout(
      title: "Instant Try-On with AI",
      subtitle: "AI-Powered Virtual Try-On",
      description: "Try on glasses instantly with your\nphone's camera",
      buttonText: "Next",
      onButtonPressed: onNext,
      onLoginPressed: onLogin,
      imageAsset: 'assets/images/onboarding1.png',
      showBackButton: false, // No back button on first screen
    );
  }
}