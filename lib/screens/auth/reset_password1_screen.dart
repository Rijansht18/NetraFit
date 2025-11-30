import 'package:flutter/material.dart';
import '../../services/password_service.dart';
import '../../models/api_response.dart';

class ResetPassword1Screen extends StatefulWidget {
  const ResetPassword1Screen({Key? key}) : super(key: key);

  @override
  State<ResetPassword1Screen> createState() => _ResetPassword1ScreenState();
}

class _ResetPassword1ScreenState extends State<ResetPassword1Screen> {
  final _emailController = TextEditingController();
  bool _isEmailValid = false;
  bool _isLoading = false;

  final PasswordService _passwordService = PasswordService();

  void _sendVerificationCode() async {
    if (_emailController.text.isEmpty) {
      _showErrorDialog('Please enter your email address');
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      print('=== SENDING VERIFICATION CODE ===');
      print('Email: ${_emailController.text}');

      final ApiResponse response = await _passwordService.requestResetCode(
        _emailController.text.trim(),
      );

      setState(() {
        _isLoading = false;
      });

      if (response.success == true) {
        // Success - navigate to next screen
        Navigator.pushNamed(
          context,
          '/reset-password-2',
          arguments: {'email': _emailController.text.trim()},
        );
      } else {
        // Check if this is a rate limit error (429 status code)
        if (response.statusCode == 429) {
          // Show rate limit warning and navigate to next screen
          _showRateLimitWarning(response.error ?? 'Please use the reset code already sent to your email.');
        } else {
          // Show other backend error message
          final errorMessage = response.error ?? 'Failed to send verification code. Please try again.';
          _showErrorDialog(errorMessage);
        }
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      print('=== SEND VERIFICATION CODE ERROR ===');
      print('Exception: $e');
      _showErrorDialog('An unexpected error occurred. Please try again.');
    }
  }

  void _showRateLimitWarning(String message) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.timer_outlined, color: Colors.orange, size: 24),
              SizedBox(width: 8),
              Text('Code Already Sent'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(message),
              const SizedBox(height: 8),
              const Text(
                'Please check your email and use the code we already sent you.',
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                // Navigate to next screen after user acknowledges
                Navigator.pushNamed(
                  context,
                  '/reset-password-2',
                  arguments: {'email': _emailController.text.trim()},
                );
              },
              child: const Text('OK, USE EXISTING CODE'),
            ),
          ],
        );
      },
    );
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.error_outline, color: Colors.red, size: 24),
              SizedBox(width: 8),
              Text('Error'),
            ],
          ),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text('OK'),
            ),
          ],
        );
      },
    );
  }

  void _showSuccessDialog(String message) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.check_circle, color: Colors.green, size: 24),
              SizedBox(width: 8),
              Text('Success'),
            ],
          ),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text('OK'),
            ),
          ],
        );
      },
    );
  }

  void _goToLogin() {
    Navigator.pushReplacementNamed(context, '/login');
  }

  void _validateEmail(String email) {
    final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
    setState(() {
      _isEmailValid = emailRegex.hasMatch(email);
    });
  }

  @override
  void initState() {
    super.initState();
    _emailController.addListener(() {
      _validateEmail(_emailController.text);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        leading: IconButton(
          icon: Icon(Icons.chevron_left, size: 30),
          onPressed: () {
            _goToLogin();
          },
        ),
        title: const Text(
          'Reset Password',
          style: TextStyle(
            fontSize: 16,
          ),
        ),
        centerTitle: true,
        backgroundColor: Colors.white,
        foregroundColor: Color(0xFF133FA0),
      ),
      body: Container(
        width: double.infinity,
        height: double.infinity,
        color: Color(0xFFF5F8FF),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Progress Indicator
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _buildProgressStep("Email", 1, _isEmailValid),
                    _buildProgressConnector(_isEmailValid),
                    _buildProgressStep("Code", 2, false),
                    _buildProgressConnector(false),
                    _buildProgressStep("Password", 3, false),
                  ],
                ),

                const SizedBox(height: 30),

                // Lock Icon Container
                Container(
                  height: 80,
                  width: 80,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.blue.withOpacity(0.5),
                        blurRadius: 8,
                        spreadRadius: 2,
                        offset: Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Center(
                    child: Image.asset(
                      'assets/images/div.png',
                      width: 40,
                      height: 40,
                      fit: BoxFit.cover,
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                // Security Text with Icon
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.lock, color: Colors.grey),
                    SizedBox(width: 8),
                    Text(
                      "Your security is our priority",
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.grey,
                        height: 1.5,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 8),

                // Description Text
                const Text(
                  "We'll send a secure verification code to your email",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.grey,
                    height: 1.5,
                    fontStyle: FontStyle.italic,
                  ),
                ),

                const SizedBox(height: 30),

                // Email Card
                Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        "Enter your email address",
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w400,
                          color: Colors.black,
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _emailController,
                        keyboardType: TextInputType.emailAddress,
                        decoration: InputDecoration(
                          prefixIcon: Icon(Icons.mail, color: Colors.black),
                          hintText: "john@example.com",
                          hintStyle: const TextStyle(color: Colors.grey),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide.none,
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: const BorderSide(color: Color(0xFF275BCD)),
                          ),
                          filled: true,
                          fillColor: const Color(0xFFF5F8FF),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 14,
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        "We'll email you a 6-digit verification code",
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey,
                          height: 1.5,
                          fontWeight: FontWeight.w400,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 30),

                // Send Verification Code Button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: (_isEmailValid && !_isLoading) ? _sendVerificationCode : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF275BCD),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      disabledBackgroundColor: Colors.grey[300],
                      elevation: 0,
                    ),
                    child: _isLoading
                        ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                        : const Text(
                      "Send Verification Code",
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                // Expiry Info
                const Text(
                  "Code expires in 10 minutes • Resend available",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey,
                  ),
                ),

                const SizedBox(height: 20),

                // Back to Login
                GestureDetector(
                  onTap: _goToLogin,
                  child: const Text(
                    "Remember your password? Return to Login",
                    style: TextStyle(
                      color: Color(0xFF275BCD),
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildProgressStep(String text, int stepNumber, bool isCompleted) {
    return Column(
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isCompleted ? const Color(0xFF275BCD) : Colors.grey[300],
          ),
          child: Center(
            child: isCompleted
                ? const Icon(
              Icons.check,
              color: Colors.white,
              size: 18,
            )
                : Text(
              stepNumber.toString(),
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: stepNumber == 1 && !isCompleted
                    ? const Color(0xFF275BCD)
                    : Colors.grey[600],
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          text,
          style: TextStyle(
            fontSize: 12,
            color: stepNumber == 1 ? const Color(0xFF275BCD) : Colors.grey,
            fontWeight: stepNumber == 1 ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
      ],
    );
  }

  Widget _buildProgressConnector(bool isActive) {
    return Container(
      width: 40,
      height: 2,
      margin: const EdgeInsets.only(bottom: 16),
      color: isActive ? const Color(0xFF275BCD) : Colors.grey[300],
    );
  }

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }
}