import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:camera/camera.dart';
import 'package:google_mlkit_commons/google_mlkit_commons.dart';

class CameraService {
  CameraController? _cameraController;
  late List<CameraDescription> _cameras;
  bool _isInitialized = false;
  int _currentCameraIndex = 0;
  bool _isFrontCamera = true;
  Completer<void>? _initializationCompleter;
  bool _isDisposed = false;

  Future<void> initialize() async {
    _cameras = await availableCameras();

    // Find front camera first
    _currentCameraIndex = _findFrontCameraIndex();
    _isFrontCamera = true;

    await _initializeCameraController();
  }

  int _findFrontCameraIndex() {
    for (int i = 0; i < _cameras.length; i++) {
      if (_cameras[i].lensDirection == CameraLensDirection.front) {
        return i;
      }
    }
    return 0; // Fallback to first camera
  }

  Future<void> _initializeCameraController() async {
    // Cancel any pending initialization
    if (_initializationCompleter != null && !_initializationCompleter!.isCompleted) {
      _initializationCompleter!.completeError('Camera switched');
    }

    _initializationCompleter = Completer<void>();

    if (_cameraController != null) {
      await _cameraController!.dispose();
      _cameraController = null;
    }

    try {
      _cameraController = CameraController(
        _cameras[_currentCameraIndex],
        ResolutionPreset.medium,
        enableAudio: false,
        imageFormatGroup: Platform.isAndroid
            ? ImageFormatGroup.yuv420
            : ImageFormatGroup.bgra8888,
      );

      await _cameraController!.initialize();

      _isInitialized = true;
      _isDisposed = false;
      _initializationCompleter!.complete();
    } catch (e) {
      _isInitialized = false;
      _initializationCompleter!.completeError(e);
      rethrow;
    }
  }

  Future<void> switchCamera() async {
    if (_cameras.length < 2) return;

    _currentCameraIndex = (_currentCameraIndex + 1) % _cameras.length;
    _isFrontCamera = _cameras[_currentCameraIndex].lensDirection == CameraLensDirection.front;

    await _initializeCameraController();
  }

  Future<InputImage> captureImage() async {
    // Wait for camera to be fully initialized
    if (_initializationCompleter != null && !_initializationCompleter!.isCompleted) {
      await _initializationCompleter!.future;
    }

    if (_cameraController == null ||
        !_cameraController!.value.isInitialized ||
        _isDisposed) {
      throw Exception('Camera not initialized or disposed');
    }

    try {
      final image = await _cameraController!.takePicture();
      return InputImage.fromFilePath(image.path);
    } catch (e) {
      throw Exception('Failed to capture image: $e');
    }
  }

  CameraController? get cameraController => _cameraController;

  bool get isInitialized => _isInitialized &&
      _cameraController != null &&
      _cameraController!.value.isInitialized &&
      !_isDisposed;

  bool get isFrontCamera => _isFrontCamera;
  int get availableCamerasCount => _cameras.length;

  Future<void> dispose() async {
    // Cancel any pending initialization
    if (_initializationCompleter != null && !_initializationCompleter!.isCompleted) {
      _initializationCompleter!.completeError('Camera disposed');
    }

    await _cameraController?.dispose();
    _cameraController = null;
    _isInitialized = false;
    _isDisposed = true;
  }
}