import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../services/password_service.dart';
import '../../models/api_response.dart';

class ResetPassword2Screen extends StatefulWidget {
  final String email;

  const ResetPassword2Screen({Key? key, required this.email}) : super(key: key);

  @override
  State<ResetPassword2Screen> createState() => _ResetPassword2ScreenState();
}

class _ResetPassword2ScreenState extends State<ResetPassword2Screen> {
  final List<TextEditingController> _codeControllers =
  List.generate(6, (index) => TextEditingController());
  final List<FocusNode> _focusNodes = List.generate(6, (index) => FocusNode());
  int _timerSeconds = 600; // 10 minutes in seconds for expiry
  int _resendTimerSeconds = 120; // 2 minutes for resend availability
  bool _canResend = false;
  bool _isCodeComplete = false;
  bool _isCodeExpired = false;
  bool _isLoading = false;

  final PasswordService _passwordService = PasswordService();

  @override
  void initState() {
    super.initState();
    _startExpiryTimer();
    _startResendTimer();
    _setupCodeInputs();
  }

  void _startExpiryTimer() {
    Future.delayed(const Duration(seconds: 1), () {
      if (mounted && _timerSeconds > 0) {
        setState(() {
          _timerSeconds--;
        });
        _startExpiryTimer();
      } else if (mounted) {
        setState(() {
          _isCodeExpired = true;
        });
      }
    });
  }

  void _startResendTimer() {
    Future.delayed(const Duration(seconds: 1), () {
      if (mounted && _resendTimerSeconds > 0) {
        setState(() {
          _resendTimerSeconds--;
        });
        _startResendTimer();
      } else if (mounted) {
        setState(() {
          _canResend = true;
        });
      }
    });
  }

  void _setupCodeInputs() {
    for (int i = 0; i < _focusNodes.length; i++) {
      _codeControllers[i].addListener(() {
        String fullCode = _codeControllers.map((c) => c.text).join();
        setState(() {
          _isCodeComplete = fullCode.length == 6;
        });
      });
    }
  }

  void _verifyCode() async {
    String code = _codeControllers.map((controller) => controller.text).join();
    if (code.length == 6) {
      setState(() {
        _isLoading = true;
      });

      try {
        print('=== VERIFYING RESET CODE ===');
        print('Email: ${widget.email}');
        print('Code: $code');

        final ApiResponse response = await _passwordService.verifyResetCode(
          widget.email,
          code,
        );

        setState(() {
          _isLoading = false;
        });

        if (response.success == true && response.data?['tempToken'] != null) {
          // Success - navigate to password reset screen
          final String tempToken = response.data!['tempToken'];
          Navigator.pushNamed(
            context,
            '/reset-password-3',
            arguments: {
              'email': widget.email,
              'code': code,
              'tempToken': tempToken,
            },
          );
        } else {
          final errorMessage = response.error ?? 'Invalid verification code. Please try again.';
          _showErrorDialog(errorMessage);
        }
      } catch (e) {
        setState(() {
          _isLoading = false;
        });
        print('=== VERIFY CODE ERROR ===');
        print('Exception: $e');
        _showErrorDialog('An unexpected error occurred. Please try again.');
      }
    }
  }

