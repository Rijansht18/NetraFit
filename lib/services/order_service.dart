// services/order_service.dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../core/config/api_config.dart';
import '../models/api_response.dart';
import '../models/order_model.dart';

class OrderService {
  // services/order_service.dart - Fix the getAllOrders method
  Future<ApiResponse> getAllOrders({
    String? status,
    String? paymentStatus,
    String? token,
  }) async {
    try {
      final url = Uri.parse('${ApiUrl.baseBackendUrl}/order/allOrders');
      final headers = {
        'Content-Type': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      };

      final response = await http.get(url, headers: headers);
      final data = json.decode(response.body);

      if (response.statusCode == 200) {
        // Handle different response structures
        List<Order> orders = [];

        if (data['orders'] != null && data['orders'] is List) {
          orders = (data['orders'] as List).map((order) => Order.fromJson(order)).toList();
        } else if (data['data'] != null && data['data'] is List) {
          orders = (data['data'] as List).map((order) => Order.fromJson(order)).toList();
        } else if (data is List) {
          orders = data.map((order) => Order.fromJson(order)).toList();
        }

        // Filter by status if provided
        List<Order> filteredOrders = orders;
        if (status != null && status.isNotEmpty) {
          filteredOrders = orders.where((order) => order.orderStatus.toLowerCase() == status.toLowerCase()).toList();
        }

        // Filter by payment status if provided
        if (paymentStatus != null && paymentStatus.isNotEmpty) {
          filteredOrders = filteredOrders.where((order) => order.paymentStatus.toLowerCase() == paymentStatus.toLowerCase()).toList();
        }

        return ApiResponse(
          success: true,
          data: {'orders': filteredOrders},
        );
      } else {
        return ApiResponse(
          success: false,
          error: data['error'] ?? 'Failed to fetch orders',
        );
      }
    } catch (e) {
      return ApiResponse(
        success: false,
        error: 'Network error: $e',
      );
    }
  }

  // services/order_service.dart - Fix updateOrderStatus method
  Future<ApiResponse> updateOrderStatus({
    required String orderId,
    required String orderStatus,
    String? trackingNumber,
    required String token,
  }) async {
    try {
      final url = Uri.parse('${ApiUrl.baseBackendUrl}/order/$orderId/status');
      final headers = {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      };

      final body = {
        'orderStatus': orderStatus,
        if (trackingNumber != null && trackingNumber.isNotEmpty) 'trackingNumber': trackingNumber,
      };

      final response = await http.put(
        url,
        headers: headers,
        body: json.encode(body),
      );

      final data = json.decode(response.body);

      print('Update Order Status Response: ${response.statusCode}');
      print('Response Data: $data');

      if (response.statusCode == 200) {
        // Handle different response structures
        Order? updatedOrder;

        if (data['order'] != null) {
          updatedOrder = Order.fromJson(data['order']);
        } else if (data['data'] != null) {
          updatedOrder = Order.fromJson(data['data']);
        } else if (data is Map<String, dynamic>) {
          updatedOrder = Order.fromJson(data);
        }

        return ApiResponse(
          success: true,
          // message: data['message'] ?? 'Order status updated successfully',
          data: {'order': updatedOrder},
        );
      } else {
        return ApiResponse(
          success: false,
          error: data['error'] ?? data['message'] ?? 'Failed to update order status',
        );
      }
    } catch (e) {
      print('Update Order Status Error: $e');
      return ApiResponse(
        success: false,
        error: 'Network error: $e',
      );
    }
  }

// Also fix getOrderById method
  Future<ApiResponse> getOrderById(String orderId, String token) async {
    try {
      final url = Uri.parse('${ApiUrl.baseBackendUrl}/order/$orderId');
      final headers = {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      };

      final response = await http.get(url, headers: headers);
      final data = json.decode(response.body);

      print('Get Order By ID Response: ${response.statusCode}');
      print('Response Data: $data');

      if (response.statusCode == 200) {
        Order? order;

        if (data['order'] != null) {
          order = Order.fromJson(data['order']);
        } else if (data['data'] != null) {
          order = Order.fromJson(data['data']);
        } else if (data is Map<String, dynamic>) {
          order = Order.fromJson(data);
        }

        return ApiResponse(
          success: true,
          // message: data['message'] ?? 'Order fetched successfully',
          data: {'order': order},
        );
      } else {
        return ApiResponse(
          success: false,
          error: data['error'] ?? data['message'] ?? 'Failed to fetch order',
        );
      }
    } catch (e) {
      print('Get Order By ID Error: $e');
      return ApiResponse(
        success: false,
        error: 'Network error: $e',
      );
    }
  }

