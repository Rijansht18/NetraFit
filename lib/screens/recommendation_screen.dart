import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'dart:io';
import '../providers/frame_provider.dart';
import '../services/api_service.dart';
import '../services/image_service.dart';
import '../widgets/frame_card.dart';
import 'try_on_screen.dart';
import 'upload_screen.dart';

class RecommendationScreen extends StatefulWidget {
  const RecommendationScreen({super.key});

  @override
  State<RecommendationScreen> createState() => _RecommendationScreenState();
}

class _RecommendationScreenState extends State<RecommendationScreen> {
  File? _capturedImage;
  String? _faceShape;
  bool _isProcessing = false;
  bool _showCamera = false;

  @override
  void initState() {
    super.initState();
  }

  Future<void> _capturePhoto() async {
    try {
      final image = await ImageService.captureImageFromCamera();
      if (image != null) {
        setState(() {
          _capturedImage = image;
          _isProcessing = true;
        });
        await _analyzeFace(image);
      }
    } catch (e) {
      Fluttertoast.showToast(msg: 'Error capturing photo: $e');
    }
  }

  Future<void> _pickImage() async {
    try {
      final image = await ImageService.pickImageFromGallery();
      if (image != null) {
        setState(() {
          _capturedImage = image;
          _isProcessing = true;
        });
        await _analyzeFace(image);
      }
    } catch (e) {
      Fluttertoast.showToast(msg: 'Error picking image: $e');
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

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => isRealtime
            ? TryOnScreen(recommendedFrameFilenames: recommendedFrameFilenames, showHeader: true,)
            : UploadScreen(recommendedFrameFilenames: recommendedFrameFilenames, showHeader: true,),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final frameProvider = Provider.of<FrameProvider>(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Recommendation'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
      ),
      body: _isProcessing
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            const Center(
              child: Column(
                children: [
                  Icon(
                    Icons.face_retouching_natural,
                    size: 80,
                    color: Colors.blue,
                  ),
                  SizedBox(height: 16),
                  Text(
                    'Face Shape Detector',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.blue,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Position your face in the frame',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),

            const SizedBox(height: 30),

            // Image Capture Section
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
                      )
                    else
                      Container(
                        height: 200,
                        color: Colors.grey[100],
                        child: const Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.photo_camera,
                              size: 50,
                              color: Colors.grey,
                            ),
                            SizedBox(height: 16),
                            Text(
                              'Capture or upload a photo',
                              style: TextStyle(
                                color: Colors.grey,
                              ),
                            ),
                          ],
                        ),
                      ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: _capturePhoto,
                            icon: const Icon(Icons.camera_alt),
                            label: const Text('Capture Photo'),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: _pickImage,
                            icon: const Icon(Icons.photo_library),
                            label: const Text('Upload Photo'),
                          ),
                        ),
                      ],
                    ),
                    if (_capturedImage != null) ...[
                      const SizedBox(height: 10),
                      ElevatedButton(
                        onPressed: _retakePhoto,
                        child: const Text('Retake Photo'),
                      ),
                    ],
                  ],
                ),
              ),
            ),

            const SizedBox(height: 20),

            // Face Shape Result
            if (_faceShape != null)
              Card(
                color: Colors.green[50],
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    children: [
                      const Icon(Icons.face, color: Colors.green, size: 40),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Detected Face Shape',
                              style: TextStyle(
                                fontSize: 16,
                                color: Colors.green,
                              ),
                            ),
                            Text(
                              _faceShape!,
                              style: const TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: Colors.green,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

            const SizedBox(height: 20),

            // Get Recommendations Button
            if (_faceShape != null && frameProvider.recommendedFrames.isEmpty)
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () {
                    Provider.of<FrameProvider>(context, listen: false)
                        .getRecommendations(_faceShape!);
                  },
                  icon: const Icon(Icons.recommend),
                  label: const Text('Get Recommended Frames'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 15),
                    backgroundColor: Colors.purple,
                    foregroundColor: Colors.white,
                  ),
                ),
              ),

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
                      SizedBox(
                        height: 200,
                        child: ListView.builder(
                          scrollDirection: Axis.horizontal,
                          itemCount: frameProvider.recommendedFrames.length,
                          itemBuilder: (context, index) {
                            final frame = frameProvider.recommendedFrames[index];
                            return Container(
                              width: 150,
                              margin: const EdgeInsets.only(right: 10),
                              child: FrameCard(
                                frame: frame,
                                isSelected: false,
                                onTap: () {},
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 20),

              // Try On Buttons
              const Text(
                'Try Recommended Frames:',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => _goToTryOn(isRealtime: true),
                      icon: const Icon(Icons.camera),
                      label: const Text('AR Try On'),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 15),
                        backgroundColor: Colors.blue,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => _goToTryOn(isRealtime: false),
                      icon: const Icon(Icons.photo),
                      label: const Text('Photo Try On'),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 15),
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}