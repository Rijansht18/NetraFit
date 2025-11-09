import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:google_ml_kit/google_ml_kit.dart';

class CameraService {
  CameraController? _cameraController;
  late List<CameraDescription> _cameras;
  bool _isInitialized = false;
  int _currentCameraIndex = 0;
  bool _isFrontCamera = true;

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
    if (_cameraController != null) {
      await _cameraController!.dispose();
    }

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
  }

  Future<void> switchCamera() async {
    if (_cameras.length < 2) return; // Only one camera available

    _currentCameraIndex = (_currentCameraIndex + 1) % _cameras.length;
    _isFrontCamera = _cameras[_currentCameraIndex].lensDirection == CameraLensDirection.front;

    await _initializeCameraController();
  }

  CameraController? get cameraController => _cameraController;
  bool get isInitialized => _isInitialized;
  bool get isFrontCamera => _isFrontCamera;
  int get availableCamerasCount => _cameras.length;

  Future<InputImage> captureImage() async {
    if (_cameraController == null || !_cameraController!.value.isInitialized) {
      throw Exception('Camera not initialized');
    }

    final image = await _cameraController!.takePicture();
    return InputImage.fromFilePath(image.path);
  }

  InputImage? convertCameraImage(CameraImage image) {
    try {
      final WriteBuffer allBytes = WriteBuffer();
      for (final Plane plane in image.planes) {
        allBytes.putUint8List(plane.bytes);
      }
      final bytes = allBytes.done().buffer.asUint8List();

      final inputImageData = InputImageMetadata(
        size: ui.Size(image.width.toDouble(), image.height.toDouble()),
        rotation: _getRotation(),
        format: InputImageFormat.nv21,
        bytesPerRow: image.planes.first.bytesPerRow,
      );

      return InputImage.fromBytes(
        bytes: bytes,
        metadata: inputImageData,
      );
    } catch (e) {
      print('Error converting camera image: $e');
      return null;
    }
  }

  InputImageRotation _getRotation() {
    if (Platform.isAndroid) {
      return InputImageRotation.rotation0deg;
    } else {
      // iOS rotation handling
      switch (_cameraController!.description.sensorOrientation) {
        case 90:
          return InputImageRotation.rotation90deg;
        case 180:
          return InputImageRotation.rotation180deg;
        case 270:
          return InputImageRotation.rotation270deg;
        default:
          return InputImageRotation.rotation0deg;
      }
    }
  }

  Future<void> dispose() async {
    await _cameraController?.dispose();
    _isInitialized = false;
  }
}