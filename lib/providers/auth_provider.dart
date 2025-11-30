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

  Future<void> _loadStoredAuth() async {
    _rememberMe = await _storageService.getRememberMe();
    if (_rememberMe) {
      _token = await _storageService.getToken();
      _user = await _storageService.getUser();
      if (_token != null && _user != null) {
        print('Auto-login loaded: ${_user?.username} (${_user?.role})');
      }
      notifyListeners();
    }
  }

  Future<bool> login(String identifier, String password, bool rememberMe) async {
    _isLoading = true;
    notifyListeners();

    try {
      // Step 1: Login to get token
      final loginResponse = await _authService.login(identifier, password);

      if (loginResponse.success == true && loginResponse.data?['token'] != null) {
        _token = loginResponse.data!['token'];
        _rememberMe = rememberMe;

        // Step 2: Get user profile with the token
        final profileResponse = await _authService.getUserProfile(_token!);

        if (profileResponse.success == true) {
          // Create user model from profile data
          _user = UserModel.fromJson(profileResponse.data?['user'] ?? profileResponse.data ?? {});

          // Store auth data if remember me is enabled
          if (rememberMe) {
            await _storageService.setToken(_token!);
            await _storageService.setUser(_user!);
            await _storageService.setRememberMe(true);
          }

          print('Login successful: ${_user?.username} (${_user?.role})');
          _isLoading = false;
          notifyListeners();
          return true;
        } else {
          print('Failed to get user profile: ${profileResponse.error}');
        }
      } else {
        print('Login failed: ${loginResponse.error}');
      }

      _isLoading = false;
      notifyListeners();
      return false;

    } catch (e) {
      print('Login error: $e');
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<void> logout() async {
    _user = null;
    _token = null;
    _rememberMe = false;

    // Clear stored data
    await _storageService.clearAuthData();

    print('User logged out');
    notifyListeners();
  }

  void setRememberMe(bool value) {
    _rememberMe = value;
    _storageService.setRememberMe(value);
    print('Remember me set to: $value');
    notifyListeners();
  }
}