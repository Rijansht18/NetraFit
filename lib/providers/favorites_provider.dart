// providers/favorites_provider.dart
import 'package:flutter/foundation.dart';
import 'package:netrafit/services/favorites_service.dart';

class FavoritesProvider with ChangeNotifier {
  final FavoritesService _favoritesService = FavoritesService();
  List<Map<String, dynamic>> _favorites = [];
  bool _isLoading = false;

  List<Map<String, dynamic>> get favorites => _favorites;
  bool get isLoading => _isLoading;
  int get favoritesCount => _favorites.length;

  // Update getFavoriteByFrameId method
  Map<String, dynamic>? getFavoriteByFrameId(String frameId) {
    try {
      print('Looking for favorite with frameId: $frameId');
      print('Total favorites in list: ${_favorites.length}');

      for (var fav in _favorites) {
        print('Checking favorite: ${fav['_id']}');
        print('Frame in favorite: ${fav['frame']?['_id']}');
        print('FrameId in favorite: ${fav['frameId']}');

        if ((fav['frame']?['_id'] == frameId) || (fav['frameId'] == frameId)) {
          print('Found matching favorite!');
          return fav;
        }
      }

      print('No matching favorite found');
      return null;
    } catch (e) {
      print('Error in getFavoriteByFrameId: $e');
      return null;
    }
  }

  // providers/favorites_provider.dart - Update loadFavorites method
  Future<void> loadFavorites(String token) async {
    _isLoading = true;
    notifyListeners();

    try {
      final response = await _favoritesService.getUserFavorites(token);
      if (response.success) {
        // Handle the response format from your logs
        // Format: {favorites: [{favoriteId: ..., frame: {...}, favoritedAt: ...}, ...]}
        if (response.data.containsKey('favorites')) {
          final List<dynamic> favoritesList = response.data['favorites'] ?? [];

          // Transform the data to our expected format
          _favorites = favoritesList.map<Map<String, dynamic>>((fav) {
            return {
              '_id': fav['favoriteId'], // Map favoriteId to _id
              'frame': fav['frame'] ?? {},
              'frameId': fav['frame']?['_id'] ?? '',
              'favoritedAt': fav['favoritedAt'],
            };
          }).toList();

          if (kDebugMode) {
            print('Loaded ${_favorites.length} favorites');
            print('First favorite: ${_favorites.isNotEmpty ? _favorites.first : "None"}');
          }
        } else {
          _favorites = [];
        }
      } else {
        if (kDebugMode) {
          print('Failed to load favorites: ${response.error}');
        }
        _favorites = [];
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error loading favorites: $e');
      }
      _favorites = [];
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Update addFavorite method in FavoritesProvider
  Future<Map<String, dynamic>?> addFavorite({
    required String token,
    required String frameId,
  }) async {
    try {
      final response = await _favoritesService.addFavorite(
        token: token,
        frameId: frameId,
      );

      if (response.success) {
        // Refresh the favorites list
        await loadFavorites(token);

        // Find and return the newly added favorite
        final newFavorite = getFavoriteByFrameId(frameId);

        if (newFavorite != null) {
          print('Successfully added favorite: ${newFavorite['_id']}');
          return newFavorite;
        } else {
          print('Added favorite but could not find it in list');
          return null;
        }
      } else {
        if (kDebugMode) {
          print('Failed to add favorite: ${response.error}');
        }
        throw Exception(response.error ?? 'Failed to add favorite');
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error adding favorite: $e');
      }
      rethrow;
    }
  }

  // Remove from favorites
  // In FavoritesProvider, update removeFavorite method
  Future<bool> removeFavorite({
    required String token,
    required String favoriteId,
  }) async {
    try {
      print('FavoritesProvider: Removing favorite with ID: $favoriteId');

      final response = await _favoritesService.removeFavorite(
        token: token,
        favoriteId: favoriteId,
      );

      if (response.success) {
        print('FavoritesProvider: Successfully removed favorite');
        // Remove from local list
        _favorites.removeWhere((fav) => fav['_id'] == favoriteId);
        notifyListeners();
        return true;
      } else {
        print('FavoritesProvider: Failed to remove favorite: ${response.error}');
        return false;
      }
    } catch (e) {
      print('FavoritesProvider: Error removing favorite: $e');
      return false;
    }
  }

  // Clear favorites
  void clearFavorites() {
    _favorites.clear();
    notifyListeners();
  }

  // Check if a frame is favorited
  bool isFavorited(String frameId) {
    return getFavoriteByFrameId(frameId) != null;
  }
}