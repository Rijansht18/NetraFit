import 'package:flutter/material.dart';
import '../../services/password_service.dart';
import '../../models/api_response.dart';

class ResetPassword3Screen extends StatefulWidget {
  final String email;
  final String code;
  final String tempToken;

  const ResetPassword3Screen({
    Key? key,
    required this.email,
    required this.code,
    required this.tempToken,
  }) : super(key: key);

  @override
  State<ResetPassword3Screen> createState() => _ResetPassword3ScreenState();
}

class _ResetPassword3ScreenState extends State<ResetPassword3Screen> {
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _obscureNewPassword = true;
  bool _obscureConfirmPassword = true;
  bool _isLoading = false;

  // Password strength variables
  double _passwordStrength = 0.0;
  String _passwordText = '';
  String _confirmPasswordText = '';
  bool _isPasswordValid = false;
  bool _doPasswordsMatch = false;

  final PasswordService _passwordService = PasswordService();

  void _checkPasswordStrength(String password) {
    double strength = 0.0;

    if (password.length >= 8) strength += 0.2;
    if (password.contains(RegExp(r'[a-z]'))) strength += 0.2;
    if (password.contains(RegExp(r'[A-Z]'))) strength += 0.2;
    if (password.contains(RegExp(r'[0-9]'))) strength += 0.2;
    if (password.contains(RegExp(r'[!@#$%^&*(),.?":{}|<>]'))) strength += 0.2;

    setState(() {
      _passwordStrength = strength;
      _passwordText = password;
      _isPasswordValid = strength == 1.0;
    });
  }

  void _updateConfirmPassword(String password) {
    setState(() {
      _confirmPasswordText = password;
      _doPasswordsMatch = password == _passwordText && _isPasswordValid;
    });
  }

  String get _passwordStrengthText {
    if (_passwordText.isEmpty) return 'Enter password';
    if (_passwordStrength < 0.4) return 'Weak';
    if (_passwordStrength < 0.7) return 'Fair';
    if (_passwordStrength < 1.0) return 'Good';
    return 'Strong';
  }

  Color get _passwordStrengthColor {
    if (_passwordText.isEmpty) return Colors.grey;
    if (_passwordStrength < 0.4) return Colors.red;
    if (_passwordStrength < 0.7) return Colors.orange;
    if (_passwordStrength < 1.0) return Colors.blue;
    return Colors.green;
  }

  String get _confirmPasswordStatus {
    if (_confirmPasswordText.isEmpty) return 'Enter confirmation';
    if (_passwordText.isEmpty) return 'Enter password first';
    if (_confirmPasswordText == _passwordText) return 'Passwords match';
    return 'Passwords do not match';
  }

  Color get _confirmPasswordColor {
    if (_confirmPasswordText.isEmpty) return Colors.grey;
    if (_passwordText.isEmpty) return Colors.grey;
    if (_confirmPasswordText == _passwordText) return Colors.green;
    return Colors.red;
  }

