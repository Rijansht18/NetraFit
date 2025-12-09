// services/favorites_service.dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../core/config/api_config.dart';

class ApiResponse {
  final bool success;
  final Map<String, dynamic> data;
  final String? error;

  ApiResponse({
    required this.success,
    required this.data,
    this.error,
  });
}

class FavoritesService {
  // services/favorites_service.dart - Update getUserFavorites method
  Future<ApiResponse> getUserFavorites(String token) async {
    try {
      final url = Uri.parse('${ApiUrl.baseBackendUrl}/favorites/me');
      final headers = {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      };

      print('Fetching favorites from: $url');

      final response = await http.get(url, headers: headers);

      print('Favorites Response Status: ${response.statusCode}');

      if (response.body.isNotEmpty) {
        final data = json.decode(response.body);
        print('Favorites Response Data: $data');

        if (response.statusCode == 200) {
          return ApiResponse(
            success: true,
            data: data,
          );
        } else {
          return ApiResponse(
            success: false,
            data: {},
            error: data['message'] ?? data['error'] ?? 'Failed to get favorites',
          );
        }
      } else {
        // Empty response - return empty list
        return ApiResponse(
          success: true,
          data: {'favorites': []},
        );
      }
    } catch (e) {
      print('Get Favorites Error: $e');
      return ApiResponse(
        success: false,
        data: {},
        error: 'Network error: ${e.toString()}',
      );
    }
  }

  // Add to favorites
  Future<ApiResponse> addFavorite({
    required String token,
    required String frameId,
  }) async {
    try {
      final url = Uri.parse('${ApiUrl.baseBackendUrl}/favorites/add');
      final headers = {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      };

      final body = {
        'frameId': frameId,
      };

      print('Adding to favorites: ${json.encode(body)}');

      final response = await http.post(
        url,
        headers: headers,
        body: json.encode(body),
      );

      print('Add to Favorites Response: ${response.statusCode}');

      final data = response.body.isNotEmpty ? json.decode(response.body) : {};
      print('Response Data: $data');

      if (response.statusCode == 200 || response.statusCode == 201) {
        return ApiResponse(
          success: true,
          data: data,
        );
      } else {
        return ApiResponse(
          success: false,
          data: {},
          error: data['message'] ?? data['error'] ?? 'Failed to add to favorites',
        );
      }
    } catch (e) {
      print('Add to Favorites Error: $e');
      return ApiResponse(
        success: false,
        data: {},
        error: 'Network error: ${e.toString()}',
      );
    }
  }

  // Remove from favorites
  // services/favorites_service.dart - Update removeFavorite method
  Future<ApiResponse> removeFavorite({
    required String token,
    required String favoriteId,
  }) async {
    try {
      final url = Uri.parse('${ApiUrl.baseBackendUrl}/favorites/remove');
      final headers = {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      };

      final body = {
        'favoriteId': favoriteId,
      };

      print('Removing from favorites: ${json.encode(body)}');
      print('Authorization: Bearer $token');

      final response = await http.delete(
        url,
        headers: headers,
        body: json.encode(body),
      );

      print('Remove from Favorites Response: ${response.statusCode}');

      final data = response.body.isNotEmpty ? json.decode(response.body) : {};
      print('Response Data: $data');

      if (response.statusCode == 200) {
        return ApiResponse(
          success: true,
          data: data,
        );
      } else {
        return ApiResponse(
          success: false,
          data: {},
          error: data['message'] ?? data['error'] ?? 'Failed to remove from favorites',
        );
      }
    } catch (e) {
      print('Remove from Favorites Error: $e');
      return ApiResponse(
        success: false,
        data: {},
        error: 'Network error: ${e.toString()}',
      );
    }
  }
}