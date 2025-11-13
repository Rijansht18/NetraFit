import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'dart:io';
import '../providers/frame_provider.dart';
import '../services/image_service.dart';
import '../services/api_service.dart';
import '../widgets/frame_card.dart';
import '../widgets/size_selector.dart';
import '../widgets/recommendation_widget.dart';

class UploadScreen extends StatefulWidget {
  const UploadScreen({super.key});

  @override
  State<UploadScreen> createState() => _UploadScreenState();
}

class _UploadScreenState extends State<UploadScreen> {
  File? _selectedImage;
  String? _faceShape;
  String _selectedFrame = '';
  String _selectedSize = 'medium';
  bool _isProcessing = false;
  String? _resultImageUrl;

  final Map<String, String> frameSizes = {
    'small': 'Small',
    'medium': 'Medium',
    'large': 'Large',
  };

  @override
  void initState() {
    super.initState();
    // Load frames when screen initializes
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<FrameProvider>(context, listen: false).loadFrames();
    });
  }

  Future<void> _pickImage() async {
    try {
      final image = await ImageService.pickImageFromGallery();
      if (image != null) {
        setState(() {
          _selectedImage = image;
          _faceShape = null;
          _resultImageUrl = null;
        });
      }
    } catch (e) {
      Fluttertoast.showToast(msg: 'Error picking image: $e');
    }
  }

  Future<void> _analyzeFace() async {
    if (_selectedImage == null) return;

    setState(() {
      _isProcessing = true;
    });

    final result = await ApiService.analyzeFace(_selectedImage!);

    setState(() {
      _isProcessing = false;
    });

    if (result['success'] == true) {
      setState(() {
        _faceShape = result['face_shape'];
      });

      // Load recommendations
      Provider.of<FrameProvider>(context, listen: false)
          .getRecommendations(_faceShape!);

      Fluttertoast.showToast(msg: 'Face shape: ${result['face_shape']}');
    } else {
      Fluttertoast.showToast(msg: 'Analysis failed: ${result['error']}');
    }
  }

  Future<void> _tryFrame() async {
    if (_selectedImage == null || _selectedFrame.isEmpty) return;

    setState(() {
      _isProcessing = true;
    });

    final result = await ApiService.tryFrame(
      _selectedImage!,
      _selectedFrame,
      _selectedSize,
    );

    setState(() {
      _isProcessing = false;
    });

    if (result['success'] == true) {
      setState(() {
        _resultImageUrl = result['result_url'];
      });
      Fluttertoast.showToast(msg: 'Frame applied successfully!');
    } else {
      Fluttertoast.showToast(msg: 'Failed: ${result['error']}');
    }
  }

  @override
  Widget build(BuildContext context) {
    final frameProvider = Provider.of<FrameProvider>(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Upload Photo'),
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
            // Image Selection
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    if (_selectedImage != null)
                      Image.file(
                        _selectedImage!,
                        height: 200,
                        fit: BoxFit.cover,
                      )
                    else
                      Container(
                        height: 200,
                        color: Colors.grey[200],
                        child: const Icon(
                          Icons.photo,
                          size: 50,
                          color: Colors.grey,
                        ),
                      ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: _pickImage,
                            icon: const Icon(Icons.photo_library),
                            label: const Text('Choose Photo'),
                          ),
                        ),
                      ],
                    ),
                    if (_selectedImage != null) ...[
                      const SizedBox(height: 16),
                      ElevatedButton.icon(
                        onPressed: _analyzeFace,
                        icon: const Icon(Icons.face),
                        label: const Text('Analyze Face Shape'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          foregroundColor: Colors.white,
                        ),
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

            // Size Selector
            SizeSelector(
              sizes: frameSizes,
              selectedSize: _selectedSize,
              onSizeSelected: (size) {
                setState(() {
                  _selectedSize = size;
                });
              },
            ),

            const SizedBox(height: 20),

            // Recommended Frames
            if (_faceShape != null && frameProvider.recommendedFrames.isNotEmpty)
              RecommendationWidget(
                frames: frameProvider.recommendedFrames,
                onFrameSelected: (frame) {
                  setState(() {
                    _selectedFrame = frame.filename;
                  });
                },
                selectedFrame: _selectedFrame,
              ),

            const SizedBox(height: 20),

            // All Frames
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'All Frames',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 10),
                    if (frameProvider.isLoading)
                      const Center(child: CircularProgressIndicator())
                    else if (frameProvider.frames.isEmpty)
                      const Text('No frames available')
                    else
                      GridView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          crossAxisSpacing: 10,
                          mainAxisSpacing: 10,
                          childAspectRatio: 0.8,
                        ),
                        itemCount: frameProvider.frames.length,
                        itemBuilder: (context, index) {
                          final frame = frameProvider.frames[index];
                          return FrameCard(
                            frame: frame,
                            isSelected: _selectedFrame == frame.filename,
                            onTap: () {
                              setState(() {
                                _selectedFrame = frame.filename;
                                _resultImageUrl = null; // Clear previous result when changing frame
                              });
                              print('Selected frame: ${frame.filename}');
                            },
                          );
                        },
                      ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 20),

            // Try Frame Button
            if (_selectedImage != null && _selectedFrame.isNotEmpty)
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _tryFrame,
                  icon: const Icon(Icons.visibility),
                  label: const Text('Try This Frame'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 15),
                    backgroundColor: Colors.orange,
                    foregroundColor: Colors.white,
                  ),
                ),
              ),

            const SizedBox(height: 20),

            // Result Image
            if (_resultImageUrl != null)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      const Text(
                        'Result',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Image.network(
                        _resultImageUrl!,
                        height: 300,
                        fit: BoxFit.cover,
                        loadingBuilder: (context, child, loadingProgress) {
                          if (loadingProgress == null) return child;
                          return Center(
                            child: CircularProgressIndicator(
                              value: loadingProgress.expectedTotalBytes != null
                                  ? loadingProgress.cumulativeBytesLoaded /
                                  loadingProgress.expectedTotalBytes!
                                  : null,
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}