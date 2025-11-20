import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:camera/camera.dart';
import 'package:http/http.dart' as http;
import 'package:permission_handler/permission_handler.dart';

class CameraService {
  static const String baseUrl = 'https://violetlike-onward-marley.ngrok-free.dev'; // Change to your computer's IP

  CameraController? _controller;
  bool _isInitialized = false;
  bool _isProcessing = false;
  String? _initializationError;

  CameraController? get controller => _controller;
  bool get isInitialized => _isInitialized;
  bool get isProcessing => _isProcessing;
  String? get initializationError => _initializationError;

  // Request camera permission
  Future<bool> requestCameraPermission() async {
    try {
      print('📷 Requesting camera permission...');
      final status = await Permission.camera.request();
      print('📷 Camera permission status: $status');
      
      if (status.isGranted) {
        print('✓ Camera permission granted');
        return true;
      } else if (status.isPermanentlyDenied) {
        print('✗ Camera permission permanently denied');
        _initializationError = 'Camera permission is permanently denied. Please enable it in app settings.';
        return false;
      } else {
        print('✗ Camera permission denied');
        _initializationError = 'Camera permission denied. Please grant camera access to use this feature.';
        return false;
      }
    } catch (e) {
      print('✗ Error requesting camera permission: $e');
      _initializationError = 'Error requesting camera permission: $e';
      return false;
    }
  }

  // Check camera permission
  Future<bool> checkCameraPermission() async {
    try {
      final status = await Permission.camera.status;
      print('📷 Camera permission check: $status');
      return status.isGranted;
    } catch (e) {
      print('✗ Error checking camera permission: $e');
      return false;
    }
  }

  // Initialize camera
  Future<void> initializeCamera() async {
    try {
      print('📷 Starting camera initialization...');
      
      // Check and request permission first
      final hasPermission = await checkCameraPermission();
      if (!hasPermission) {
        final granted = await requestCameraPermission();
        if (!granted) {
          throw Exception(_initializationError ?? 'Camera permission not granted');
        }
      }

      print('📷 Getting available cameras...');
      final cameras = await availableCameras();
      print('📷 Found ${cameras.length} camera(s)');

      if (cameras.isEmpty) {
        throw Exception('No cameras available on this device');
      }

      // Find front camera
      CameraDescription? frontCamera;
      try {
        frontCamera = cameras.firstWhere(
          (camera) => camera.lensDirection == CameraLensDirection.front,
        );
        print('✓ Found front camera: ${frontCamera.name}');
      } catch (e) {
        print('⚠ Front camera not found, using first available camera');
        frontCamera = cameras.first;
      }

      print('📷 Creating camera controller...');
      // Use low resolution for faster processing in real-time
      _controller = CameraController(
        frontCamera,
        ResolutionPreset.low, // Low for faster capture and processing
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.jpeg,
      );

      print('📷 Initializing camera controller...');
      await _controller!.initialize();
      
      // Verify controller is initialized
      if (!_controller!.value.isInitialized) {
        throw Exception('Camera controller initialization failed - controller not initialized');
      }

      _isInitialized = true;
      _initializationError = null;
      print('✓ Camera initialized successfully');
      print('  - Camera: ${frontCamera.name}');
      print('  - Resolution: ${_controller!.value.previewSize}');
      print('  - Initialized: ${_controller!.value.isInitialized}');
    } catch (e, stackTrace) {
      print('✗ Camera initialization error: $e');
      print('Stack trace: $stackTrace');
      _isInitialized = false;
      _initializationError = e.toString();
      await dispose();
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
      // Capture image at lower resolution for faster processing
      final image = await _controller!.takePicture();
      final imageFile = File(image.path);

      // Read and compress image for faster transfer
      final imageBytes = await imageFile.readAsBytes();
      
      // Compress image to reduce size (use lower quality for speed)
      // Note: For better performance, we could use image package to resize
      // For now, we'll just use the image as-is but note that backend should handle it
      
      final base64Image = base64Encode(imageBytes);
      final imageDataUrl = 'data:image/jpeg;base64,$base64Image';

      // Send to backend for processing with timeout
      final response = await http.post(
        Uri.parse('$baseUrl/api/process_frame'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'image': imageDataUrl,
          'frame': frameFilename,
          'size': size,
        }),
      ).timeout(
        const Duration(seconds: 5),
        onTimeout: () {
          throw Exception('Request timeout');
        },
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
  Future<void> dispose() async {
    print('📷 Disposing camera service...');
    try {
      await _controller?.dispose();
      _controller = null;
      _isInitialized = false;
      _isProcessing = false;
      _initializationError = null;
      print('✓ Camera service disposed');
    } catch (e) {
      print('✗ Error disposing camera: $e');
    }
  }
}