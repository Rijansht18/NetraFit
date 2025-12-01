import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import '../core/config/api_config.dart';
import '../models/api_response.dart';
import '../models/frame_model.dart';

class FrameService {
  static const String basePath = '${ApiUrl.baseBackendUrl}/frames';

  // Create Frame with multipart/form-data
  Future<ApiResponse> createFrameWithImages({
    required Map<String, dynamic> textFields,
    required List<XFile> productImages,
    required XFile overlayImage,
  }) async {
    try {
      // Create multipart request
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

      // Add colors as comma-separated string
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
          // message: responseData['message'] ?? 'Frame created successfully',
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

  // Update Frame with multipart/form-data
  Future<ApiResponse> updateFrameWithImages({
    required String frameId,
    required Map<String, dynamic> textFields,
    List<XFile>? newProductImages,
    XFile? newOverlayImage,
  }) async {
    try {
      // Create multipart request
      var request = http.MultipartRequest('PUT', Uri.parse('$basePath/$frameId'));

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

      // Add colors as comma-separated string
      if (textFields['colors'] is List) {
        final colorsList = textFields['colors'] as List<dynamic>;
        request.fields['colors'] = colorsList.join(',');
      }

      // Add new product images if provided
      if (newProductImages != null && newProductImages.isNotEmpty) {
        for (int i = 0; i < newProductImages.length; i++) {
          final image = newProductImages[i];
          final file = File(image.path);
          request.files.add(
            await http.MultipartFile.fromPath(
              'images',
              file.path,
              filename: 'product_update_${DateTime.now().millisecondsSinceEpoch}_$i.jpg',
            ),
          );
        }
      }

      // Add new overlay image if provided
      if (newOverlayImage != null) {
        final overlayFile = File(newOverlayImage.path);
        request.files.add(
          await http.MultipartFile.fromPath(
            'overlayImage',
            overlayFile.path,
            filename: 'overlay_update_${DateTime.now().millisecondsSinceEpoch}.jpg',
          ),
        );
      }

      // Send request
      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      final responseData = json.decode(response.body);

      if (response.statusCode == 200) {
        return ApiResponse(
          success: true,
          data: responseData,
          // message: responseData['message'] ?? 'Frame updated successfully',
        );
      } else {
        return ApiResponse(
          success: false,
          error: responseData['error'] ?? 'Failed to update frame',
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

  // Simple JSON methods (without images)
  Future<ApiResponse> createFrame(Map<String, dynamic> frameData) async {
    try {
      final response = await http.post(
        Uri.parse(basePath),
        headers: {'Content-Type': 'application/json'},
        body: json.encode(frameData),
      ).timeout(const Duration(seconds: 30));

      final Map<String, dynamic> responseData = json.decode(response.body);

      if (response.statusCode == 201) {
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

  Future<ApiResponse> updateFrame(String frameId, Map<String, dynamic> frameData) async {
    try {
      final response = await http.put(
        Uri.parse('$basePath/$frameId'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode(frameData),
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

  // Keep existing methods as they are
  Future<ApiResponse> getAllFrames() async {
    try {
      final response = await http.get(
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

  Future<ApiResponse> getFrameById(String frameId) async {
    try {
      final response = await http.get(
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

  Future<ApiResponse> deleteFrame(String frameId) async {
    try {
      final response = await http.delete(
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

  Future<ApiResponse> getFramesByCategory({String? mainCategoryId, String? subCategoryId}) async {
    try {
      final Map<String, String> queryParams = {};
      if (mainCategoryId != null) queryParams['mainCategoryId'] = mainCategoryId;
      if (subCategoryId != null) queryParams['subCategoryId'] = subCategoryId;

      final uri = Uri.parse('$basePath/category').replace(queryParameters: queryParams);

      final response = await http.get(
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

  Future<ApiResponse> getAvailableSizes() async {
    try {
      final response = await http.get(
        Uri.parse('$basePath/sizes/available'),
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
}