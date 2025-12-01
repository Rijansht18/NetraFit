import 'dart:convert';
import 'package:http/http.dart' as http;
import '../core/config/api_config.dart';
import '../models/api_response.dart';
import '../models/cart_model.dart';

class CartService {
  Future<ApiResponse> getCart(String token) async {
    try {
      final url = Uri.parse('${ApiUrl.baseBackendUrl}/cart');
      final headers = {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      };

      print('Fetching cart from: $url');
      print('Token: ${token.substring(0, 20)}...');

      final response = await http.get(url, headers: headers);
      final data = json.decode(response.body);

      print('Cart Response Status: ${response.statusCode}');
      print('Cart Response Data: $data');

      if (response.statusCode == 200) {
        if (data['success'] == true) {
          final cart = Cart.fromJson(data['cart']);
          return ApiResponse(
            success: true,
            data: {'cart': cart},
          );
        } else {
          return ApiResponse(
            success: false,
            error: data['message'] ?? 'Failed to get cart',
          );
        }
      } else {
        return ApiResponse(
          success: false,
          error: data['error'] ?? data['message'] ?? 'Failed to fetch cart',
        );
      }
    } catch (e) {
      print('Get Cart Error: $e');
      return ApiResponse(
        success: false,
        error: 'Network error: ${e.toString()}',
      );
    }
  }

  Future<ApiResponse> addToCart({
    required String token,
    required String frameId,
    int quantity = 1,
  }) async {
    try {
      final url = Uri.parse('${ApiUrl.baseBackendUrl}/cart/add');
      final headers = {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      };

      final body = {
        'frameId': frameId,
        'quantity': quantity,
      };

      print('Adding to cart: ${json.encode(body)}');

      final response = await http.post(
        url,
        headers: headers,
        body: json.encode(body),
      );

      final data = json.decode(response.body);

      print('Add to Cart Response: ${response.statusCode}');
      print('Response Data: $data');

      if (response.statusCode == 200) {
        if (data['success'] == true) {
          return ApiResponse(
            success: true,
            data: data,
          );
        } else {
          return ApiResponse(
            success: false,
            error: data['message'] ?? 'Failed to add to cart',
          );
        }
      } else {
        return ApiResponse(
          success: false,
          error: data['message'] ?? data['error'] ?? 'Failed to add to cart',
        );
      }
    } catch (e) {
      print('Add to Cart Error: $e');
      return ApiResponse(
        success: false,
        error: 'Network error: ${e.toString()}',
      );
    }
  }

  Future<ApiResponse> updateCartItem({
    required String token,
    required String itemId,
    required int quantity,
  }) async {
    try {
      final url = Uri.parse('${ApiUrl.baseBackendUrl}/cart/item/$itemId');
      final headers = {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      };

      final body = {
        'quantity': quantity,
      };

      print('Updating cart item: ${json.encode(body)}');

      final response = await http.put(
        url,
        headers: headers,
        body: json.encode(body),
      );

      final data = json.decode(response.body);

      print('Update Cart Item Response: ${response.statusCode}');
      print('Response Data: $data');

      if (response.statusCode == 200) {
        if (data['success'] == true) {
          return ApiResponse(
            success: true,
            data: data,
          );
        } else {
          return ApiResponse(
            success: false,
            error: data['message'] ?? 'Failed to update cart item',
          );
        }
      } else {
        return ApiResponse(
          success: false,
          error: data['message'] ?? data['error'] ?? 'Failed to update cart item',
        );
      }
    } catch (e) {
      print('Update Cart Item Error: $e');
      return ApiResponse(
        success: false,
        error: 'Network error: ${e.toString()}',
      );
    }
  }

  Future<ApiResponse> removeCartItem({
    required String token,
    required String itemId,
  }) async {
    try {
      final url = Uri.parse('${ApiUrl.baseBackendUrl}/cart/item/$itemId');
      final headers = {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      };

      print('Removing cart item: $itemId');

      final response = await http.delete(url, headers: headers);
      final data = json.decode(response.body);

      print('Remove Cart Item Response: ${response.statusCode}');
      print('Response Data: $data');

      if (response.statusCode == 200) {
        if (data['success'] == true) {
          return ApiResponse(
            success: true,
            data: data,
          );
        } else {
          return ApiResponse(
            success: false,
            error: data['message'] ?? 'Failed to remove item',
          );
        }
      } else {
        return ApiResponse(
          success: false,
          error: data['message'] ?? data['error'] ?? 'Failed to remove item',
        );
      }
    } catch (e) {
      print('Remove Cart Item Error: $e');
      return ApiResponse(
        success: false,
        error: 'Network error: ${e.toString()}',
      );
    }
  }

  Future<ApiResponse> clearCart(String token) async {
    try {
      final url = Uri.parse('${ApiUrl.baseBackendUrl}/cart/clear');
      final headers = {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      };

      print('Clearing cart');

      final response = await http.delete(url, headers: headers);
      final data = json.decode(response.body);

      print('Clear Cart Response: ${response.statusCode}');
      print('Response Data: $data');

      if (response.statusCode == 200) {
        if (data['success'] == true) {
          return ApiResponse(
            success: true,
            data: data,
          );
        } else {
          return ApiResponse(
            success: false,
            error: data['message'] ?? 'Failed to clear cart',
          );
        }
      } else {
        return ApiResponse(
          success: false,
          error: data['message'] ?? data['error'] ?? 'Failed to clear cart',
        );
      }
    } catch (e) {
      print('Clear Cart Error: $e');
      return ApiResponse(
        success: false,
        error: 'Network error: ${e.toString()}',
      );
    }
  }
}