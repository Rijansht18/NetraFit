import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/api_response.dart';
import '../models/order_model.dart';
import '../core/config/api_config.dart';

class CreateOrderService {
  // Create a new order
  Future<ApiResponse> createOrder({
    required String token,
    required List<Map<String, dynamic>> items,
    required ShippingAddress shippingAddress,
    required String paymentMethod,
    String? notes,
  }) async {
    try {
      final url = Uri.parse('${ApiUrl.baseBackendUrl}/order/createOrder');
      final headers = {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      };

      final body = {
        'items': items,
        'shippingAddress': shippingAddress.toJson(),
        'paymentMethod': paymentMethod,
        if (notes != null && notes.isNotEmpty) 'notes': notes,
      };

      print('Creating order with data: ${json.encode(body)}');

      final response = await http.post(
        url,
        headers: headers,
        body: json.encode(body),
      ).timeout(const Duration(seconds: 30));

      final data = json.decode(response.body);

      print('Order Creation Response: ${response.statusCode}');
      print('Response Data: $data');

      if (response.statusCode == 201 || response.statusCode == 200) {
        return ApiResponse(
          success: true,
          data: data,
        );
      } else {
        return ApiResponse(
          success: false,
          error: data['error'] ?? 'Failed to create order',
        );
      }
    } catch (e) {
      print('Create Order Error: $e');
      return ApiResponse(
        success: false,
        error: 'Network error: ${e.toString()}',
      );
    }
  }

  // Create order from a single frame
  Future<ApiResponse> createOrderFromFrame({
    required String token,
    required String frameId,
    required int quantity,
    required ShippingAddress shippingAddress,
    required String paymentMethod,
    String? notes,
  }) async {
    return createOrder(
      token: token,
      items: [
        {
          'frame': frameId,
          'quantity': quantity,
        }
      ],
      shippingAddress: shippingAddress,
      paymentMethod: paymentMethod,
      notes: notes,
    );
  }
}