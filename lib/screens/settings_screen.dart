import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:http/http.dart' as http;
import 'package:netrafit/providers/auth_provider.dart';
import 'package:netrafit/services/auth_service.dart';
import 'package:netrafit/models/user_model.dart';
import 'package:netrafit/core/config/api_config.dart';
import '../models/api_response.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  UserModel? _userProfile;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadUserProfile();
  }

  Future<void> _loadUserProfile() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final token = authProvider.token;

    if (token != null) {
      setState(() {
        _isLoading = true;
      });

      try {
        // Try getting profile from backend API /me
        final response = await http.get(
          Uri.parse('${ApiUrl.baseBackendUrl}/users/me'),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $token',
          },
        ).timeout(const Duration(seconds: 10));

        print('Profile API Response Status: ${response.statusCode}');
        print('Profile API Response Body: ${response.body}');

        if (response.statusCode == 200) {
          final Map<String, dynamic> responseData = json.decode(response.body);

          // Handle the response format {"user": {...}}
          if (responseData['user'] != null) {
            setState(() {
              _userProfile = UserModel.fromJson(responseData['user']);
            });
            print('User profile loaded successfully');
          } else if (responseData['_id'] != null) {
            setState(() {
              _userProfile = UserModel.fromJson(responseData);
            });
            print('User profile loaded directly');
          }
        } else {
          // If /me fails, try the auth service method
          final authService = AuthService();
          final serviceResponse = await authService.getUserProfile(token);

          if (serviceResponse.success && serviceResponse.data != null) {
            if (serviceResponse.data['user'] != null) {
              setState(() {
                _userProfile = UserModel.fromJson(serviceResponse.data['user']);
              });
            } else if (serviceResponse.data['data'] != null) {
              setState(() {
                _userProfile = UserModel.fromJson(serviceResponse.data['data']);
              });
            }
          }
        }
      } catch (e) {
        print('Error loading profile: $e');
      } finally {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
        children: [
          // User Profile Section
          Container(
            color: Colors.white,
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Search Settings',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey,
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    CircleAvatar(
                      radius: 24,
                      backgroundColor: Colors.blueAccent,
                      backgroundImage: _userProfile?.profilePhoto != null &&
                          _userProfile!.profilePhoto!.isNotEmpty &&
                          _userProfile!.profilePhoto != 'null'
                          ? NetworkImage(_userProfile!.profilePhoto!)
                          : null,
                      child: _userProfile?.profilePhoto == null ||
                          _userProfile!.profilePhoto!.isEmpty ||
                          _userProfile!.profilePhoto == 'null'
                          ? const Icon(Icons.person, color: Colors.white)
                          : null,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _userProfile?.fullname ?? 'Loading...',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _userProfile?.email ?? 'Loading...',
                            style: const TextStyle(
                              fontSize: 14,
                              color: Colors.grey,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.refresh, size: 20),
                      onPressed: _loadUserProfile,
                    ),
                  ],
                ),
              ],
            ),
          ),
          const Divider(height: 1),

          // Account and Security Section
          Container(
            color: Colors.white,
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Account and Security',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey,
                  ),
                ),
                const SizedBox(height: 16),
                _buildSettingsItem(
                  icon: Icons.lock,
                  title: 'Privacy policy',
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const PrivacyPolicyScreen(),
                      ),
                    );
                  },
                ),
                _buildSettingsItem(
                  icon: Icons.security,
                  title: 'Password & Security',
                  onTap: () {
                    _showChangePasswordDialog(context);
                  },
                ),
              ],
            ),
          ),
          const Divider(height: 1),

          // Help & Support Section
          Container(
            color: Colors.white,
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Help & Support',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey,
                  ),
                ),
                const SizedBox(height: 16),
                _buildSettingsItem(
                  icon: Icons.help_outline,
                  title: 'Help & Support',
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const HelpSupportScreen(),
                      ),
                    );
                  },
                ),
                _buildSettingsItem(
                  icon: Icons.question_answer,
                  title: 'FAQ',
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const FAQScreen(),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
          const Divider(height: 1),

          // Logout Button
          Container(
            padding: const EdgeInsets.all(16),
            child: Center(
              child: ElevatedButton(
                onPressed: () {
                  authProvider.logout();
                  Navigator.pushReplacementNamed(context, '/onboarding');
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(double.infinity, 48),
                ),
                child: const Text('Logout'),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSettingsItem({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
  }) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(icon, color: Colors.black54),
      title: Text(title),
      trailing: const Icon(Icons.chevron_right, size: 20),
      onTap: onTap,
    );
  }

  void _showChangePasswordDialog(BuildContext context) {
    final oldPasswordController = TextEditingController();
    final newPasswordController = TextEditingController();
    final confirmPasswordController = TextEditingController();
    bool _isChangingPassword = false;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('Change Password'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: oldPasswordController,
                    obscureText: true,
                    decoration: const InputDecoration(
                      labelText: 'Old Password',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: newPasswordController,
                    obscureText: true,
                    decoration: const InputDecoration(
                      labelText: 'New Password',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: confirmPasswordController,
                    obscureText: true,
                    decoration: const InputDecoration(
                      labelText: 'Confirm New Password',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  if (_isChangingPassword)
                    const Padding(
                      padding: EdgeInsets.only(top: 16),
                      child: CircularProgressIndicator(),
                    ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: _isChangingPassword ? null : () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: _isChangingPassword
                      ? null
                      : () async {
                    if (oldPasswordController.text.isEmpty ||
                        newPasswordController.text.isEmpty ||
                        confirmPasswordController.text.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Please fill all fields'),
                        ),
                      );
                      return;
                    }

                    if (newPasswordController.text != confirmPasswordController.text) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('New passwords do not match'),
                        ),
                      );
                      return;
                    }

                    setState(() {
                      _isChangingPassword = true;
                    });

                    final authProvider =
                    Provider.of<AuthProvider>(context, listen: false);
                    final token = authProvider.token;

                    if (token != null) {
                      final response = await _changePassword(
                        token,
                        oldPasswordController.text,
                        newPasswordController.text,
                      );

                      setState(() {
                        _isChangingPassword = false;
                      });

                      // Check for success based on different response formats
                      bool isSuccess = response.success;

                      // Also check for common success messages
                      if (response.data != null) {
                        final responseData = response.data as Map<String, dynamic>;
                        if (responseData['message']?.toString().toLowerCase().contains('success') == true ||
                            responseData['success'] == true ||
                            responseData['status']?.toString().toLowerCase().contains('success') == true) {
                          isSuccess = true;
                        }
                      }

                      if (isSuccess) {
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Password changed successfully'),
                            backgroundColor: Colors.green,
                          ),
                        );
                      } else {
                        // Try to get a better error message
                        String errorMessage = 'Failed to change password';
                        if (response.data != null) {
                          final responseData = response.data as Map<String, dynamic>;
                          errorMessage = responseData['message'] ??
                              responseData['error'] ??
                              response.error ??
                              'Failed to change password';
                        } else if (response.error != null) {
                          errorMessage = response.error!;
                        }

                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(errorMessage),
                            backgroundColor: Colors.red,
                          ),
                        );
                      }
                    } else {
                      setState(() {
                        _isChangingPassword = false;
                      });
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Please login again'),
                          backgroundColor: Colors.red,
                        ),
                      );
                      Navigator.pop(context);
                    }
                  },
                  child: const Text('Change'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<ApiResponse> _changePassword(
      String token,
      String oldPassword,
      String newPassword,
      ) async {
    try {
      print('=== CHANGE PASSWORD API CALL ===');
      print('URL: ${ApiUrl.baseBackendUrl}/users/changePassword');
      print('Token: ${token.substring(0, 20)}...');
      print('Old Password: $oldPassword');
      print('New Password: $newPassword');

      final response = await http.post(
        Uri.parse('${ApiUrl.baseBackendUrl}/users/changePassword'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: json.encode({
          'oldPassword': oldPassword,
          'newPassword': newPassword,
        }),
      ).timeout(const Duration(seconds: 10));

      print('Change Password Response Status: ${response.statusCode}');
      print('Change Password Response Body: ${response.body}');

      final Map<String, dynamic> responseData = json.decode(response.body);

      // Check for different success response formats
      if (response.statusCode == 200) {
        // Check for various success indicators
        if (responseData['message']?.toString().toLowerCase().contains('success') == true ||
            responseData['success'] == true ||
            responseData['status']?.toString().toLowerCase().contains('success') == true ||
            responseData['passwordChanged'] == true) {
          return ApiResponse(
            success: true,
            data: responseData,
            error: null,
          );
        }

        // If no explicit success indicator, but status is 200, check for common patterns
        if (responseData['error'] == null && responseData['message'] != null) {
          return ApiResponse(
            success: true,
            data: responseData,
            error: null,
          );
        }
      }

      // Return error response
      String errorMessage = 'Failed to change password';
      if (responseData['message'] != null) {
        errorMessage = responseData['message'].toString();
      } else if (responseData['error'] != null) {
        errorMessage = responseData['error'].toString();
      } else if (response.statusCode != 200) {
        errorMessage = 'Server returned status code ${response.statusCode}';
      }

      return ApiResponse(
        success: false,
        error: errorMessage,
        data: responseData,
      );
    } catch (e) {
      print('=== CHANGE PASSWORD ERROR ===');
      print('Error: $e');
      return ApiResponse(
        success: false,
        error: 'Network error: ${e.toString()}',
        data: null,
      );
    }
  }
}

// Privacy Policy Screen (same as before)
class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Privacy Policy'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: const [
          Text(
            'Privacy Policy',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              height: 1.5,
            ),
          ),
          SizedBox(height: 20),
          Text(
            'Last Updated: January 2024',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey,
            ),
          ),
          SizedBox(height: 30),
          Text(
            '1. Information We Collect',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              height: 1.5,
            ),
          ),
          SizedBox(height: 10),
          Text(
            'We collect information you provide directly to us, such as when you create an account, update your profile, make purchases, or contact customer support. This may include:\n\n• Name and contact information\n• Profile information\n• Payment information\n• Communications with us',
            style: TextStyle(fontSize: 16, height: 1.5),
          ),
          SizedBox(height: 30),
          Text(
            '2. How We Use Your Information',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              height: 1.5,
            ),
          ),
          SizedBox(height: 10),
          Text(
            'We use the information we collect to:\n\n• Provide, maintain, and improve our services\n• Process transactions and send related information\n• Send technical notices, updates, and support messages\n• Respond to your comments and questions\n• Personalize your experience\n• Detect, prevent, and address technical issues',
            style: TextStyle(fontSize: 16, height: 1.5),
          ),
          SizedBox(height: 30),
          Text(
            '3. Information Sharing',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              height: 1.5,
            ),
          ),
          SizedBox(height: 10),
          Text(
            'We do not share your personal information with third parties except in the following circumstances:\n\n• With your consent\n• For legal reasons\n• With service providers who assist in our operations\n• In connection with a business transfer',
            style: TextStyle(fontSize: 16, height: 1.5),
          ),
          SizedBox(height: 30),
          Text(
            '4. Data Security',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              height: 1.5,
            ),
          ),
          SizedBox(height: 10),
          Text(
            'We implement appropriate technical and organizational security measures to protect your personal information. However, no method of transmission over the Internet or electronic storage is 100% secure.',
            style: TextStyle(fontSize: 16, height: 1.5),
          ),
          SizedBox(height: 30),
          Text(
            '5. Your Rights',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              height: 1.5,
            ),
          ),
          SizedBox(height: 10),
          Text(
            'You have the right to:\n\n• Access your personal information\n• Correct inaccurate information\n• Delete your personal information\n• Object to processing of your personal information\n• Data portability\n• Withdraw consent',
            style: TextStyle(fontSize: 16, height: 1.5),
          ),
          SizedBox(height: 30),
          Text(
            '6. Contact Us',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              height: 1.5,
            ),
          ),
          SizedBox(height: 10),
          Text(
            'If you have any questions about this Privacy Policy, please contact us at:\n\nEmail: privacy@netrafit.com\nAddress: 123 Privacy Street, Security City, SC 12345',
            style: TextStyle(fontSize: 16, height: 1.5),
          ),
        ],
      ),
    );
  }
}

