import 'package:flutter/material.dart';
import '../../../widgets/onboarding/onboarding_layout.dart';

class Onboarding2Screen extends StatelessWidget {
  final VoidCallback onNext;
  final VoidCallback onLogin;
  final VoidCallback onBack;

  const Onboarding2Screen({
    Key? key,
    required this.onNext,
    required this.onLogin,
    required this.onBack,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return OnboardingLayout(
      title: "Reliable eyewear brands",
      subtitle: "Shop 1,000+ Designer Frames",
      description: "Explore authentic frames with easy returns",
      buttonText: "Next",
      onButtonPressed: onNext,
      onLoginPressed: onLogin,
      imageAsset: 'assets/images/onboarding2.png',
      showBackButton: true,
      onBackPressed: onBack,
    );
  }
}