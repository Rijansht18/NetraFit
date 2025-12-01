// lib/models/frame_model.dart

import '../core/config/api_config.dart';

class Frame {
  final String id;
  final String filename; // Added filename property
  final String name;
  final String brand;
  final String mainCategory;
  final String subCategory;
  final String type;
  final String shape;
  final double price;
  final int quantity;
  final List<String> colors;
  final String size;
  final String? description;
  final List<String> imageUrls;
  final String? overlayUrl;
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;

  // For displaying category names
  final String? mainCategoryName;
  final String? subCategoryName;

  Frame({
    required this.id,
    required this.filename,
    required this.name,
    required this.brand,
    required this.mainCategory,
    required this.subCategory,
    required this.type,
    required this.shape,
    required this.price,
    required this.quantity,
    required this.colors,
    required this.size,
    this.description,
    this.imageUrls = const [],
    this.overlayUrl,
    this.isActive = true,
    required this.createdAt,
    required this.updatedAt,
    this.mainCategoryName,
    this.subCategoryName,
  });

  factory Frame.fromJson(Map<String, dynamic> json) {
    final id = (json['_id'] ?? json['id'] ?? '').toString();
    final name = (json['name'] ?? '').toString();
    final filename = (json['filename'] != null && json['filename'].toString().isNotEmpty)
        ? json['filename'].toString()
        : _generateFilename(name, id);

    // price: attempt robust parsing from int, double or string
    double parsePrice(dynamic p) {
      if (p == null) return 0.0;
      if (p is double) return p;
      if (p is int) return p.toDouble();
      final parsed = double.tryParse(p.toString());
      return parsed ?? 0.0;
    }

    DateTime parseDateTime(dynamic d) {
      if (d == null) return DateTime.now();
      if (d is DateTime) return d;
      final parsed = DateTime.tryParse(d.toString());
      return parsed ?? DateTime.now();
    }

    return Frame(
      id: id,
      filename: filename,
      name: name,
      brand: (json['brand'] ?? '').toString(),
      mainCategory: json['mainCategory'] is String
          ? json['mainCategory'] as String
          : (json['mainCategory'] is Map ? (json['mainCategory']?['_id']?.toString() ?? '') : ''),
      subCategory: json['subCategory'] is String
          ? json['subCategory'] as String
          : (json['subCategory'] is Map ? (json['subCategory']?['_id']?.toString() ?? '') : ''),
      type: (json['type'] ?? '').toString(),
      shape: (json['shape'] ?? '').toString(),
      price: parsePrice(json['price']),
      quantity: (json['quantity'] is int) ? json['quantity'] as int : int.tryParse('${json['quantity']}') ?? 0,
      colors: List<String>.from((json['colors'] ?? []).map((c) => c?.toString() ?? '')),
      size: (json['size'] ?? '').toString(),
      description: json['description']?.toString(),
        imageUrls: _parseImageUrls(json, id),
        overlayUrl: (json['overlayImage'] is Map)
          ? (json['overlayImage']?['url']?.toString() ?? '${ApiUrl.baseBackendUrl}/frames/images/$id/overlay')
          : (json['overlay_url']?.toString() ?? '${ApiUrl.baseBackendUrl}/frames/images/$id/overlay'),
      isActive: json['isActive'] is bool ? json['isActive'] as bool : (json['isActive']?.toString().toLowerCase() == 'true'),
      createdAt: parseDateTime(json['createdAt']),
      updatedAt: parseDateTime(json['updatedAt']),
      mainCategoryName: (json['mainCategory'] is Map)
          ? (json['mainCategory']['name']?.toString())
          : null,

      subCategoryName: (json['subCategory'] is Map)
          ? (json['subCategory']['name']?.toString())
          : null,

    );
  }

  static List<String> _parseImageUrls(Map<String, dynamic> json, String id) {
    final images = json['images'];
    if (images == null) return <String>[];
    if (images is List) {
      final List<String> urls = [];
      for (var i = 0; i < images.length; i++) {
        final img = images[i];
        if (img == null) continue;
        if (img is String) {
          if (img.isNotEmpty) urls.add(img);
          continue;
        }
        if (img is Map) {
          final url = img['url']?.toString();
          urls.add(url?.isNotEmpty == true ? url! : '${ApiUrl.baseBackendUrl}/frames/images/$id/$i');
          continue;
        }
        final s = img.toString();
        if (s.isNotEmpty) urls.add(s);
      }
      return urls;
    }
    // if single string
    if (images is String) return [images];
    return <String>[];
  }

  static String _generateFilename(String name, String id) {
    if (name.isNotEmpty) {
      final sanitized = name.toLowerCase().replaceAll(RegExp(r'\s+'), '_').replaceAll(RegExp(r'[^\w\-]'), '');
      return '${sanitized}_$id';
    }
    return 'frame_$id';
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'brand': brand,
      'mainCategory': mainCategory,
      'subCategory': subCategory,
      'type': type,
      'shape': shape,
      'price': price,
      'quantity': quantity,
      'colors': colors,
      'size': size,
      'description': description,
      'isActive': isActive,
    };
  }
}
