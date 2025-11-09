import 'dart:async';

import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:camera/camera.dart';
import '../services/camera_service.dart';
import '../services/face_shape_detector.dart';
import '../models/face_shape.dart';
import '../widgets/camera_preview_widget.dart';

class FaceDetectionScreen extends StatefulWidget {
  const FaceDetectionScreen({super.key});

  @override
  State<FaceDetectionScreen> createState() => _FaceDetectionScreenState();
}

class _FaceDetectionScreenState extends State<FaceDetectionScreen> {
  final CameraService _cameraService = CameraService();
  final FaceShapeDetectorService _faceDetector = FaceShapeDetectorService();

  FaceShape _currentFaceShape = FaceShape.unknown;
  bool _isLoading = true;
  String _errorMessage = '';
  bool _isDetecting = false;
  int _detectionCount = 0;
  bool _isSwitchingCamera = false;
  Timer? _detectionTimer;

  @override
  void initState() {
    super.initState();
    _initializeCamera();
  }

  Future<void> _initializeCamera() async {
    try {
      final status = await Permission.camera.request();

      if (status.isGranted) {
        await _cameraService.initialize();
        _startFaceDetection();
        setState(() {
          _isLoading = false;
        });
      } else {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Camera permission is required for face detection';
        });
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Failed to initialize camera: $e';
      });
    }
  }

  void _startFaceDetection() {
    // Stop any existing timer
    _detectionTimer?.cancel();

    // Start new periodic detection
    _detectionTimer = Timer.periodic(const Duration(seconds: 3), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      _detectFaces();
    });
  }

  void _stopFaceDetection() {
    _detectionTimer?.cancel();
    _detectionTimer = null;
  }

  Future<void> _detectFaces() async {
    if (_isDetecting ||
        !_cameraService.isInitialized ||
        _isSwitchingCamera) {
      return;
    }

    _isDetecting = true;
    try {
      final inputImage = await _cameraService.captureImage();
      final shape = await _faceDetector.detectFaceShape(inputImage);

      if (mounted) {
        setState(() {
          _currentFaceShape = shape;
          _detectionCount++;
        });
      }
    } catch (e) {
      print('Face detection error: $e');
      // Don't update UI on temporary errors during camera switch
    } finally {
      _isDetecting = false;
    }
  }

  Future<void> _switchCamera() async {
    if (_isSwitchingCamera || _cameraService.availableCamerasCount < 2) return;

    // Stop detection during camera switch
    _stopFaceDetection();

    setState(() {
      _isSwitchingCamera = true;
      _currentFaceShape = FaceShape.unknown;
    });

    try {
      await _cameraService.switchCamera();

      // Restart detection after successful switch
      if (mounted) {
        _startFaceDetection();
      }
    } catch (e) {
      print('Error switching camera: $e');
      if (mounted) {
        setState(() {
          _errorMessage = 'Failed to switch camera: $e';
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSwitchingCamera = false;
        });
      }
    }
  }

  Widget _buildResultPanel() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.8),
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.5),
            blurRadius: 10,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_isSwitchingCamera) ...[
            const CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
            ),
            const SizedBox(height: 16),
            const Text(
              'Switching Camera...',
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
              ),
            ),
          ] else ...[
            // Shape name
            Text(
              _currentFaceShape.name,
              style: TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.bold,
                color: _currentFaceShape.color,
              ),
            ),
            const SizedBox(height: 8),

            // Shape description
            Text(
              _currentFaceShape.description,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 16,
                color: Colors.white70,
              ),
            ),
            const SizedBox(height: 16),

            // Detection indicator
            _buildShapeIndicator(),

            const SizedBox(height: 8),

            // Tips
            _buildTips(),
          ],
        ],
      ),
    );
  }

  Widget _buildShapeIndicator() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: _currentFaceShape.color.withOpacity(0.2),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _currentFaceShape.color),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.face_retouching_natural,
            color: _currentFaceShape.color,
          ),
          const SizedBox(width: 8),
          Text(
            'Detection: $_detectionCount',
            style: TextStyle(
              color: _currentFaceShape.color,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTips() {
    return const Column(
      children: [
        Icon(
          Icons.lightbulb_outline,
          color: Colors.yellow,
          size: 16,
        ),
        SizedBox(height: 4),
        Text(
          'Ensure good lighting and face the camera directly',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Colors.white54,
            fontSize: 12,
          ),
        ),
      ],
    );
  }

  Widget _buildCameraControls() {
    return Positioned(
      top: 60,
      right: 16,
      child: Column(
        children: [
          // Camera switch button
          if (_cameraService.availableCamerasCount > 1)
            FloatingActionButton(
              onPressed: _isSwitchingCamera ? null : _switchCamera,
              mini: true,
              backgroundColor: Colors.black54,
              child: _isSwitchingCamera
                  ? const CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                strokeWidth: 2,
              )
                  : Icon(
                _cameraService.isFrontCamera
                    ? Icons.camera_rear
                    : Icons.camera_front,
                color: Colors.white,
              ),
            ),
          const SizedBox(height: 16),
          // Camera info
          if (!_isSwitchingCamera)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.black54,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                _cameraService.isFrontCamera ? 'Front' : 'Back',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildErrorScreen() {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.error_outline,
                color: Colors.red,
                size: 64,
              ),
              const SizedBox(height: 20),
              Text(
                _errorMessage,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                ),
              ),
              const SizedBox(height: 30),
              ElevatedButton(
                onPressed: _initializeCamera,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.deepPurple,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 15),
                ),
                child: const Text('Try Again'),
              ),
              const SizedBox(height: 20),
              TextButton(
                onPressed: () => openAppSettings(),
                child: const Text(
                  'Open App Settings',
                  style: TextStyle(color: Colors.blue),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLoadingScreen() {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Colors.deepPurple),
            ),
            const SizedBox(height: 20),
            const Text(
              'Initializing Netrafit',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
              ),
            ),
            if (_errorMessage.isNotEmpty) ...[
              const SizedBox(height: 10),
              Text(
                _errorMessage,
                style: const TextStyle(
                  color: Colors.red,
                  fontSize: 14,
                ),
              ),
            ]
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return _buildLoadingScreen();
    }

    if (_errorMessage.isNotEmpty && !_cameraService.isInitialized) {
      return _buildErrorScreen();
    }

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('Netrafit - Face Shape Detector'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          // Camera info in app bar
          if (_cameraService.availableCamerasCount > 1 && !_isSwitchingCamera)
            Padding(
              padding: const EdgeInsets.only(right: 16.0),
              child: Row(
                children: [
                  Icon(
                    _cameraService.isFrontCamera
                        ? Icons.camera_front
                        : Icons.camera_rear,
                    color: Colors.white,
                    size: 20,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    _cameraService.isFrontCamera ? 'Front' : 'Back',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
          IconButton(
            icon: const Icon(Icons.info_outline),
            onPressed: _isSwitchingCamera ? null : () {
              showDialog(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('About Face Shapes'),
                  content: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _buildShapeInfo('Oval', 'Balanced proportions, slightly longer than wide'),
                        _buildShapeInfo('Round', 'Full cheeks with similar width and length'),
                        _buildShapeInfo('Square', 'Strong jawline and forehead of similar width'),
                        _buildShapeInfo('Heart', 'Wide forehead tapering to narrow chin'),
                        _buildShapeInfo('Diamond', 'Wide cheekbones, narrow forehead and jaw'),
                        _buildShapeInfo('Oblong', 'Long face with consistent width'),
                      ],
                    ),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('OK'),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
      body: Stack(
        children: [
          Column(
            children: [
              Expanded(
                child: _isSwitchingCamera
                    ? Container(
                  color: Colors.black,
                  child: const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CircularProgressIndicator(
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                        SizedBox(height: 16),
                        Text(
                          'Switching Camera...',
                          style: TextStyle(color: Colors.white, fontSize: 16),
                        ),
                      ],
                    ),
                  ),
                )
                    : CameraPreviewWidget(
                  controller: _cameraService.cameraController,
                ),
              ),
              _buildResultPanel(),
            ],
          ),
          if (!_isSwitchingCamera) _buildCameraControls(),
        ],
      ),
      floatingActionButton: _cameraService.availableCamerasCount > 1 && !_isSwitchingCamera
          ? FloatingActionButton(
        onPressed: _switchCamera,
        backgroundColor: Colors.deepPurple,
        child: Icon(
          _cameraService.isFrontCamera
              ? Icons.camera_rear
              : Icons.camera_front,
          color: Colors.white,
        ),
      )
          : null,
    );
  }

  Widget _buildShapeInfo(String shape, String description) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '• $shape:',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          Text(
            '  $description',
            style: const TextStyle(fontSize: 12, color: Colors.grey),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _stopFaceDetection();
    _cameraService.dispose();
    _faceDetector.dispose();
    super.dispose();
  }
}