import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:netrafit/core/config/api_config.dart';

import '../models/api_response.dart';
import '../models/user_model.dart';

class AuthService {
  static const String baseUrl = ApiUrl.baseBackendUrl; // Replace with your actual backend URL

  final http.Client client;

  AuthService({http.Client? client}) : client = client ?? http.Client();

  Future<ApiResponse> register(UserModel user) async {
    try {
      print('=== REGISTER API CALL ===');
      print('URL: $baseUrl/users/register');
      print('Request Data: ${user.toRegisterJson()}');

      final response = await client.post(
        Uri.parse('$baseUrl/users/register'),
        headers: {
          'Content-Type': 'application/json',
        },
        body: json.encode(user.toRegisterJson()),
      ).timeout(const Duration(seconds: 10));

      print('Response Status: ${response.statusCode}');
      print('Response Body: ${response.body}');

      final Map<String, dynamic> responseData = json.decode(response.body);

      // Handle different success scenarios
      if (response.statusCode == 200 || response.statusCode == 201) {
        // If backend returns success: true
        if (responseData['success'] == true) {
          return ApiResponse.fromJson(responseData);
        }
        // If backend returns user data directly (without success field)
        else if (responseData['_id'] != null || responseData['user'] != null) {
          return ApiResponse(
            success: true,
            data: responseData,
            error: null,
          );
        }
        // If backend returns message only
        else if (responseData['message'] != null) {
          return ApiResponse(
            success: true,
            data: responseData,
            error: null,
          );
        }
      }

      // If we reach here, treat as failure
      return ApiResponse.fromJson(responseData);

    } catch (e) {
      print('=== REGISTER ERROR ===');
      print('Error: $e');
      return ApiResponse(
        success: false,
        error: 'Network error: ${e.toString()}',
      );
    }
  }

  // Login method - updated for your backend
  Future<ApiResponse> login(String identifier, String password) async {
    try {
      print('=== LOGIN API CALL ===');
      print('URL: $baseUrl/users/login');
      print('Identifier: $identifier');

      final response = await client.post(
        Uri.parse('$baseUrl/users/login'),
        headers: {
          'Content-Type': 'application/json',
        },
        body: json.encode({
          'identifier': identifier, // Can be email or username
          'password': password,
        }),
      ).timeout(const Duration(seconds: 10));

      print('Response Status: ${response.statusCode}');
      print('Response Body: ${response.body}');

      final Map<String, dynamic> responseData = json.decode(response.body);

      // Handle success scenarios for your backend
      if (response.statusCode == 200) {
        // Your backend returns {message: "Login Successful", token: "jwt_token"}
        if (responseData['token'] != null) {
          return ApiResponse(
            success: true,
            data: responseData,
            error: null,
          );
        }
        // If backend returns success with token
        else if (responseData['message']?.contains('Successful') == true) {
          return ApiResponse(
            success: true,
            data: responseData,
            error: null,
          );
        }
      }

      // Handle error responses from your backend
      if (responseData['error'] != null) {
        return ApiResponse(
          success: false,
          error: responseData['error'],
          data: null,
        );
      }

      // Default failure
      return ApiResponse(
        success: false,
        error: 'Login failed',
        data: null,
      );

    } catch (e) {
      print('=== LOGIN ERROR ===');
      print('Error: $e');
      return ApiResponse(
        success: false,
        error: 'Network error: ${e.toString()}',
      );
    }
  }

  // Forgot password method (optional)
  Future<ApiResponse> forgotPassword(String email) async {
    try {
      final response = await client.post(
        Uri.parse('$baseUrl/users/forgot-password'), // Adjust endpoint
        headers: {
          'Content-Type': 'application/json',
        },
        body: json.encode({
          'email': email,
        }),
      ).timeout(const Duration(seconds: 10));

      final Map<String, dynamic> responseData = json.decode(response.body);
      return ApiResponse.fromJson(responseData);

    } catch (e) {
      return ApiResponse(
        success: false,
        error: 'Network error: ${e.toString()}',
      );
    }
  }
}