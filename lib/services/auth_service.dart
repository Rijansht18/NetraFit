import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:netrafit/core/config/api_config.dart';
import '../models/api_response.dart';
import '../models/user_model.dart';

class AuthService {
  static const String baseUrl = ApiUrl.baseBackendUrl; // Your IP

  final http.Client client;

  AuthService({http.Client? client}) : client = client ?? http.Client();

  // Register method
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

      if (response.statusCode == 200 || response.statusCode == 201) {
        if (responseData['success'] == true) {
          return ApiResponse.fromJson(responseData);
        } else if (responseData['_id'] != null || responseData['user'] != null) {
          return ApiResponse(
            success: true,
            data: responseData,
            error: null,
          );
        } else if (responseData['message'] != null) {
          return ApiResponse(
            success: true,
            data: responseData,
            error: null,
          );
        }
      }

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

  // Login method
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
          'identifier': identifier,
          'password': password,
        }),
      ).timeout(const Duration(seconds: 10));

      print('Response Status: ${response.statusCode}');
      print('Response Body: ${response.body}');

      final Map<String, dynamic> responseData = json.decode(response.body);

      if (response.statusCode == 200) {
        if (responseData['token'] != null) {
          return ApiResponse(
            success: true,
            data: responseData,
            error: null,
          );
        } else if (responseData['message']?.contains('Successful') == true) {
          return ApiResponse(
            success: true,
            data: responseData,
            error: null,
          );
        }
      }

      if (responseData['error'] != null) {
        return ApiResponse(
          success: false,
          error: responseData['error'],
          data: null,
        );
      }

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

  // Get user profile
  Future<ApiResponse> getUserProfile(String token) async {
    try {
      print('=== GET USER PROFILE ===');

      final response = await client.get(
        Uri.parse('$baseUrl/users/profile'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      ).timeout(const Duration(seconds: 10));

      print('Profile Response Status: ${response.statusCode}');
      print('Profile Response Body: ${response.body}');

      final Map<String, dynamic> responseData = json.decode(response.body);

      if (response.statusCode == 200) {
        return ApiResponse(
          success: true,
          data: responseData,
          error: null,
        );
      }

      return ApiResponse.fromJson(responseData);

    } catch (e) {
      print('=== GET PROFILE ERROR ===');
      print('Error: $e');
      return ApiResponse(
        success: false,
        error: 'Failed to get user profile: ${e.toString()}',
      );
    }
  }

  // Forgot password method
  Future<ApiResponse> forgotPassword(String identifier) async {
    try {
      final response = await client.post(
        Uri.parse('$baseUrl/users/forgot-password'),
        headers: {
          'Content-Type': 'application/json',
        },
        body: json.encode({
          'identifier': identifier,
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