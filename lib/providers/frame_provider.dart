import 'package:flutter/foundation.dart';
import '../models/frame_model.dart';
import '../services/api_service.dart';

class FrameProvider with ChangeNotifier {
  List<Frame> _frames = [];
  List<Frame> _recommendedFrames = [];
  bool _isLoading = false;
  String? _error;

  List<Frame> get frames => _frames;
  List<Frame> get recommendedFrames => _recommendedFrames;
  bool get isLoading => _isLoading;
  String? get error => _error;

  // Load all frames
  Future<void> loadFrames() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _frames = await ApiService.getFrames();
      _error = null;
    } catch (e) {
      _error = e.toString();
      _frames = [];
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Get recommendations for face shape
  Future<void> getRecommendations(String faceShape) async {
    _isLoading = true;
    notifyListeners();

    try {
      _recommendedFrames = await ApiService.getRecommendations(faceShape);
      _error = null;
    } catch (e) {
      _error = e.toString();
      _recommendedFrames = [];
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Clear recommendations
  void clearRecommendations() {
    _recommendedFrames = [];
    notifyListeners();
  }
}