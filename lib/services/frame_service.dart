import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import '../models/api_response.dart';
import '../models/frame_model.dart';

class FrameService {
  static const String basePath = 'https://ar-eyewear-try-on-backend-1.onrender.com/api/frames';

  final http.Client client;

  FrameService({http.Client? client}) : client = client ?? http.Client();

  // Get all frames
  Future<ApiResponse> getAllFrames() async {
    try {
      final response = await client.get(
        Uri.parse(basePath),
        headers: {'Content-Type': 'application/json'},
      ).timeout(const Duration(seconds: 30));

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

  // Get frames by main category
  Future<ApiResponse> getFramesByMainCategory(String mainCategoryId) async {
    try {
      final response = await client.get(
        Uri.parse('$basePath?mainCategory=$mainCategoryId'),
        headers: {'Content-Type': 'application/json'},
      ).timeout(const Duration(seconds: 30));

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

  // Get frames by sub category
  Future<ApiResponse> getFramesBySubCategory(String subCategoryId) async {
    try {
      final response = await client.get(
        Uri.parse('$basePath?subCategory=$subCategoryId'),
        headers: {'Content-Type': 'application/json'},
      ).timeout(const Duration(seconds: 30));

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

  // Get featured frames (active frames, limited)
  Future<ApiResponse> getFeaturedFrames({int limit = 4}) async {
    try {
      final response = await client.get(
        Uri.parse('$basePath?isActive=true&limit=$limit'),
        headers: {'Content-Type': 'application/json'},
      ).timeout(const Duration(seconds: 30));

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

  // Get frame by ID
  Future<ApiResponse> getFrameById(String frameId) async {
    try {
      final response = await client.get(
        Uri.parse('$basePath/$frameId'),
        headers: {'Content-Type': 'application/json'},
      ).timeout(const Duration(seconds: 30));

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

  // Delete frame
  Future<ApiResponse> deleteFrame(String frameId) async {
    try {
      final response = await client.delete(
        Uri.parse('$basePath/$frameId'),
        headers: {'Content-Type': 'application/json'},
      ).timeout(const Duration(seconds: 30));

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

  // Get frames by categories
  Future<ApiResponse> getFramesByCategories({
    String? mainCategoryId,
    String? subCategoryId,
  }) async {
    try {
      final Map<String, String> queryParams = {};
      if (mainCategoryId != null) queryParams['mainCategory'] = mainCategoryId;
      if (subCategoryId != null) queryParams['subCategory'] = subCategoryId;

      final uri = Uri.parse(basePath).replace(queryParameters: queryParams);

      final response = await client.get(
        uri,
        headers: {'Content-Type': 'application/json'},
      ).timeout(const Duration(seconds: 30));

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

  // Create Frame with multipart/form-data
  Future<ApiResponse> createFrameWithImages({
    required Map<String, dynamic> textFields,
    required List<XFile> productImages,
    required XFile overlayImage,
  }) async {
    try {
      var request = http.MultipartRequest('POST', Uri.parse(basePath));

      // Add text fields
      request.fields['name'] = textFields['name'] ?? '';
      request.fields['brand'] = textFields['brand'] ?? '';
      request.fields['mainCategory'] = textFields['mainCategory'] ?? '';
      request.fields['subCategory'] = textFields['subCategory'] ?? '';
      request.fields['type'] = textFields['type'] ?? '';
      request.fields['shape'] = textFields['shape'] ?? '';
      request.fields['price'] = (textFields['price'] ?? 0).toString();
      request.fields['quantity'] = (textFields['quantity'] ?? 0).toString();
      request.fields['size'] = textFields['size'] ?? '';
      request.fields['description'] = textFields['description'] ?? '';

      // Add colors
      if (textFields['colors'] is List) {
        final colorsList = textFields['colors'] as List<dynamic>;
        request.fields['colors'] = colorsList.join(',');
      }

      // Add product images
      for (int i = 0; i < productImages.length; i++) {
        final image = productImages[i];
        final file = File(image.path);
        request.files.add(
          await http.MultipartFile.fromPath(
            'images',
            file.path,
            filename: 'product_${DateTime.now().millisecondsSinceEpoch}_$i.jpg',
          ),
        );
      }

      // Add overlay image
      final overlayFile = File(overlayImage.path);
      request.files.add(
        await http.MultipartFile.fromPath(
          'overlayImage',
          overlayFile.path,
          filename: 'overlay_${DateTime.now().millisecondsSinceEpoch}.jpg',
        ),
      );

      // Send request
      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);
      final responseData = json.decode(response.body);

      if (response.statusCode == 201) {
        return ApiResponse(
          success: true,
          data: responseData,
        );
      } else {
        return ApiResponse(
          success: false,
          error: responseData['error'] ?? 'Failed to create frame',
          data: responseData,
        );
      }
    } catch (e) {
      return ApiResponse(
        success: false,
        error: 'Network error: ${e.toString()}',
      );
    }
  }

  // Helper methods for image URLs
  static String getFrameImageUrl(String frameId, [int imageIndex = 0]) {
    return 'https://ar-eyewear-try-on-backend-1.onrender.com/api/frames/images/$frameId/$imageIndex';
  }

  static String getFrameOverlayUrl(String frameId) {
    return 'https://ar-eyewear-try-on-backend-1.onrender.com/api/frames/overlay/$frameId';
  }
}