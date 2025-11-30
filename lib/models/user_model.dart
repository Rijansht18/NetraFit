class UserModel {
  final String? id;
  final String username;
  final String fullname;
  final String email;
  final String password;
  final String role;
  final String mobile;
  final String address;
  final String? status;
  final String? profilePhoto;
  final DateTime? createdAt;

  UserModel({
    this.id,
    required this.username,
    required this.fullname,
    required this.email,
    required this.password,
    this.role = 'CUSTOMER',
    required this.mobile,
    required this.address,
    this.status,
    this.profilePhoto,
    this.createdAt,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['_id'],
      username: json['username'],
      fullname: json['fullname'],
      email: json['email'],
      password: json['password'] ?? '',
      role: json['role'] ?? 'CUSTOMER',
      mobile: json['mobile'] ?? '',
      address: json['address'] ?? '',
      status: json['status'],
      profilePhoto: json['profilePhoto'],
      createdAt: json['createdAt'] != null ? DateTime.parse(json['createdAt']) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'username': username,
      'fullname': fullname,
      'email': email,
      'password': password,
      'role': role,
      'mobile': mobile,
      'address': address,
      'status': status,
      'profilePhoto': profilePhoto,
    };
  }

  Map<String, dynamic> toRegisterJson() {
    return {
      'username': username,
      'fullname': fullname,
      'email': email,
      'password': password,
      'mobile': mobile,
      'address': address,
    };
  }

  // Helper methods for role checking
  bool get isAdmin => role == 'ADMIN';
  bool get isCustomer => role == 'CUSTOMER';

  // Storage methods
  Map<String, dynamic> toStorageJson() {
    return {
      'id': id,
      'username': username,
      'fullname': fullname,
      'email': email,
      'role': role,
      'mobile': mobile,
      'address': address,
      'status': status,
      'profilePhoto': profilePhoto,
      'createdAt': createdAt?.toIso8601String(),
    };
  }

  factory UserModel.fromStorageJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id'],
      username: json['username'],
      fullname: json['fullname'],
      email: json['email'],
      password: '', // Don't store password
      role: json['role'] ?? 'CUSTOMER',
      mobile: json['mobile'] ?? '',
      address: json['address'] ?? '',
      status: json['status'],
      profilePhoto: json['profilePhoto'],
      createdAt: json['createdAt'] != null ? DateTime.parse(json['createdAt']) : null,
    );
  }
}