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
  final DateTime? updatedAt;
  final DateTime? passwordChangedAt;
  final String? resetCode;
  final DateTime? resetCodeExpires;
  final DateTime? lastResetRequest;
  final int? resetAttempts;
  final DateTime? accountSuspendedUntil;

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
    this.updatedAt,
    this.passwordChangedAt,
    this.resetCode,
    this.resetCodeExpires,
    this.lastResetRequest,
    this.resetAttempts,
    this.accountSuspendedUntil,
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
      updatedAt: json['updatedAt'] != null ? DateTime.parse(json['updatedAt']) : null,
      passwordChangedAt: json['passwordChangedAt'] != null ? DateTime.parse(json['passwordChangedAt']) : null,
      resetCode: json['resetCode'],
      resetCodeExpires: json['resetCodeExpires'] != null ? DateTime.parse(json['resetCodeExpires']) : null,
      lastResetRequest: json['lastResetRequest'] != null ? DateTime.parse(json['lastResetRequest']) : null,
      resetAttempts: json['resetAttempts'],
      accountSuspendedUntil: json['accountSuspendedUntil'] != null ? DateTime.parse(json['accountSuspendedUntil']) : null,
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

  // Status helpers
  bool get isActive => status != 'SUSPENDED';
  bool get isSuspended => status == 'SUSPENDED';
  bool get isAccountSuspended => accountSuspendedUntil != null && accountSuspendedUntil!.isAfter(DateTime.now());

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
      'updatedAt': updatedAt?.toIso8601String(),
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
      updatedAt: json['updatedAt'] != null ? DateTime.parse(json['updatedAt']) : null,
    );
  }
}