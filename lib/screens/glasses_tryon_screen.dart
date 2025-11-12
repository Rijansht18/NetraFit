import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:netrafit_glasses/painters/glasses_overlay_painter.dart';
import 'package:netrafit_glasses/models/glass_model.dart';

class GlassesTryOnScreen extends StatefulWidget {
  const GlassesTryOnScreen({super.key});

  @override
  State<GlassesTryOnScreen> createState() => _GlassesTryOnScreenState();
}

class _GlassesTryOnScreenState extends State<GlassesTryOnScreen> {
  CameraController? _controller;
  Future<void>? _initializeControllerFuture;
  final FaceDetector _faceDetector = FaceDetector(
    options: FaceDetectorOptions(
      enableClassification: true,
      enableLandmarks: true,
      enableTracking: true,
      performanceMode: FaceDetectorMode.fast,
      minFaceSize: 0.1,
    ),
  );

  bool _isDetecting = false;
  List<Face> _faces = [];
  List<CameraDescription> cameras = [];
  int _selectedCameraIndex = 0;

  List<GlassModel> _glassesOptions = [];
  int _selectedGlassesIndex = 0;
  bool _showGlassesSelector = false;

  final Map<String, ui.Image> _glassesImages = {};
  bool _imagesLoaded = false;

  @override
  void initState() {
    super.initState();
    _initGlassesOptions();
    _loadGlassesImages();
    _initializeApp();
  }

  Future<void> _initializeApp() async {
    await _requestPermissions();
    await _initializeCameras();
  }

  void _initGlassesOptions() {
    _glassesOptions = [
      GlassModel(
        name: "Classic Black",
        imagePath: "assets/image1.png",
        widthFactor: 2.2,
        heightFactor: 1.0,
      ),
      GlassModel(
        name: "Aviator",
        imagePath: "assets/image2.png",
        widthFactor: 2.2,
        heightFactor: 1.0,
      ),
      GlassModel(
        name: "Round Vintage",
        imagePath: "assets/image3.png",
        widthFactor: 2.2,
        heightFactor: 1.0,
      ),
      GlassModel(
        name: "Square Frame",
        imagePath: "assets/image4.png",
        widthFactor: 2.2,
        heightFactor: 1.0,
      ),
      GlassModel(
        name: "Cat Eye",
        imagePath: "assets/image5.png",
        widthFactor: 2.2,
        heightFactor: 1.0,
      ),
    ];
  }

  Future<void> _loadGlassesImages() async {
    try {
      for (GlassModel glasses in _glassesOptions) {
        if (glasses.imagePath.isNotEmpty) {
          final ByteData data = await rootBundle.load(glasses.imagePath);
          final Uint8List bytes = data.buffer.asUint8List();
          final ui.Codec codec = await ui.instantiateImageCodec(bytes);
          final ui.FrameInfo frameInfo = await codec.getNextFrame();
          final ui.Image image = frameInfo.image;

          _glassesImages[glasses.imagePath] = image;
        }
      }
      setState(() {
        _imagesLoaded = true;
      });
    } catch (e) {
      // Handle image loading error
    }
  }

  Future<void> _requestPermissions() async {
    final status = await Permission.camera.request();
    if (status != PermissionStatus.granted) {
      // Handle permission denied
    }
  }

  Future<void> _initializeCameras() async {
    try {
      cameras = await availableCameras();

      if (cameras.isEmpty) {
        return;
      }

      // Prefer front camera
      _selectedCameraIndex = cameras.indexWhere(
            (camera) => camera.lensDirection == CameraLensDirection.front,
      );

      if (_selectedCameraIndex == -1) {
        _selectedCameraIndex = 0;
      }

      await _initializeCamera(cameras[_selectedCameraIndex]);
    } catch (e) {
      // Handle camera initialization error
    }
  }

  Future<void> _initializeCamera(CameraDescription cameraDescription) async {
    try {
      final controller = CameraController(
        cameraDescription,
        ResolutionPreset.high,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.yuv420,
      );

      _controller = controller;

      _initializeControllerFuture = controller.initialize().then((_) {
        if (!mounted) return;
        setState(() {
          _startFaceDetection();
        });
      }).catchError((error) {
        _initializeCameraWithFallback(cameraDescription);
      });
    } catch (e) {
      // Handle camera controller creation error
    }
  }

