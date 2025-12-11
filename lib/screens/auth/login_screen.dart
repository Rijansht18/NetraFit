import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/api_response.dart';
import '../../routes.dart';
import '../../services/auth_service.dart';
import '../../providers/auth_provider.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({Key? key}) : super(key: key);

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _identifierController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  bool _obscurePassword = true;

  void _login() async {
    if (_formKey.currentState!.validate()) {
      setState(() {
        _isLoading = true;
      });

      try {
        print('=== LOGIN SCREEN ===');
        print('Identifier: ${_identifierController.text}');

        final authProvider = Provider.of<AuthProvider>(context, listen: false);
        final rememberMe = authProvider.rememberMe;

        // Call API through AuthProvider
        final success = await authProvider.login(
          _identifierController.text.trim(),
          _passwordController.text,
          rememberMe,
        );

        setState(() {
          _isLoading = false;
        });

        if (success) {
          // Navigate based on user role
          _navigateBasedOnRole(authProvider);
        } else {
          final errorMessage = 'Login failed. Please check your credentials.';
          _showErrorDialog(errorMessage);
        }
      } catch (e) {
        setState(() {
          _isLoading = false;
        });
        print('=== LOGIN SCREEN ERROR ===');
        print('Exception: $e');
        _showErrorDialog('An unexpected error occurred. Please try again.');
      }
    }
  }

  void _navigateBasedOnRole(AuthProvider authProvider) {
    if (authProvider.isAdmin) {
      // Navigate to admin screen
      print('Navigating to ADMIN dashboard - User: ${authProvider.user?.username}');
      Navigator.pushReplacementNamed(context, AppRoute.adminDashboardRoute);
    } else {
      // Navigate to customer home screen
      print('Navigating to CUSTOMER home - User: ${authProvider.user?.username}');
      Navigator.pushReplacementNamed(context, AppRoute.homeroute);
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
              Text('Login Failed'),
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

  void _handleForgotPassword() async {
    Navigator.pushReplacementNamed(context, AppRoute.resetPassword1Route);
  }

  Future<void> _sendPasswordReset(String identifier) async {
    setState(() {
      _isLoading = true;
    });

    try {
      final AuthService authService = AuthService();
      final ApiResponse response = await authService.forgotPassword(identifier);

      setState(() {
        _isLoading = false;
      });

      if (response.success == true) {
        showDialog(
          context: context,
          builder: (BuildContext context) {
            return AlertDialog(
              title: const Text('Success'),
              content: Text(response.data?['message'] ?? 'Password reset instructions sent to your email.'),
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
      } else {
        _showErrorDialog(
            response.error ?? 'Failed to send reset instructions. Please try again.'
        );
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      _showErrorDialog('Network error. Please check your connection.');
    }
  }

  void _goToRegister() {
    Navigator.pushReplacementNamed(context, AppRoute.registerpageroute);
  }

  void _togglePasswordVisibility() {
    setState(() {
      _obscurePassword = !_obscurePassword;
    });
  }

  String? _identifierValidator(String? value) {
    if (value == null || value.isEmpty) {
      return 'Please enter your email or username';
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);

    return Scaffold(
      backgroundColor: Color(0xFFF5F8FF),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 23),

                // Logo
                Center(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: Image.asset(
                      "assets/logo/logo.png",
                      width: 100,
                      height: 100,
                      fit: BoxFit.contain,
                    ),
                  ),
                ),

                const SizedBox(height: 30),

                // Login Form Container
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Email/Username Field
                      const Text(
                        "Email or Username",
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                          color: Colors.black,
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _identifierController,
                        keyboardType: TextInputType.text,
                        decoration: InputDecoration(
                          hintText: "Enter email or username",
                          hintStyle: const TextStyle(color: Colors.grey),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: Color(0xFF275BCD)),
                          ),
                          filled: true,
                          fillColor: Colors.grey[50],
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                          prefixIcon: Icon(Icons.person, color: Colors.black),
                        ),
                        validator: _identifierValidator,
                      ),

                      const SizedBox(height: 16),

                      // Password Field
                      const Text(
                        "Password",
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                          color: Colors.black,
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _passwordController,
                        obscureText: _obscurePassword,
                        decoration: InputDecoration(
                          hintText: "Enter your password",
                          hintStyle: const TextStyle(color: Colors.grey),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: Color(0xFF275BCD)),
                          ),
                          filled: true,
                          fillColor: Colors.grey[50],
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                          prefixIcon: Icon(Icons.lock, color: Colors.black),
                          suffixIcon: IconButton(
                            icon: Icon(
                              _obscurePassword ? Icons.visibility_off : Icons.visibility,
                              color: Colors.black,
                            ),
                            onPressed: _togglePasswordVisibility,
                          ),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please enter your password';
                          }
                          return null;
                        },
                      ),

                      const SizedBox(height: 16),

                      // Remember Me & Forgot Password
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Checkbox(
                                value: authProvider.rememberMe,
                                onChanged: (value) {
                                  authProvider.setRememberMe(value!);
                                },
                                activeColor: const Color(0xFF275BCD),
                              ),
                              const Text(
                                "Remember Me",
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.black,
                                ),
                              ),
                            ],
                          ),
                          GestureDetector(
                            onTap: _handleForgotPassword,
                            child: const Text(
                              "Forgot Password?",
                              style: TextStyle(
                                color: Color(0xFF275BCD),
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 24),

                      // Sign In Button
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _isLoading ? null : _login,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF275BCD),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
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
                            "Sign In",
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 30),

                // // OR CONTINUE WITH
                // const Row(
                //   children: [
                //     Expanded(
                //       child: Divider(
                //         color: Colors.grey,
                //         thickness: 1,
                //       ),
                //     ),
                //     Padding(
                //       padding: EdgeInsets.symmetric(horizontal: 16),
                //       child: Text(
                //         "OR CONTINUE WITH",
                //         style: TextStyle(
                //           color: Colors.grey,
                //           fontSize: 14,
                //           fontWeight: FontWeight.w500,
                //         ),
                //       ),
                //     ),
                //     Expanded(
                //       child: Divider(
                //         color: Colors.grey,
                //         thickness: 1,
                //       ),
                //     ),
                //   ],
                // ),
                //
                // const SizedBox(height: 20),
                //
                // // Social Buttons
                // Column(
                //   children: [
                //     _buildSocialButton(
                //       text: "Continue with Google",
                //       textColor: Colors.black,
                //     ),
                //     const SizedBox(height: 12),
                //     _buildSocialButton(
                //       text: "Continue with Apple",
                //       textColor: Colors.black,
                //     ),
                //     const SizedBox(height: 12),
                //     _buildSocialButton(
                //       text: "Continue with Facebook",
                //       textColor: Colors.black,
                //     ),
                //   ],
                // ),
                //
                // const SizedBox(height: 30),

                // Sign Up Link
                Center(
                  child: GestureDetector(
                    onTap: _goToRegister,
                    child: const Text.rich(
                      TextSpan(
                        text: "Don't have an account? ",
                        style: TextStyle(
                          color: Colors.grey,
                          fontSize: 16,
                        ),
                        children: [
                          TextSpan(
                            text: "Sign Up",
                            style: TextStyle(
                              color: Color(0xFF275BCD),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSocialButton({required String text, required Color textColor}) {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton(
        onPressed: () {},
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          side: BorderSide(color: Colors.grey.shade300),
          backgroundColor: Colors.white,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _getSocialIcon(text),
            const SizedBox(width: 12),
            Text(
              text,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: textColor,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Icon _getSocialIcon(String text) {
    if (text.contains("Google")) {
      return const Icon(
        Icons.g_mobiledata,
        size: 24,
        color: Colors.black,
      );
    } else if (text.contains("Apple")) {
      return const Icon(
        Icons.apple,
        size: 24,
        color: Colors.black,
      );
    } else if (text.contains("Facebook")) {
      return const Icon(
          Icons.facebook_outlined,
          size: 24,
          color: Colors.black
      );
    }
    return const Icon(Icons.question_mark);
  }

  @override
  void dispose() {
    _identifierController.dispose();
    _passwordController.dispose();
    super.dispose();
  }
}