class ApiResponse {
  final bool success;
  final String? error;
  final dynamic data;
  final int? statusCode;

  ApiResponse({
    required this.success,
    this.error,
    this.data,
    this.statusCode,
  });

  factory ApiResponse.fromJson(Map<String, dynamic> json) {
    return ApiResponse(
      success: json['success'] ?? false,
      error: json['error'],
      data: json['data'],
      statusCode: json['statusCode'],
    );
  }
}