  void _resetPassword() async {
    if (!_doPasswordsMatch) {
      _showErrorDialog('Please make sure passwords match and meet all requirements.');
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      print('=== RESETTING PASSWORD ===');
      print('Email: ${widget.email}');
      print('Temp Token: ${widget.tempToken}');

      final ApiResponse response = await _passwordService.resetPassword(
        widget.tempToken,
        _newPasswordController.text,
      );

      setState(() {
        _isLoading = false;
      });

      if (response.success == true) {
        _showSuccessDialog(
          'Password reset successfully! You can now login with your new password.',
          onDismiss: () {
            Navigator.pushReplacementNamed(context, '/login');
          },
        );
      } else {
        final errorMessage = response.error ?? 'Failed to reset password. Please try again.';
        _showErrorDialog(errorMessage);
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      print('=== RESET PASSWORD ERROR ===');
      print('Exception: $e');
      _showErrorDialog('An unexpected error occurred. Please try again.');
    }
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

  void _showSuccessDialog(String message, {VoidCallback? onDismiss}) {
    showDialog(
      context: context,
      barrierDismissible: false,
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
                if (onDismiss != null) {
                  onDismiss();
                }
              },
              child: const Text('OK'),
            ),
          ],
        );
      },
    );
  }

  void _toggleNewPasswordVisibility() {
    setState(() {
      _obscureNewPassword = !_obscureNewPassword;
    });
  }

  void _toggleConfirmPasswordVisibility() {
    setState(() {
      _obscureConfirmPassword = !_obscureConfirmPassword;
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
            Navigator.pop(context);
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
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Progress Indicator
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _buildProgressStep("Email", 1, true),
                    _buildProgressConnector(true),
                    _buildProgressStep("Code", 2, true),
                    _buildProgressConnector(true),
                    _buildProgressStep("Password", 3, _doPasswordsMatch),
                  ],
                ),

                const SizedBox(height: 40),

                // Title
                const Text(
                  "Create New Password",
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                  ),
                ),

                const SizedBox(height: 16),

                // Subtitle
                const Text(
                  "Almost there! Create your new password.\nUse a strong, unique password you haven't used before.",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.grey,
                    height: 1.5,
                  ),
                ),

                const SizedBox(height: 40),

                // New Password Field
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
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
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        "Choose a strong password",
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: Colors.black,
                        ),
                      ),
                      const SizedBox(height: 16),

                      const Text(
                        "New Password",
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: Colors.black,
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _newPasswordController,
                        obscureText: _obscureNewPassword,
                        onChanged: _checkPasswordStrength,
                        decoration: InputDecoration(
                          hintText: "Enter new password",
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
                          suffixIcon: IconButton(
                            icon: Icon(
                              _obscureNewPassword
                                  ? Icons.visibility_off
                                  : Icons.visibility,
                              color: Colors.grey,
                            ),
                            onPressed: _toggleNewPasswordVisibility,
                          ),
                        ),
                      ),

                      const SizedBox(height: 16),

                      // Password Strength Bar
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Strength Text
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                "Password strength",
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey[600],
                                ),
                              ),
                              Text(
                                _passwordStrengthText,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: _passwordStrengthColor,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),

                          // Strength Bar
                          Container(
                            height: 6,
                            width: double.infinity,
                            decoration: BoxDecoration(
                              color: Colors.grey[300],
                              borderRadius: BorderRadius.circular(3),
                            ),
                            child: Stack(
                              children: [
                                // Background
                                Container(
                                  height: 6,
                                  width: double.infinity,
                                  decoration: BoxDecoration(
                                    color: Colors.grey[300],
                                    borderRadius: BorderRadius.circular(3),
                                  ),
                                ),

                                // Progress
                                AnimatedContainer(
                                  duration: const Duration(milliseconds: 300),
                                  height: 6,
                                  width: MediaQuery.of(context).size.width * _passwordStrength,
                                  decoration: BoxDecoration(
                                    color: _passwordStrengthColor,
                                    borderRadius: BorderRadius.circular(3),
                                  ),
                                ),
                              ],
                            ),
                          ),

                          // Password requirements
                          if (_passwordText.isNotEmpty) ...[
                            const SizedBox(height: 16),
                            const Text(
                              "Password must include:",
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                                color: Colors.black,
                              ),
                            ),
                            const SizedBox(height: 8),
                            _buildPasswordRequirement("At least 8 characters", _passwordText.length >= 8),
                            _buildPasswordRequirement("One uppercase letter", _passwordText.contains(RegExp(r'[A-Z]'))),
                            _buildPasswordRequirement("One lowercase letter", _passwordText.contains(RegExp(r'[a-z]'))),
                            _buildPasswordRequirement("One number", _passwordText.contains(RegExp(r'[0-9]'))),
                            _buildPasswordRequirement("One special character", _passwordText.contains(RegExp(r'[!@#$%^&*(),.?":{}|<>]'))),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 20),

                // Confirm Password Field
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
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
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        "Confirm Password",
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: Colors.black,
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _confirmPasswordController,
                        obscureText: _obscureConfirmPassword,
                        onChanged: _updateConfirmPassword,
                        decoration: InputDecoration(
                          hintText: "Confirm your new password",
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
                          suffixIcon: IconButton(
                            icon: Icon(
                              _obscureConfirmPassword
                                  ? Icons.visibility_off
                                  : Icons.visibility,
                              color: Colors.grey,
                            ),
                            onPressed: _toggleConfirmPasswordVisibility,
                          ),
                        ),
                      ),

                      const SizedBox(height: 8),

                      // Confirm Password Status
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            "Password confirmation",
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[600],
                            ),
                          ),
                          Text(
                            _confirmPasswordStatus,
                            style: TextStyle(
                              fontSize: 12,
                              color: _confirmPasswordColor,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 40),

                // Reset Password Button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: (_doPasswordsMatch && !_isLoading) ? _resetPassword : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF275BCD),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      disabledBackgroundColor: Colors.grey[300],
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
                      "Reset Password",
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 20),

                // Success Message
                const Center(
                  child: Text(
                    "Your password will be updated immediately.",
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.green,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),

                const SizedBox(height: 40),
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
                color: isCompleted ? Colors.white : Colors.grey[600],
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          text,
          style: TextStyle(
            fontSize: 12,
            color: isCompleted ? const Color(0xFF275BCD) : Colors.grey,
            fontWeight: isCompleted ? FontWeight.w600 : FontWeight.normal,
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

  Widget _buildPasswordRequirement(String text, bool isMet) {
    return Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Row(
          children: [
            Icon(
              isMet ? Icons.check_circle : Icons.radio_button_unchecked,
              size: 16,
              color: isMet ? Colors.green : Colors.grey,
            ),
            const SizedBox(width: 8),
            Text(
              text,
              style: TextStyle(
                fontSize: 14,
                color: isMet ? Colors.green : Colors.grey,
              ),
            ),
          ],
        )
    );
  }

  @override
  void dispose() {
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }
}