  Future<ApiResponse> updatePaymentStatus({
    required String orderId,
    required String paymentStatus,
    required String token,
  }) async {
    try {
      final url = Uri.parse('${ApiUrl.baseBackendUrl}/order/$orderId/payment');
      final headers = {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      };

      final body = {
        'paymentStatus': paymentStatus,
      };

      final response = await http.put(
        url,
        headers: headers,
        body: json.encode(body),
      );

      final data = json.decode(response.body);

      if (response.statusCode == 200) {
        return ApiResponse(
          success: true,
          data: {'order': Order.fromJson(data['order'])},
        );
      } else {
        return ApiResponse(
          success: false,
          error: data['error'] ?? 'Failed to update payment status',
        );
      }
    } catch (e) {
      return ApiResponse(
        success: false,
        error: 'Network error: $e',
      );
    }
  }

  Future<ApiResponse> cancelOrder(String orderId, String token) async {
    try {
      final url = Uri.parse('${ApiUrl.baseBackendUrl}/order/$orderId/cancel');
      final headers = {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      };

      final response = await http.put(url, headers: headers);
      final data = json.decode(response.body);

      if (response.statusCode == 200) {
        return ApiResponse(
          success: true,
          data: {'order': Order.fromJson(data['order'])},
        );
      } else {
        return ApiResponse(
          success: false,
          error: data['error'] ?? 'Failed to cancel order',
        );
      }
    } catch (e) {
      return ApiResponse(
        success: false,
        error: 'Network error: $e',
      );
    }
  }

  // Get order statistics for dashboard
  Future<Map<String, dynamic>> getOrderStatistics(String token) async {
    try {
      final response = await getAllOrders(token: token);

      if (response.success == true) {
        final orders = (response.data?['orders'] as List<Order>?) ?? [];

        final totalOrders = orders.length;
        final pendingOrders = orders.where((order) => order.orderStatus.toLowerCase() == 'pending').length;
        final processingOrders = orders.where((order) => order.orderStatus.toLowerCase() == 'processing').length;
        final shippedOrders = orders.where((order) => order.orderStatus.toLowerCase() == 'shipped').length;
        final deliveredOrders = orders.where((order) => order.orderStatus.toLowerCase() == 'delivered').length;
        final cancelledOrders = orders.where((order) => order.orderStatus.toLowerCase() == 'cancelled').length;

        final totalRevenue = orders
            .where((order) => order.orderStatus.toLowerCase() != 'cancelled')
            .fold(0.0, (sum, order) => sum + order.totalAmount);

        return {
          'totalOrders': totalOrders,
          'pendingOrders': pendingOrders,
          'processingOrders': processingOrders,
          'shippedOrders': shippedOrders,
          'deliveredOrders': deliveredOrders,
          'cancelledOrders': cancelledOrders,
          'totalRevenue': totalRevenue,
        };
      }

      return {
        'totalOrders': 0,
        'pendingOrders': 0,
        'processingOrders': 0,
        'shippedOrders': 0,
        'deliveredOrders': 0,
        'cancelledOrders': 0,
        'totalRevenue': 0.0,
      };
    } catch (e) {
      return {
        'totalOrders': 0,
        'pendingOrders': 0,
        'processingOrders': 0,
        'shippedOrders': 0,
        'deliveredOrders': 0,
        'cancelledOrders': 0,
        'totalRevenue': 0.0,
      };
    }
  }
}