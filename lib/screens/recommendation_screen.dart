import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:camera/camera.dart';
import 'dart:io';
import '../providers/frame_provider.dart';
import '../services/camera_service.dart';
import '../services/api_service.dart';
import '../services/image_service.dart';
import '../widgets/frame_card.dart';
import 'upload_screen.dart';
import 'real_time_screen.dart';

class RecommendationScreen extends StatefulWidget {
  const RecommendationScreen({super.key});

  @override
  State<RecommendationScreen> createState() => _RecommendationScreenState();
}

class _RecommendationScreenState extends State<RecommendationScreen> {
  late CameraService _cameraService;
  File? _capturedImage;
  String? _faceShape;
  bool _isProcessing = false;
  bool _isCameraInitialized = false;
  bool _showCamera = true;

  @override
  void initState() {
    super.initState();
    _cameraService = CameraService();
    _initializeCamera();
  }

  Future<void> _initializeCamera() async {
    try {
      await _cameraService.initializeCamera();
      if (_cameraService.isInitialized && _cameraService.controller != null) {
        setState(() {
          _isCameraInitialized = true;
        });
      }
    } catch (e) {
      setState(() {
        _isCameraInitialized = false;
      });
      Fluttertoast.showToast(
        msg: 'Camera initialization failed',
        toastLength: Toast.LENGTH_LONG,
      );
    }
  }

  Future<void> _capturePhoto() async {
    if (!_isCameraInitialized || _cameraService.controller == null) {
      Fluttertoast.showToast(msg: 'Camera not ready');
      return;
    }

    try {
      setState(() {
        _isProcessing = true;
      });

      final image = await _cameraService.controller!.takePicture();
      final imageFile = File(image.path);

      setState(() {
        _capturedImage = imageFile;
        _showCamera = false;
      });

      // Analyze face
      await _analyzeFace(imageFile);
    } catch (e) {
      Fluttertoast.showToast(msg: 'Error capturing photo: $e');
      setState(() {
        _isProcessing = false;
      });
    }
  }

  Future<void> _analyzeFace(File imageFile) async {
    try {
      final result = await ApiService.analyzeFace(imageFile);

      setState(() {
        _isProcessing = false;
      });

      if (result['success'] == true) {
        setState(() {
          _faceShape = result['face_shape'];
        });

        // Load recommendations
        await Provider.of<FrameProvider>(context, listen: false)
            .getRecommendations(_faceShape!);

        Fluttertoast.showToast(msg: 'Face shape detected: ${result['face_shape']}');
      } else {
        Fluttertoast.showToast(msg: 'Analysis failed: ${result['error']}');
      }
    } catch (e) {
      setState(() {
        _isProcessing = false;
      });
      Fluttertoast.showToast(msg: 'Error analyzing face: $e');
    }
  }

  void _retakePhoto() {
    setState(() {
      _capturedImage = null;
      _faceShape = null;
      _showCamera = true;
    });
  }

  void _goToTryOn({required bool isRealtime}) {
    final frameProvider = Provider.of<FrameProvider>(context, listen: false);
    final recommendedFrames = frameProvider.recommendedFrames;
    
    if (recommendedFrames.isEmpty) {
      Fluttertoast.showToast(msg: 'No recommended frames available');
      return;
    }

    final recommendedFrameFilenames = recommendedFrames.map((f) => f.filename).toList();

    if (isRealtime) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => RealTimeScreen(
            recommendedFrameFilenames: recommendedFrameFilenames,
          ),
        ),
      );
    } else {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => UploadScreen(
            recommendedFrameFilenames: recommendedFrameFilenames,
          ),
        ),
      );
    }
  }

  Widget _buildCameraPreview() {
    final controller = _cameraService.controller;
    if (controller == null || !controller.value.isInitialized) {
      return Container(
        color: Colors.black,
        child: const Center(
          child: Text(
            'Camera not ready',
            style: TextStyle(color: Colors.white),
          ),
        ),
      );
    }

    return SizedBox.expand(
      child: CameraPreview(controller),
    );
  }

  @override
  void dispose() {
    _cameraService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final frameProvider = Provider.of<FrameProvider>(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Get Recommendations'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
      ),
      body: _isProcessing
          ? const Center(child: CircularProgressIndicator())
          : _showCamera
              ? _buildCameraView()
              : _buildResultsView(frameProvider),
    );
  }

  Widget _buildCameraView() {
    return Column(
      children: [
        Expanded(
          child: Container(
            decoration: BoxDecoration(
              color: Colors.black,
              border: Border.all(color: Colors.grey),
            ),
            child: Stack(
              fit: StackFit.expand,
              children: [
                if (_isCameraInitialized && _cameraService.controller != null)
                  _buildCameraPreview()
                else
                  Container(
                    color: Colors.black,
                    child: const Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          CircularProgressIndicator(color: Colors.white),
                          SizedBox(height: 16),
                          Text(
                            'Initializing Camera...',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
        Container(
          padding: const EdgeInsets.all(20),
          child: SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _isCameraInitialized ? _capturePhoto : null,
              icon: const Icon(Icons.camera_alt),
              label: const Text('Capture Photo'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildResultsView(FrameProvider frameProvider) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Captured Image
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  if (_capturedImage != null)
                    Image.file(
                      _capturedImage!,
                      height: 200,
                      fit: BoxFit.cover,
                    ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: _retakePhoto,
                          icon: const Icon(Icons.camera_alt),
                          label: const Text('Retake Photo'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 20),

          // Face Shape Result
          if (_faceShape != null)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  children: [
                    const Icon(Icons.face, color: Colors.blue),
                    const SizedBox(width: 10),
                    Text(
                      'Face Shape: $_faceShape',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),

          const SizedBox(height: 20),

          // Recommended Frames
          if (_faceShape != null && frameProvider.recommendedFrames.isNotEmpty) ...[
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Recommended Frames',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 10),
                    GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        crossAxisSpacing: 10,
                        mainAxisSpacing: 10,
                        childAspectRatio: 0.8,
                      ),
                      itemCount: frameProvider.recommendedFrames.length,
                      itemBuilder: (context, index) {
                        final frame = frameProvider.recommendedFrames[index];
                        return FrameCard(
                          frame: frame,
                          isSelected: false,
                          onTap: () {},
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 20),

            // Try On Buttons
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _goToTryOn(isRealtime: true),
                    icon: const Icon(Icons.camera),
                    label: const Text('Real-time Try-On'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 15),
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _goToTryOn(isRealtime: false),
                    icon: const Icon(Icons.upload),
                    label: const Text('Upload Try-On'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 15),
                      backgroundColor: Colors.blue,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ] else if (_faceShape != null) ...[
            const Card(
              child: Padding(
                padding: EdgeInsets.all(16.0),
                child: Text('No recommended frames available'),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

