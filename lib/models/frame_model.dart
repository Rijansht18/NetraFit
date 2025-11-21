class Frame {
  final String filename;
  final String path;
  final String name;
  final String shape;

  Frame({
    required this.filename,
    required this.path,
    required this.name,
    required this.shape,
  });

  factory Frame.fromJson(Map<String, dynamic> json) {
    return Frame(
      filename: json['filename'] ?? '',
      path: json['path'] ?? '',
      name: json['name'] ?? '',
      shape: json['shape'] ?? 'Unknown',
    );
  }
}

class ApiResponse {
  final bool success;
  final String? error;
  final dynamic data;

  ApiResponse({
    required this.success,
    this.error,
    this.data,
  });

  factory ApiResponse.fromJson(Map<String, dynamic> json) {
    return ApiResponse(
      success: json['success'] ?? false,
      error: json['error'],
      data: json['data'],
    );
  }
}