  Future<void> _initializeCameraWithFallback(CameraDescription cameraDescription) async {
    try {
      final controller = CameraController(
        cameraDescription,
        ResolutionPreset.medium,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.yuv420,
      );

      _controller = controller;

      _initializeControllerFuture = controller.initialize().then((_) {
        if (!mounted) return;
        setState(() {
          _startFaceDetection();
        });
      });
    } catch (e) {
      // Handle fallback camera initialization error
    }
  }

  void _toggleCamera() async {
    if (cameras.isEmpty || cameras.length < 2) {
      return;
    }

    if (_controller != null && _controller!.value.isStreamingImages) {
      await _controller!.stopImageStream();
    }

    _selectedCameraIndex = (_selectedCameraIndex + 1) % cameras.length;

    setState(() {
      _faces = [];
    });

    await _initializeCamera(cameras[_selectedCameraIndex]);
  }

  void _startFaceDetection() {
    if (_controller == null || !_controller!.value.isInitialized) {
      return;
    }

    _controller!.startImageStream((CameraImage image) async {
      if (_isDetecting) return;

      _isDetecting = true;

      try {
        final inputImage = _convertCameraImageToInputImage(image);
        if (inputImage == null) {
          _isDetecting = false;
          return;
        }

        final List<Face> faces = await _faceDetector.processImage(inputImage);

        if (mounted) {
          setState(() {
            _faces = faces;
          });
        }
      } catch (e) {
        // Handle face detection error
      } finally {
        _isDetecting = false;
      }
    });
  }

  InputImage? _convertCameraImageToInputImage(CameraImage image) {
    if (_controller == null) {
      return null;
    }

    try {
      final rotation = _getRotation();
      final format = _getInputImageFormat(image);

      final inputImageMetadata = InputImageMetadata(
        size: Size(image.width.toDouble(), image.height.toDouble()),
        rotation: rotation,
        format: format,
        bytesPerRow: image.planes.first.bytesPerRow,
      );

      if (format == InputImageFormat.nv21) {
        return InputImage.fromBytes(
          bytes: _concatenateYUV420Planes(image.planes),
          metadata: inputImageMetadata,
        );
      } else if (format == InputImageFormat.bgra8888) {
        return InputImage.fromBytes(
          bytes: image.planes.first.bytes,
          metadata: inputImageMetadata,
        );
      } else {
        return null;
      }
    } catch (e) {
      return null;
    }
  }