// Help & Support Screen (same as before)
class HelpSupportScreen extends StatelessWidget {
  const HelpSupportScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Help & Support'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildSupportOption(
            icon: Icons.email,
            title: 'Contact Us',
            subtitle: 'Send us an email',
            onTap: () {},
          ),
          _buildSupportOption(
            icon: Icons.chat,
            title: 'Live Chat',
            subtitle: 'Chat with our support team',
            onTap: () {},
          ),
          _buildSupportOption(
            icon: Icons.phone,
            title: 'Call Us',
            subtitle: 'Call our support hotline',
            onTap: () {},
          ),
          _buildSupportOption(
            icon: Icons.description,
            title: 'User Guide',
            subtitle: 'Read our user guide',
            onTap: () {},
          ),
        ],
      ),
    );
  }

  Widget _buildSupportOption({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Card(
      child: ListTile(
        leading: Icon(icon, size: 30, color: Colors.blue),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }
}

// FAQ Screen (same as before)
class FAQScreen extends StatelessWidget {
  const FAQScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Frequently Asked Questions'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: const [
          ExpansionTile(
            title: Text('How do I reset my password?'),
            children: [
              Padding(
                padding: EdgeInsets.all(16),
                child: Text(
                  'To reset your password, go to Settings > Password & Security. Enter your old password and new password, then confirm the change.',
                ),
              ),
            ],
          ),
          ExpansionTile(
            title: Text('How can I update my profile information?'),
            children: [
              Padding(
                padding: EdgeInsets.all(16),
                child: Text(
                  'You can update your profile information by tapping on your profile picture in the Settings screen and selecting Edit Profile.',
                ),
              ),
            ],
          ),
          ExpansionTile(
            title: Text('How do I contact customer support?'),
            children: [
              Padding(
                padding: EdgeInsets.all(16),
                child: Text(
                  'You can contact customer support through the Help & Support section in Settings. We offer email, live chat, and phone support.',
                ),
              ),
            ],
          ),
          ExpansionTile(
            title: Text('Where can I find my order history?'),
            children: [
              Padding(
                padding: EdgeInsets.all(16),
                child: Text(
                  'Your order history is available in the Order & Storage section of the Settings screen.',
                ),
              ),
            ],
          ),
          ExpansionTile(
            title: Text('How do I change the app theme?'),
            children: [
              Padding(
                padding: EdgeInsets.all(16),
                child: Text(
                  'Go to Settings > Preferences > Theme. You can choose between light and dark mode.',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}