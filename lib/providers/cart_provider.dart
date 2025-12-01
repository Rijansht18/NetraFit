import 'package:flutter/foundation.dart';
import '../models/cart_model.dart';
import '../services/cart_service.dart';

class CartProvider with ChangeNotifier {
  Cart? _cart;
  bool _isLoading = false;
  String _errorMessage = '';

  Cart? get cart => _cart;
  bool get isLoading => _isLoading;
  String get errorMessage => _errorMessage;
  int get cartItemCount => _cart?.totalItems ?? 0;
  double get cartTotal => _cart?.totalPrice ?? 0.0;

  final CartService _cartService = CartService();

  Future<void> loadCart(String token) async {
    _isLoading = true;
    _errorMessage = '';
    notifyListeners();

    try {
      final response = await _cartService.getCart(token);

      if (response.success) {
        _cart = response.data?['cart'];
      } else {
        _errorMessage = response.error ?? 'Failed to load cart';
      }
    } catch (e) {
      _errorMessage = 'Error loading cart: $e';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> addToCart({
    required String token,
    required String frameId,
    int quantity = 1,
  }) async {
    _isLoading = true;
    notifyListeners();

    try {
      final response = await _cartService.addToCart(
        token: token,
        frameId: frameId,
        quantity: quantity,
      );

      if (response.success) {
        // Reload cart to get updated state
        await loadCart(token);
        return true;
      } else {
        _errorMessage = response.error ?? 'Failed to add to cart';
        return false;
      }
    } catch (e) {
      _errorMessage = 'Error adding to cart: $e';
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> updateCartItem({
    required String token,
    required String itemId,
    required int quantity,
  }) async {
    _isLoading = true;
    notifyListeners();

    try {
      final response = await _cartService.updateCartItem(
        token: token,
        itemId: itemId,
        quantity: quantity,
      );

      if (response.success) {
        // Update local cart item
        if (_cart != null) {
          final index = _cart!.items.indexWhere((item) => item.id == itemId);
          if (index != -1) {
            _cart!.items[index].quantity = quantity;
            _cart!.items[index].subtotal = _cart!.items[index].price * quantity;

            // Recalculate total
            _cart!.totalPrice = _cart!.items.fold(0.0, (sum, item) => sum + item.subtotal);
          }
        }
        return true;
      } else {
        _errorMessage = response.error ?? 'Failed to update cart item';
        return false;
      }
    } catch (e) {
      _errorMessage = 'Error updating cart item: $e';
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> removeCartItem({
    required String token,
    required String itemId,
  }) async {
    _isLoading = true;
    notifyListeners();

    try {
      final response = await _cartService.removeCartItem(
        token: token,
        itemId: itemId,
      );

      if (response.success) {
        // Remove item from local cart
        if (_cart != null) {
          _cart!.items.removeWhere((item) => item.id == itemId);

          // Recalculate total
          _cart!.totalPrice = _cart!.items.fold(0.0, (sum, item) => sum + item.subtotal);
          _cart!.itemCount = _cart!.items.length;
        }
        return true;
      } else {
        _errorMessage = response.error ?? 'Failed to remove item';
        return false;
      }
    } catch (e) {
      _errorMessage = 'Error removing cart item: $e';
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> clearCart(String token) async {
    _isLoading = true;
    notifyListeners();

    try {
      final response = await _cartService.clearCart(token);

      if (response.success) {
        _cart = null;
        return true;
      } else {
        _errorMessage = response.error ?? 'Failed to clear cart';
        return false;
      }
    } catch (e) {
      _errorMessage = 'Error clearing cart: $e';
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void clearError() {
    _errorMessage = '';
    notifyListeners();
  }
}