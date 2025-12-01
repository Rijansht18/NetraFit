// models/order_model.dart
import 'dart:convert';
import 'dart:ui';
import 'package:flutter/material.dart';

import '../core/config/api_config.dart';

class Order {
  String? id;
  String? orderNumber;
  UserOrder? user;
  List<OrderItem> items;
  ShippingAddress shippingAddress;
  double totalAmount;
  String paymentMethod;
  String paymentStatus;
  String orderStatus;
  String? trackingNumber;
  String? notes;
  DateTime createdAt;
  DateTime updatedAt;

  Order({
    this.id,
    this.orderNumber,
    this.user,
    required this.items,
    required this.shippingAddress,
    required this.totalAmount,
    required this.paymentMethod,
    required this.paymentStatus,
    required this.orderStatus,
    this.trackingNumber,
    this.notes,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Order.fromJson(Map<String, dynamic> json) {
    // Safely parse items - this is where the error occurs
    List<OrderItem> items = [];
    if (json['items'] != null && json['items'] is List) {
      items = (json['items'] as List).map((item) => OrderItem.fromJson(item)).toList();
    } else {
      print('Warning: items is null or not a List in Order.fromJson');
      print('JSON data: ${json.toString()}');
    }

    // Safely parse user
    UserOrder? user;
    if (json['user'] != null && json['user'] is Map) {
      user = UserOrder.fromJson(json['user']);
    }

    // Safely parse dates
    DateTime createdAt;
    try {
      createdAt = DateTime.parse(json['createdAt'] ?? DateTime.now().toIso8601String());
    } catch (e) {
      print('Error parsing createdAt: $e');
      createdAt = DateTime.now();
    }

    DateTime updatedAt;
    try {
      updatedAt = DateTime.parse(json['updatedAt'] ?? DateTime.now().toIso8601String());
    } catch (e) {
      print('Error parsing updatedAt: $e');
      updatedAt = DateTime.now();
    }

    // Safely parse total amount
    double totalAmount = 0.0;
    if (json['totalAmount'] != null) {
      if (json['totalAmount'] is int) {
        totalAmount = (json['totalAmount'] as int).toDouble();
      } else if (json['totalAmount'] is double) {
        totalAmount = json['totalAmount'];
      } else if (json['totalAmount'] is String) {
        totalAmount = double.tryParse(json['totalAmount']) ?? 0.0;
      }
    }

    return Order(
      id: json['_id'],
      orderNumber: json['orderNumber'],
      user: user,
      items: items,
      shippingAddress: ShippingAddress.fromJson(json['shippingAddress'] ?? {}),
      totalAmount: totalAmount,
      paymentMethod: json['paymentMethod'] ?? 'cash-on-delivery',
      paymentStatus: json['paymentStatus'] ?? 'pending',
      orderStatus: json['orderStatus'] ?? 'pending',
      trackingNumber: json['trackingNumber'],
      notes: json['notes'],
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      '_id': id,
      'orderNumber': orderNumber,
      'user': user?.toJson(),
      'items': items.map((item) => item.toJson()).toList(),
      'shippingAddress': shippingAddress.toJson(),
      'totalAmount': totalAmount,
      'paymentMethod': paymentMethod,
      'paymentStatus': paymentStatus,
      'orderStatus': orderStatus,
      'trackingNumber': trackingNumber,
      'notes': notes,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  // Get next possible statuses (flow-based)
  List<String> getNextStatuses() {
    switch (orderStatus.toLowerCase()) {
      case 'pending':
        return ['processing', 'cancelled'];
      case 'processing':
        return ['shipped', 'cancelled'];
      case 'shipped':
        return ['delivered'];
      case 'delivered':
        return [];
      case 'cancelled':
        return [];
      default:
        return [];
    }
  }

  String getStatusDisplay() {
    switch (orderStatus.toLowerCase()) {
      case 'pending':
        return 'Pending';
      case 'processing':
        return 'Processing';
      case 'shipped':
        return 'Shipped';
      case 'delivered':
        return 'Delivered';
      case 'cancelled':
        return 'Cancelled';
      default:
        return orderStatus;
    }
  }

  Color getStatusColor() {
    switch (orderStatus.toLowerCase()) {
      case 'pending':
        return Colors.orange;
      case 'processing':
        return Colors.blue;
      case 'shipped':
        return Colors.purple;
      case 'delivered':
        return Colors.green;
      case 'cancelled':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  IconData getStatusIcon() {
    switch (orderStatus.toLowerCase()) {
      case 'pending':
        return Icons.pending;
      case 'processing':
        return Icons.settings;
      case 'shipped':
        return Icons.local_shipping;
      case 'delivered':
        return Icons.check_circle;
      case 'cancelled':
        return Icons.cancel;
      default:
        return Icons.question_mark;
    }
  }

  String getPaymentStatusDisplay() {
    switch (paymentStatus.toLowerCase()) {
      case 'pending':
        return 'Pending';
      case 'paid':
        return 'Paid';
      case 'failed':
        return 'Failed';
      default:
        return paymentStatus;
    }
  }

  Color getPaymentStatusColor() {
    switch (paymentStatus.toLowerCase()) {
      case 'pending':
        return Colors.orange;
      case 'paid':
        return Colors.green;
      case 'failed':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }
}

class UserOrder {
  String? id;
  String? username;
  String? fullname;
  String? email;
  String? mobile;

  UserOrder({
    this.id,
    this.username,
    this.fullname,
    this.email,
    this.mobile,
  });

  factory UserOrder.fromJson(Map<String, dynamic> json) {
    return UserOrder(
      id: json['_id'],
      username: json['username'],
      fullname: json['fullname'],
      email: json['email'],
      mobile: json['mobile'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      '_id': id,
      'username': username,
      'fullname': fullname,
      'email': email,
      'mobile': mobile,
    };
  }
}

class OrderItem {
  String? id;
  String frame;
  Frame? frameDetails;
  int quantity;
  double price;
  double subtotal;

  OrderItem({
    this.id,
    required this.frame,
    this.frameDetails,
    required this.quantity,
    required this.price,
    required this.subtotal,
  });

  factory OrderItem.fromJson(Map<String, dynamic> json) {
    // Safely parse frame details
    Frame? frameDetails;
    if (json['frame'] != null && json['frame'] is Map) {
      frameDetails = Frame.fromJson(json['frame']);
    }

    return OrderItem(
      id: json['_id'],
      frame: json['frame'] is String ? json['frame'] : (json['frame']?['_id'] ?? ''),
      frameDetails: frameDetails,
      quantity: json['quantity'] ?? 1,
      price: (json['price'] is int)
          ? (json['price'] as int).toDouble()
          : json['price']?.toDouble() ?? 0.0,
      subtotal: (json['subtotal'] is int)
          ? (json['subtotal'] as int).toDouble()
          : json['subtotal']?.toDouble() ?? 0.0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      '_id': id,
      'frame': frame,
      'quantity': quantity,
      'price': price,
      'subtotal': subtotal,
    };
  }
}

class ShippingAddress {
  String fullName;
  String phone;
  String address;

  ShippingAddress({
    required this.fullName,
    required this.phone,
    required this.address,
  });

  factory ShippingAddress.fromJson(Map<String, dynamic> json) {
    return ShippingAddress(
      fullName: json['fullName'] ?? 'Unknown',
      phone: json['phone'] ?? 'Unknown',
      address: json['address'] ?? 'Unknown',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'fullName': fullName,
      'phone': phone,
      'address': address,
    };
  }

  String getFormattedAddress() {
    return address;
  }
}

class Frame {
  String? id;
  String name;
  String? brand;
  String? image;
  List<String> imageUrls;
  double price;
  Map<String, dynamic>? otherProperties;

  Frame({
    this.id,
    required this.name,
    this.brand,
    this.image,
    this.imageUrls = const [],
    required this.price,
    this.otherProperties,
  });

  factory Frame.fromJson(Map<String, dynamic> json) {
    // Extract images safely
    List<String> imageUrls = [];

    if (json['images'] != null && json['images'] is List) {
      final images = json['images'] as List;
      for (var img in images) {
        if (img is String) {
          imageUrls.add(img);
        } else if (img is Map && img['filename'] != null) {
          imageUrls.add(img['filename'] as String);
        }
      }
    }

    // Get the first image URL
    String? image;
    if (imageUrls.isNotEmpty) {
      image = imageUrls.first;
    } else if (json['image'] != null && json['image'] is String) {
      image = json['image'] as String;
    }

    // Get price safely
    double price = 0.0;
    if (json['price'] != null) {
      if (json['price'] is int) {
        price = (json['price'] as int).toDouble();
      } else if (json['price'] is double) {
        price = json['price'];
      } else if (json['price'] is String) {
        price = double.tryParse(json['price']) ?? 0.0;
      }
    }

    return Frame(
      id: json['_id'],
      name: json['name'] ?? 'Unknown Frame',
      brand: json['brand'],
      image: image,
      imageUrls: imageUrls,
      price: price,
      otherProperties: json,
    );
  }

  // Helper method to get image URL by index
  String? getImageUrl(int index) {
    if (id == null) return null;

    // Check if we have images in otherProperties
    if (otherProperties != null &&
        otherProperties!['images'] is List &&
        (otherProperties!['images'] as List).isNotEmpty) {

      final images = otherProperties!['images'] as List;
      if (index >= 0 && index < images.length) {
        final imageData = images[index];
        if (imageData is Map && imageData['filename'] != null) {
          // If we have filename, construct URL
          return '${ApiUrl.baseBackendUrl}/uploads/${imageData['filename']}';
        } else if (imageData is String) {
          return '${ApiUrl.baseBackendUrl}/uploads/$imageData';
        }
      }
    }

    // Fallback to the new API endpoint format
    return '${ApiUrl.baseBackendUrl}/frames/images/$id/$index';
  }

  // Get the first image URL
  String? get firstImageUrl => getImageUrl(0);
}