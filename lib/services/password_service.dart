import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:netrafit/core/config/api_config.dart';
import '../models/api_response.dart';

class PasswordService {
  static const String baseUrl = ApiUrl.baseBackendUrl;

  final http.Client client;

  PasswordService({http.Client? client}) : client = client ?? http.Client();

  // Step 1: Request reset code
  Future<ApiResponse> requestResetCode(String email) async {
    try {
      print('=== REQUEST RESET CODE ===');
      print('Email: $email');

      final response = await client.post(
        Uri.parse('$baseUrl/users/requestResetCode'),
        headers: {
          'Content-Type': 'application/json',
        },
        body: json.encode({
          'email': email,
        }),
      ).timeout(const Duration(seconds: 10));

      print('Response Status: ${response.statusCode}');
      print('Response Body: ${response.body}');

      final Map<String, dynamic> responseData = json.decode(response.body);

      // Always include statusCode in the response
      return ApiResponse(
        success: response.statusCode == 200,
        data: responseData,
        error: responseData['error'],
        statusCode: response.statusCode, // Add this line
      );

    } catch (e) {
      print('=== REQUEST RESET CODE ERROR ===');
      print('Error: $e');
      return ApiResponse(
        success: false,
        error: 'Network error: ${e.toString()}',
        statusCode: 500, // Add status code for errors too
      );
    }
  }

  // Step 2: Verify reset code
  Future<ApiResponse> verifyResetCode(String email, String resetCode) async {
    try {
      print('=== VERIFY RESET CODE ===');
      print('Email: $email');
      print('Code: $resetCode');

      final response = await client.post(
        Uri.parse('$baseUrl/users/verifyResetCode'),
        headers: {
          'Content-Type': 'application/json',
        },
        body: json.encode({
          'email': email,
          'resetCode': resetCode,
        }),
      ).timeout(const Duration(seconds: 10));

      print('Response Status: ${response.statusCode}');
      print('Response Body: ${response.body}');

      final Map<String, dynamic> responseData = json.decode(response.body);

      return ApiResponse(
        success: response.statusCode == 200,
        data: responseData,
        error: responseData['error'],
        statusCode: response.statusCode, // Add this line
      );

    } catch (e) {
      print('=== VERIFY RESET CODE ERROR ===');
      print('Error: $e');
      return ApiResponse(
        success: false,
        error: 'Network error: ${e.toString()}',
        statusCode: 500,
      );
    }
  }

  // Step 3: Reset password with temporary token
  Future<ApiResponse> resetPassword(String tempToken, String newPassword) async {
    try {
      print('=== RESET PASSWORD ===');

      final response = await client.post(
        Uri.parse('$baseUrl/users/resetPassword'),
        headers: {
          'Content-Type': 'application/json',
        },
        body: json.encode({
          'tempToken': tempToken,
          'newPassword': newPassword,
          'logoutAllDevices': true,
        }),
      ).timeout(const Duration(seconds: 10));

      print('Response Status: ${response.statusCode}');
      print('Response Body: ${response.body}');

      final Map<String, dynamic> responseData = json.decode(response.body);

      return ApiResponse(
        success: response.statusCode == 200,
        data: responseData,
        error: responseData['error'],
        statusCode: response.statusCode, // Add this line
      );

    } catch (e) {
      print('=== RESET PASSWORD ERROR ===');
      print('Error: $e');
      return ApiResponse(
        success: false,
        error: 'Network error: ${e.toString()}',
        statusCode: 500,
      );
    }
  }
}