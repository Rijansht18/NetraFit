import 'dart:convert';

class Cart {
  String? id;
  String? userId;
  double totalPrice;
  List<CartItem> items;
  int itemCount;
  DateTime createdAt;
  DateTime updatedAt;

  Cart({
    this.id,
    this.userId,
    required this.totalPrice,
    required this.items,
    required this.itemCount,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Cart.fromJson(Map<String, dynamic> json) {
    List<CartItem> items = [];
    if (json['items'] != null && json['items'] is List) {
      items = (json['items'] as List).map((item) => CartItem.fromJson(item)).toList();
    }

    return Cart(
      id: json['_id'],
      userId: json['user']?.toString() ?? json['userId']?.toString(),
      totalPrice: (json['totalPrice'] is int)
          ? (json['totalPrice'] as int).toDouble()
          : json['totalPrice']?.toDouble() ?? 0.0,
      items: items,
      itemCount: json['itemCount'] ?? items.length,
      createdAt: DateTime.parse(json['createdAt'] ?? DateTime.now().toIso8601String()),
      updatedAt: DateTime.parse(json['updatedAt'] ?? DateTime.now().toIso8601String()),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      '_id': id,
      'user': userId,
      'totalPrice': totalPrice,
      'items': items.map((item) => item.toJson()).toList(),
      'itemCount': itemCount,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  int get totalItems => items.fold(0, (sum, item) => sum + item.quantity);
}

class CartItem {
  String? id;
  String? cartId;
  FrameItem frame;
  int quantity;
  double price;
  double subtotal;
  DateTime createdAt;
  DateTime updatedAt;

  CartItem({
    this.id,
    this.cartId,
    required this.frame,
    required this.quantity,
    required this.price,
    required this.subtotal,
    required this.createdAt,
    required this.updatedAt,
  });

  factory CartItem.fromJson(Map<String, dynamic> json) {
    return CartItem(
      id: json['_id'],
      cartId: json['cart']?.toString(),
      frame: FrameItem.fromJson(json['frame'] ?? {}),
      quantity: json['quantity'] ?? 1,
      price: (json['price'] is int)
          ? (json['price'] as int).toDouble()
          : json['price']?.toDouble() ?? 0.0,
      subtotal: (json['subtotal'] is int)
          ? (json['subtotal'] as int).toDouble()
          : (json['price'] is int
          ? (json['price'] as int).toDouble() * (json['quantity'] ?? 1)
          : (json['price']?.toDouble() ?? 0.0) * (json['quantity'] ?? 1)),
      createdAt: DateTime.parse(json['createdAt'] ?? DateTime.now().toIso8601String()),
      updatedAt: DateTime.parse(json['updatedAt'] ?? DateTime.now().toIso8601String()),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      '_id': id,
      'cart': cartId,
      'frame': frame.toJson(),
      'quantity': quantity,
      'price': price,
      'subtotal': subtotal,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }
}

class FrameItem {
  String? id;
  String name;
  double price;

  FrameItem({
    this.id,
    required this.name,
    required this.price,
  });

  factory FrameItem.fromJson(Map<String, dynamic> json) {
    return FrameItem(
      id: json['_id'],
      name: json['name'] ?? 'Unknown Frame',
      price: (json['price'] is int)
          ? (json['price'] as int).toDouble()
          : json['price']?.toDouble() ?? 0.0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      '_id': id,
      'name': name,
      'price': price,
    };
  }
}