  void _resendCode() async {
    if (_canResend) {
      setState(() {
        _isLoading = true;
      });

      try {
        final ApiResponse response = await _passwordService.requestResetCode(widget.email);

        setState(() {
          _isLoading = false;
        });

        if (response.success == true) {
          // Reset timers and UI
          setState(() {
            _timerSeconds = 600; // Reset to 10 minutes
            _resendTimerSeconds = 120; // Reset resend timer to 2 minutes
            _canResend = false;
            _isCodeComplete = false;
            _isCodeExpired = false;

            // Clear all code fields
            for (var controller in _codeControllers) {
              controller.clear();
            }
            // Focus on first field
            _focusNodes[0].requestFocus();
          });

          _startExpiryTimer();
          _startResendTimer();

          _showSuccessDialog('New verification code sent to your email!');
        } else {
          final errorMessage = response.error ?? 'Failed to resend code. Please try again.';
          _showErrorDialog(errorMessage);
        }
      } catch (e) {
        setState(() {
          _isLoading = false;
        });
        _showErrorDialog('Network error. Please check your connection.');
      }
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

  void _copyToClipboard(String text) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Email copied to clipboard'),
        duration: Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
        margin: EdgeInsets.all(16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
    );
  }

  String _formatTime(int seconds) {
    int minutes = seconds ~/ 60;
    int remainingSeconds = seconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${remainingSeconds.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFFF5F8FF),
      appBar: AppBar(
        leading: IconButton(
          icon: Icon(Icons.chevron_left, size: 30),
          onPressed: () {
            Navigator.pop(context);
          },
        ),
        title: const Text(
          'Verify Email',
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
                    _buildProgressStep("Code", 2, _isCodeComplete),
                    _buildProgressConnector(_isCodeComplete),
                    _buildProgressStep("Password", 3, false),
                  ],
                ),

                const SizedBox(height: 40),

                // Email Display with Copy Button
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
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
                        "Code sent to:",
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          const Icon(Icons.email_outlined, color: Colors.grey, size: 16),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              widget.email,
                              style: const TextStyle(
                                fontSize: 16,
                                color: Colors.black,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          GestureDetector(
                            onTap: () {
                              _copyToClipboard(widget.email);
                            },
                            child: Container(
                              padding: EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: Color(0xFFF5F8FF),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Icon(Icons.content_copy, size: 16, color: Color(0xFF275BCD)),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Icon(Icons.access_time, color: _isCodeExpired ? Colors.red : Colors.grey, size: 16),
                          const SizedBox(width: 8),
                          Text(
                            _isCodeExpired ? "Code expired" : "Code expires in ${_formatTime(_timerSeconds)}",
                            style: TextStyle(
                              fontSize: 14,
                              color: _isCodeExpired ? Colors.red : (_timerSeconds < 60 ? Colors.orange : Colors.grey),
                              fontWeight: _isCodeExpired ? FontWeight.w600 : FontWeight.normal,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 40),

                // Code Input Section
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
                        "Enter verification code",
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w600,
                          color: Colors.black,
                        ),
                      ),
                      const SizedBox(height: 8),

                      Text(
                        _isCodeExpired
                            ? "The verification code has expired. Please request a new code."
                            : "We sent a 6-digit code to your email. It may take a minute to arrive.",
                        style: TextStyle(
                          fontSize: 14,
                          color: _isCodeExpired ? Colors.red : Colors.grey,
                          height: 1.5,
                        ),
                      ),

                      const SizedBox(height: 20),

                      // Code Input Boxes
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: List.generate(6, (index) {
                          return SizedBox(
                            width: 40,
                            child: TextFormField(
                              controller: _codeControllers[index],
                              focusNode: _focusNodes[index],
                              textAlign: TextAlign.center,
                              maxLength: 1,
                              keyboardType: TextInputType.number,
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: _isCodeExpired ? Colors.grey : Colors.black,
                              ),
                              decoration: InputDecoration(
                                counterText: "",
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  borderSide: BorderSide(color: Colors.grey[300]!),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  borderSide: BorderSide(
                                      color: _isCodeExpired ? Colors.grey : Color(0xFF275BCD)
                                  ),
                                ),
                                filled: true,
                                fillColor: _isCodeExpired ? Colors.grey[100] : Color(0xFFF5F8FF),
                                contentPadding: const EdgeInsets.symmetric(vertical: 12),
                                enabled: !_isCodeExpired,
                              ),
                              enabled: !_isCodeExpired,
                              onChanged: _isCodeExpired ? null : (value) {
                                if (value.isNotEmpty && index < 5) {
                                  _focusNodes[index + 1].requestFocus();
                                }
                                if (value.isEmpty && index > 0) {
                                  _focusNodes[index - 1].requestFocus();
                                }

                                // Auto verify when all fields are filled
                                if (value.isNotEmpty && index == 5) {
                                  String fullCode = _codeControllers.map((c) => c.text).join();
                                  if (fullCode.length == 6) {
                                    _verifyCode();
                                  }
                                }
                              },
                            ),
                          );
                        }),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 20),

                // Resend Code Section
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
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
                        "Didn't receive code?",
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                          color: Colors.black,
                        ),
                      ),
                      const SizedBox(height: 12),
                      GestureDetector(
                        onTap: _canResend ? _resendCode : null,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              "Resend Code",
                              style: TextStyle(
                                color: _canResend
                                    ? const Color(0xFF275BCD)
                                    : Colors.grey,
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            Text(
                              _canResend ? "" : "Available in ${_formatTime(_resendTimerSeconds)}",
                              style: const TextStyle(
                                fontSize: 14,
                                color: Colors.grey,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 40),

                // Verify Code Button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: (_isCodeComplete && !_isCodeExpired && !_isLoading) ? _verifyCode : null,
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
                      "Verify Code",
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 20),

                // Help Text
                const Text(
                  "Code is case-sensitive • Check spam folder if not received",
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey,
                  ),
                  textAlign: TextAlign.center,
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

  @override
  void dispose() {
    for (var controller in _codeControllers) {
      controller.dispose();
    }
    for (var focusNode in _focusNodes) {
      focusNode.dispose();
    }
    super.dispose();
  }
}