  InputImageRotation _getRotation() {
    if (_controller == null) return InputImageRotation.rotation0deg;

    final sensorOrientation = _controller!.description.sensorOrientation;

    switch (sensorOrientation) {
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

  InputImageFormat _getInputImageFormat(CameraImage image) {
    if (Platform.isAndroid) {
      return InputImageFormat.nv21;
    } else if (Platform.isIOS) {
      return InputImageFormat.bgra8888;
    }
    return InputImageFormat.nv21;
  }

  Uint8List _concatenateYUV420Planes(List<Plane> planes) {
    final WriteBuffer allBytes = WriteBuffer();
    allBytes.putUint8List(planes[0].bytes);

    final uvPlane = planes[1];
    final vuPlane = planes[2];

    for (int i = 0; i < uvPlane.bytes.length; i++) {
      allBytes.putUint8(vuPlane.bytes[i]);
      allBytes.putUint8(uvPlane.bytes[i]);
    }

    return allBytes.done().buffer.asUint8List();
  }

  void _toggleGlassesSelector() {
    setState(() {
      _showGlassesSelector = !_showGlassesSelector;
    });
  }

  void _selectGlasses(int index) {
    setState(() {
      _selectedGlassesIndex = index;
      _showGlassesSelector = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Virtual Glasses Try-On"),
        backgroundColor: Colors.blue,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          if (cameras.length > 1)
            IconButton(
              onPressed: _toggleCamera,
              icon: const Icon(Icons.switch_camera),
              tooltip: "Switch Camera",
            ),
          IconButton(
            onPressed: _toggleGlassesSelector,
            icon: const Icon(Icons.visibility),
            tooltip: "Select Glasses",
          ),
        ],
      ),
      body: Stack(
        children: [
          _buildCameraView(),
          if (_showGlassesSelector) _buildGlassesSelector(),
        ],
      ),
    );
  }

  Widget _buildCameraView() {
    if (!_imagesLoaded) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 20),
            Text("Loading glasses frames..."),
          ],
        ),
      );
    }

    if (_initializeControllerFuture == null) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.camera, size: 64, color: Colors.grey),
            SizedBox(height: 20),
            Text("No Camera Available"),
          ],
        ),
      );
    }

    return FutureBuilder<void>(
      future: _initializeControllerFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.done) {
          if (_controller != null && _controller!.value.isInitialized) {
            final previewSize = _controller!.value.previewSize;

            return Stack(
              fit: StackFit.expand,
              children: [
                CameraPreview(_controller!),
                CustomPaint(
                  painter: GlassesOverlayPainter(
                    faces: _faces,
                    imageSize: Size(
                      previewSize!.width,
                      previewSize.height,
                    ),
                    cameraLensDirection: _controller!.description.lensDirection,
                    glasses: _glassesOptions[_selectedGlassesIndex],
                    glassesImage: _glassesImages[_glassesOptions[_selectedGlassesIndex].imagePath],
                  ),
                ),
                Positioned(
                  top: 20,
                  left: 20,
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.7),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          _faces.isEmpty ? Icons.face_retouching_off : Icons.face_retouching_natural,
                          color: _faces.isEmpty ? Colors.orange : Colors.green,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          "Faces: ${_faces.length}",
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                Positioned(
                  bottom: 20,
                  left: 0,
                  right: 0,
                  child: Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.7),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        _glassesOptions[_selectedGlassesIndex].name,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ),
                if (_faces.isEmpty)
                  Positioned(
                    top: MediaQuery.of(context).size.height * 0.3,
                    left: 0,
                    right: 0,
                    child: Column(
                      children: [
                        const Icon(Icons.face, size: 64, color: Colors.white54),
                        const SizedBox(height: 16),
                        const Text(
                          "Position your face in the frame",
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          "Make sure you have good lighting",
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 14,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
              ],
            );
          } else {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 20),
                  Text("Initializing camera..."),
                ],
              ),
            );
          }
        } else if (snapshot.hasError) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error, size: 64, color: Colors.red),
                const SizedBox(height: 20),
                const Text("Camera Error"),
                const SizedBox(height: 10),
                Text(
                  snapshot.error.toString(),
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.red),
                ),
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: _initializeCameras,
                  child: const Text("Retry"),
                ),
              ],
            ),
          );
        } else {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 20),
                Text("Setting up camera..."),
              ],
            ),
          );
        }
      },
    );
  }

  Widget _buildGlassesSelector() {
    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: Container(
        height: 180,
        decoration: BoxDecoration(
          color: Colors.black87,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(20),
            topRight: Radius.circular(20),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black54,
              blurRadius: 10,
              spreadRadius: 2,
            ),
          ],
        ),
        child: Column(
          children: [
            const Padding(
              padding: EdgeInsets.all(12),
              child: Text(
                "Select Glasses Frame",
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
            Expanded(
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: _glassesOptions.length,
                padding: const EdgeInsets.symmetric(horizontal: 10),
                itemBuilder: (context, index) {
                  final glasses = _glassesOptions[index];
                  final isSelected = _selectedGlassesIndex == index;

                  return GestureDetector(
                    onTap: () => _selectGlasses(index),
                    child: Container(
                      width: 120,
                      margin: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: isSelected ? Colors.blue.withOpacity(0.3) : Colors.grey.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(15),
                        border: Border.all(
                          color: isSelected ? Colors.blue : Colors.transparent,
                          width: 3,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black26,
                            blurRadius: 5,
                            spreadRadius: 1,
                          ),
                        ],
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          if (_imagesLoaded && _glassesImages.containsKey(glasses.imagePath))
                            Container(
                              height: 80,
                              padding: const EdgeInsets.all(8),
                              child: Image.asset(
                                glasses.imagePath,
                                fit: BoxFit.contain,
                              ),
                            )
                          else
                            Container(
                              height: 80,
                              child: const Center(
                                child: CircularProgressIndicator(),
                              ),
                            ),
                          const SizedBox(height: 8),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 4),
                            child: Text(
                              glasses.name,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                              ),
                              textAlign: TextAlign.center,
                              maxLines: 2,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 10),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _controller?.dispose();
    _faceDetector.close();
    for (var image in _glassesImages.values) {
      image.dispose();
    }
    super.dispose();
  }
}