import 'package:flutter/material.dart';

class OnboardingLayout extends StatelessWidget {
  final String title;
  final String subtitle;
  final String description;
  final String buttonText;
  final VoidCallback onButtonPressed;
  final String imageAsset;
  final VoidCallback onLoginPressed;
  final bool showBackButton;
  final VoidCallback? onBackPressed;

  const OnboardingLayout({
    Key? key,
    required this.title,
    required this.subtitle,
    required this.description,
    required this.buttonText,
    required this.onButtonPressed,
    required this.imageAsset,
    required this.onLoginPressed,
    this.showBackButton = false,
    this.onBackPressed,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    var size = MediaQuery.of(context).size;
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 23),

            // Image at the top with gradient overlay and back button
            Expanded(
              flex: 2,
              child: Stack(
                children: [
                  // Image
                  Container(
                    width: size.width,
                    height: size.height,
                    child: Image.asset(
                      imageAsset,
                      fit: BoxFit.cover,
                    ),
                  ),

                  // Back Button (positioned at top left, not disturbing the UI)
                  if (showBackButton && onBackPressed != null)
                    Positioned(
                      top: 10,
                      left: 20,
                      child: GestureDetector(
                        onTap: onBackPressed,
                        child: const Icon(
                          Icons.arrow_back_ios,
                          color: Colors.white,
                          size: 24,
                        ),
                      ),
                    ),

                  // Gradient overlay at the bottom
                  Positioned(
                    bottom: 0,
                    left: 0,
                    right: 0,
                    child: Container(
                      height: 240,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.transparent,
                            Colors.black.withOpacity(0.8),
                          ],
                          stops: const [0.0, 0.57],
                        ),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(20.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.start,
                          children: [
                            // Title with white color
                            Container(
                              margin: const EdgeInsets.only(top: 40,bottom: 15),
                              child: Text(
                                title,
                                style: const TextStyle(
                                  fontSize: 32,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                  height: 1.2,
                                ),
                              ),
                            ),

                            const SizedBox(height: 8),

                            // Subtitle
                            Text(
                              subtitle,
                              style: const TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.w500,
                                color: Color(0xff98b6f9),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 23),

            // Description
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20.0),
              child: Text(
                description,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 24,
                  color: Color(0xFF0E3487),
                  fontWeight: FontWeight.w500,
                  height: 1.5,
                ),
              ),
            ),

            const SizedBox(height: 23),

            // Next Button
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 49.0),
              child: SizedBox(
                width: size.width,
                child: ElevatedButton(
                  onPressed: onButtonPressed,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF275BCD),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 2,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        buttonText,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Icon(
                        Icons.arrow_forward,
                        size: 20,
                      ),
                    ],
                  ),
                ),
              ),
            ),

            const SizedBox(height: 80),

            // Login text
            Center(
              child: GestureDetector(
                onTap: onLoginPressed,
                child: const Text(
                  "Already a member? Log in",
                  style: TextStyle(
                    color: Colors.blue,
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),

            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}