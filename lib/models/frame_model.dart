// lib/models/frame_model.dart
import 'package:intl/intl.dart';

class Frame {
  final String id;
  final String filename;
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
    required this.imageUrls,
    this.overlayUrl,
    required this.isActive,
    required this.createdAt,
    required this.updatedAt,
    this.mainCategoryName,
    this.subCategoryName,
  });

  factory Frame.fromJson(Map<String, dynamic> json) {
    // Parse ID
    final id = (json['_id'] ?? json['id'] ?? '').toString();

    // Parse name and filename
    final name = (json['name'] ?? '').toString();
    final filename = (json['filename'] != null && json['filename'].toString().isNotEmpty)
        ? json['filename'].toString()
        : _generateFilename(name, id);

    // Parse price
    double parsePrice(dynamic p) {
      if (p == null) return 0.0;
      if (p is double) return p;
      if (p is int) return p.toDouble();
      final parsed = double.tryParse(p.toString());
      return parsed ?? 0.0;
    }

    // Parse quantity
    int parseQuantity(dynamic q) {
      if (q == null) return 0;
      if (q is int) return q;
      if (q is double) return q.toInt();
      final parsed = int.tryParse(q.toString());
      return parsed ?? 0;
    }

    // Parse date
    DateTime parseDateTime(dynamic d) {
      if (d == null) return DateTime.now();
      if (d is DateTime) return d;
      if (d is String) {
        // Try parsing ISO string
        final parsed = DateTime.tryParse(d);
        if (parsed != null) return parsed;

        // Try parsing from milliseconds
        final millis = int.tryParse(d);
        if (millis != null) {
          return DateTime.fromMillisecondsSinceEpoch(millis);
        }
      }
      if (d is int) {
        return DateTime.fromMillisecondsSinceEpoch(d);
      }
      return DateTime.now();
    }

    // Parse colors
    List<String> parseColors(dynamic c) {
      if (c == null) return [];
      if (c is List) {
        return c.map((item) => item?.toString() ?? '').where((color) => color.isNotEmpty).toList();
      }
      if (c is String) {
        return c.split(',').map((color) => color.trim()).where((color) => color.isNotEmpty).toList();
      }
      return [];
    }

    // Parse main category
    String parseMainCategory(dynamic mc) {
      if (mc == null) return '';
      if (mc is String) return mc;
      if (mc is Map) {
        return mc['_id']?.toString() ?? '';
      }
      return '';
    }

    // Parse sub category
    String parseSubCategory(dynamic sc) {
      if (sc == null) return '';
      if (sc is String) return sc;
      if (sc is Map) {
        return sc['_id']?.toString() ?? '';
      }
      return '';
    }

    // Parse category names
    String? parseMainCategoryName(dynamic mc) {
      if (mc is Map) {
        return mc['name']?.toString();
      }
      return null;
    }

    String? parseSubCategoryName(dynamic sc) {
      if (sc is Map) {
        return sc['name']?.toString();
      }
      return null;
    }

    // Parse image URLs
    List<String> parseImageUrls(Map<String, dynamic> json, String id) {
      final images = json['images'];
      final imageUrls = json['imageUrls'] ?? json['image_urls'];

      // First check imageUrls
      if (imageUrls != null) {
        if (imageUrls is List) {
          return List<String>.from(imageUrls.map((url) => url?.toString() ?? '').where((url) => url.isNotEmpty));
        }
        if (imageUrls is String && imageUrls.isNotEmpty) {
          return [imageUrls];
        }
      }

      // Then check images array
      if (images != null && images is List) {
        final List<String> urls = [];
        for (var i = 0; i < images.length; i++) {
          final img = images[i];
          if (img == null) continue;
          if (img is String && img.isNotEmpty) {
            urls.add(img);
          } else if (img is Map) {
            final url = img['url']?.toString() ?? img['data']?.toString();
            if (url != null && url.isNotEmpty) {
              urls.add(url);
            }
          }
        }
        return urls;
      }

      return [];
    }

    // Parse overlay URL
    String? parseOverlayUrl(Map<String, dynamic> json, String id) {
      final overlayImage = json['overlayImage'];
      final overlayUrl = json['overlayUrl'] ?? json['overlay_url'];

      if (overlayUrl != null && overlayUrl.toString().isNotEmpty) {
        return overlayUrl.toString();
      }

      if (overlayImage != null) {
        if (overlayImage is String && overlayImage.isNotEmpty) {
          return overlayImage;
        }
        if (overlayImage is Map) {
          final url = overlayImage['url']?.toString() ?? overlayImage['data']?.toString();
          if (url != null && url.isNotEmpty) {
            return url;
          }
        }
      }

      return null;
    }

    return Frame(
      id: id,
      filename: filename,
      name: name,
      brand: (json['brand'] ?? '').toString(),
      mainCategory: parseMainCategory(json['mainCategory']),
      subCategory: parseSubCategory(json['subCategory']),
      type: (json['type'] ?? '').toString(),
      shape: (json['shape'] ?? '').toString(),
      price: parsePrice(json['price']),
      quantity: parseQuantity(json['quantity']),
      colors: parseColors(json['colors']),
      size: (json['size'] ?? '').toString(),
      description: json['description']?.toString(),
      imageUrls: parseImageUrls(json, id),
      overlayUrl: parseOverlayUrl(json, id),
      isActive: json['isActive'] is bool ? json['isActive'] as bool : (json['isActive']?.toString().toLowerCase() == 'true'),
      createdAt: parseDateTime(json['createdAt']),
      updatedAt: parseDateTime(json['updatedAt']),
      mainCategoryName: parseMainCategoryName(json['mainCategory']),
      subCategoryName: parseSubCategoryName(json['subCategory']),
    );
  }

  static String _generateFilename(String name, String id) {
    if (name.isEmpty) return 'frame_$id';

    // Remove special characters, keep only alphanumeric and spaces
    final sanitized = name.replaceAll(RegExp(r'[^\w\s-]'), '').replaceAll(RegExp(r'\s+'), '_').toLowerCase();
    return '${sanitized}_$id';
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'filename': filename,
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
      'imageUrls': imageUrls,
      'overlayUrl': overlayUrl,
      'isActive': isActive,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  // Helper method to get display price
  String get displayPrice {
    return NumberFormat.currency(symbol: 'रु ', decimalDigits: 2).format(price);
  }

  // Helper method to check if frame has images
  bool get hasImages => imageUrls.isNotEmpty;

  // Helper method to get first image URL
  String? get firstImageUrl => hasImages ? imageUrls.first : null;
}