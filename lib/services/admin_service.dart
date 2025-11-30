import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:netrafit/core/config/api_config.dart';
import '../models/api_response.dart';
import '../models/user_model.dart';

class AdminService {
  static const String baseUrl = ApiUrl.baseBackendUrl; // Your backend URL

  final http.Client client;

  AdminService({http.Client? client}) : client = client ?? http.Client();

  // Get all users
  Future<ApiResponse> getAllUsers() async {
    try {
      print('=== GET ALL USERS ===');

      final response = await client.get(
        Uri.parse('$baseUrl/users/allUsers'),
        headers: {
          'Content-Type': 'application/json',
        },
      ).timeout(const Duration(seconds: 10));

      print('Response Status: ${response.statusCode}');
      print('Response Body: ${response.body}');

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
      print('=== GET ALL USERS ERROR ===');
      print('Error: $e');
      return ApiResponse(
        success: false,
        error: 'Network error: ${e.toString()}',
      );
    }
  }

  // Delete user
  Future<ApiResponse> deleteUser(String userId) async {
    try {
      print('=== DELETE USER ===');
      print('User ID: $userId');

      final response = await client.delete(
        Uri.parse('$baseUrl/users/$userId'),
        headers: {
          'Content-Type': 'application/json',
        },
      ).timeout(const Duration(seconds: 10));

      print('Response Status: ${response.statusCode}');
      print('Response Body: ${response.body}');

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
      print('=== DELETE USER ERROR ===');
      print('Error: $e');
      return ApiResponse(
        success: false,
        error: 'Network error: ${e.toString()}',
      );
    }
  }

  // Get user by ID
  Future<ApiResponse> getUserById(String userId) async {
    try {
      final response = await client.get(
        Uri.parse('$baseUrl/users/$userId'),
        headers: {
          'Content-Type': 'application/json',
        },
      ).timeout(const Duration(seconds: 10));

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
      return ApiResponse(
        success: false,
        error: 'Network error: ${e.toString()}',
      );
    }
  }

  // Create new user (both customer and admin)
  Future<ApiResponse> createUser(UserModel user) async {
    try {
      print('=== CREATE USER ===');
      print('User Data: ${user.toRegisterJson()}');

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

      if (response.statusCode == 201 || response.statusCode == 200) {
        return ApiResponse(
          success: true,
          data: responseData,
          error: null,
        );
      }

      return ApiResponse.fromJson(responseData);

    } catch (e) {
      print('=== CREATE USER ERROR ===');
      print('Error: $e');
      return ApiResponse(
        success: false,
        error: 'Network error: ${e.toString()}',
      );
    }
  }

  // Update user role
  Future<ApiResponse> updateUserRole(String userId, String newRole) async {
    try {
      print('=== UPDATE USER ROLE ===');
      print('User ID: $userId');
      print('New Role: $newRole');

      final response = await client.put(
        Uri.parse('$baseUrl/users/$userId/role'),
        headers: {
          'Content-Type': 'application/json',
        },
        body: json.encode({'role': newRole}),
      ).timeout(const Duration(seconds: 10));

      print('Response Status: ${response.statusCode}');
      print('Response Body: ${response.body}');

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
      print('=== UPDATE USER ROLE ERROR ===');
      print('Error: $e');
      return ApiResponse(
        success: false,
        error: 'Network error: ${e.toString()}',
      );
    }
  }

  // Update user status
  Future<ApiResponse> updateUserStatus(String userId, String newStatus) async {
    try {
      print('=== UPDATE USER STATUS ===');
      print('User ID: $userId');
      print('New Status: $newStatus');

      final response = await client.put(
        Uri.parse('$baseUrl/users/$userId/status'),
        headers: {
          'Content-Type': 'application/json',
        },
        body: json.encode({'status': newStatus}),
      ).timeout(const Duration(seconds: 10));

      print('Response Status: ${response.statusCode}');
      print('Response Body: ${response.body}');

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
      print('=== UPDATE USER STATUS ERROR ===');
      print('Error: $e');
      return ApiResponse(
        success: false,
        error: 'Network error: ${e.toString()}',
      );
    }
  }

  // Clear user suspension
  Future<ApiResponse> clearUserSuspension(String userId) async {
    try {
      print('=== CLEAR USER SUSPENSION ===');
      print('User ID: $userId');

      final response = await client.put(
        Uri.parse('$baseUrl/users/$userId/clear-suspension'),
        headers: {
          'Content-Type': 'application/json',
        },
        body: json.encode({}),
      ).timeout(const Duration(seconds: 10));

      print('Response Status: ${response.statusCode}');
      print('Response Body: ${response.body}');

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
      print('=== CLEAR USER SUSPENSION ERROR ===');
      print('Error: $e');
      return ApiResponse(
        success: false,
        error: 'Network error: ${e.toString()}',
      );
    }
  }
}