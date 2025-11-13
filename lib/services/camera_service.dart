import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:camera/camera.dart';
import 'package:http/http.dart' as http;

class CameraService {
  static const String baseUrl = 'http://192.168.1.80:5000'; // Change to your computer's IP

  CameraController? _controller;
  bool _isInitialized = false;
  bool _isProcessing = false;

  CameraController? get controller => _controller;
  bool get isInitialized => _isInitialized;
  bool get isProcessing => _isProcessing;

  // Initialize camera
  Future<void> initializeCamera() async {
    try {
      final cameras = await availableCameras();

      // Find front camera
      final frontCamera = cameras.firstWhere(
            (camera) => camera.lensDirection == CameraLensDirection.front,
        orElse: () => cameras.first,
      );

      _controller = CameraController(
        frontCamera,
        ResolutionPreset.medium,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.jpeg,
      );

      await _controller!.initialize();
      _isInitialized = true;
      print('✓ Camera initialized successfully');
    } catch (e) {
      print('✗ Camera initialization error: $e');
      throw Exception('Failed to initialize camera: $e');
    }
  }

  // Capture and process frame
  Future<Map<String, dynamic>> captureAndProcessFrame({
    required String frameFilename,
    required String size,
  }) async {
    if (_controller == null || !_isInitialized) {
      throw Exception('Camera not initialized');
    }

    if (_isProcessing) {
      throw Exception('Already processing frame');
    }

    _isProcessing = true;

    try {
      // Capture image
      final image = await _controller!.takePicture();
      final imageFile = File(image.path);

      // Convert image to base64
      final imageBytes = await imageFile.readAsBytes();
      final base64Image = base64Encode(imageBytes);
      final imageDataUrl = 'data:image/jpeg;base64,$base64Image';

      // Send to backend for processing
      final response = await http.post(
        Uri.parse('$baseUrl/api/process_frame'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'image': imageDataUrl,
          'frame': frameFilename,
          'size': size,
        }),
      );

      _isProcessing = false;

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data;
      } else {
        throw Exception('Server error: ${response.statusCode}');
      }
    } catch (e) {
      _isProcessing = false;
      throw Exception('Frame processing error: $e');
    }
  }

  // Dispose camera controller
  void dispose() {
    _controller?.dispose();
    _isInitialized = false;
    _isProcessing = false;
  }
}