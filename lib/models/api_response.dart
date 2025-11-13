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