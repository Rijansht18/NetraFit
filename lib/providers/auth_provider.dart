import 'dart:convert';
import 'package:flutter/foundation.dart';
import '../models/user_model.dart';
import '../services/auth_service.dart';
import '../services/storage_service.dart';

class AuthProvider with ChangeNotifier {
  UserModel? _user;
  String? _token;
  bool _isLoading = false;
  bool _rememberMe = false;

  UserModel? get user => _user;
  String? get token => _token;
  bool get isLoading => _isLoading;
  bool get isLoggedIn => _token != null && _user != null;
  bool get isAdmin => _user?.isAdmin ?? false;
  bool get isCustomer => _user?.isCustomer ?? false;
  bool get rememberMe => _rememberMe;

  final AuthService _authService = AuthService();
  final StorageService _storageService = StorageService();

  AuthProvider() {
    _loadStoredAuth();
  }

  // ---------------------- JWT TOKEN CHECK ----------------------
  bool _isTokenExpired(String token) {
    try {
      final parts = token.split('.');
      if (parts.length != 3) return true;

      final payload = json.decode(
        utf8.decode(
          base64Url.decode(base64Url.normalize(parts[1])),
        ),
      );

      final exp = payload["exp"];
      if (exp == null) return true;

      final expiryDate = DateTime.fromMillisecondsSinceEpoch(exp * 1000);
      return DateTime.now().isAfter(expiryDate);

    } catch (e) {
      return true;
    }
  }

  // ---------------------- LOAD STORED AUTH ----------------------
  Future<void> _loadStoredAuth() async {
    _isLoading = true;
    notifyListeners();

    try {
      _rememberMe = await _storageService.getRememberMe();

      if (_rememberMe) {
        _token = await _storageService.getToken();
        _user = await _storageService.getUser();

        if (_token != null && _user != null) {
          // CHECK TOKEN EXPIRY
          if (_isTokenExpired(_token!)) {
            await logout();
            return;
          }

          print("Auto-login loaded: ${_user?.username} (${_user?.role})");
        } else {
          await logout();
        }
      }

    } catch (e) {
      await logout();
    }

    _isLoading = false;
    notifyListeners();
  }

  // ---------------------- LOGIN ----------------------
  Future<bool> login(String identifier, String password, bool rememberMe) async {
    _isLoading = true;
    notifyListeners();

    try {
      final loginResponse = await _authService.login(identifier, password);

      if (loginResponse.success == true && loginResponse.data?["token"] != null) {
        _token = loginResponse.data!["token"];
        _rememberMe = rememberMe;

        // CHECK TOKEN EXPIRY BEFORE CONTINUING
        if (_isTokenExpired(_token!)) {
          await logout();
          return false;
        }

        final profileResponse = await _authService.getUserProfile(_token!);

        if (profileResponse.success == true) {
          _user = UserModel.fromJson(
            profileResponse.data?["user"] ?? profileResponse.data ?? {},
          );

          if (rememberMe) {
            await _storageService.setToken(_token!);
            await _storageService.setUser(_user!);
            await _storageService.setRememberMe(true);
          } else {
            await _storageService.clearAuthData();
            await _storageService.setToken(_token!);
            await _storageService.setUser(_user!);
            await _storageService.setRememberMe(false);
          }

          print("Login successful: ${_user?.username}");
          _isLoading = false;
          notifyListeners();
          return true;
        }
      }

      _isLoading = false;
      notifyListeners();
      return false;

    } catch (e) {
      print("Login error: $e");
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  // ---------------------- LOGOUT ----------------------
  Future<void> logout() async {
    _user = null;
    _token = null;
    _rememberMe = false;

    await _storageService.clearAuthData();
    print("User logged out");

    notifyListeners();
  }

  // ---------------------- HELPER FUNCTIONS ----------------------
  void setRememberMe(bool value) {
    _rememberMe = value;
    _storageService.setRememberMe(value);
    notifyListeners();
  }

  Future<void> updateUser(UserModel user) async {
    _user = user;
    if (_rememberMe) {
      await _storageService.setUser(user);
    }
    notifyListeners();
  }

  Future<void> refreshToken(String newToken) async {
    _token = newToken;
    if (_rememberMe) {
      await _storageService.setToken(newToken);
    }
    notifyListeners();
  }

  bool get hasValidToken =>
      _token != null && _token!.isNotEmpty && !_isTokenExpired(_token!);

  void setAuthState(String token, UserModel user, bool rememberMe) {
    _token = token;
    _user = user;
    _rememberMe = rememberMe;
    notifyListeners();
  }
}
