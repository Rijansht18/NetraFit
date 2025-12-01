import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import '../models/api_response.dart';

class CategoryService {
  static const String baseUrl = 'http://192.168.1.80:9000/api';

  final http.Client client;

  CategoryService({http.Client? client}) : client = client ?? http.Client();

  // Main Category Methods
  Future<ApiResponse> getAllMainCategories() async {
    try {
      final response = await client.get(
        Uri.parse('$baseUrl/main-categories'),
        headers: {'Content-Type': 'application/json'},
      ).timeout(Duration(seconds: 10));

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

  Future<ApiResponse> createMainCategory(String name) async {
    try {
      final response = await client.post(
        Uri.parse('$baseUrl/main-categories'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'name': name}),
      ).timeout(Duration(seconds: 10));

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
      return ApiResponse(
        success: false,
        error: 'Network error: ${e.toString()}',
      );
    }
  }

  Future<ApiResponse> updateMainCategory(String id, String name) async {
    try {
      final response = await client.put(
        Uri.parse('$baseUrl/main-categories/$id'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'name': name}),
      ).timeout(Duration(seconds: 10));

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

  Future<ApiResponse> deleteMainCategory(String id) async {
    try {
      final response = await client.delete(
        Uri.parse('$baseUrl/main-categories/$id'),
        headers: {'Content-Type': 'application/json'},
      ).timeout(Duration(seconds: 10));

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

  // Sub Category Methods
  Future<ApiResponse> getAllSubCategories() async {
    try {
      final response = await client.get(
        Uri.parse('$baseUrl/sub-categories'),
        headers: {'Content-Type': 'application/json'},
      ).timeout(Duration(seconds: 10));

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

  Future<ApiResponse> createSubCategory(String name, String mainCategoryId, String? imageBase64) async {
    try {
      final Map<String, dynamic> body = {
        'name': name,
        'mainCategory': mainCategoryId,
      };

      if (imageBase64 != null) {
        body['image'] = imageBase64;
      }

      final response = await client.post(
        Uri.parse('$baseUrl/sub-categories'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode(body),
      ).timeout(Duration(seconds: 10));

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
      return ApiResponse(
        success: false,
        error: 'Network error: ${e.toString()}',
      );
    }
  }

  Future<ApiResponse> updateSubCategory(String id, String name, String mainCategoryId, String? imageBase64) async {
    try {
      final Map<String, dynamic> body = {
        'name': name,
        'mainCategory': mainCategoryId,
      };

      if (imageBase64 != null) {
        body['image'] = imageBase64;
      }

      final response = await client.put(
        Uri.parse('$baseUrl/sub-categories/$id'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode(body),
      ).timeout(Duration(seconds: 10));

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

  Future<ApiResponse> deleteSubCategory(String id) async {
    try {
      final response = await client.delete(
        Uri.parse('$baseUrl/sub-categories/$id'),
        headers: {'Content-Type': 'application/json'},
      ).timeout(Duration(seconds: 10));

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

  // Utility method to convert image to base64
  Future<String?> imageToBase64(File imageFile) async {
    try {
      List<int> imageBytes = await imageFile.readAsBytes();
      String base64Image = base64Encode(imageBytes);
      return base64Image;
    } catch (e) {
      return null;
    }
  }
}