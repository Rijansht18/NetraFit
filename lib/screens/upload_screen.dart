import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'dart:io';
import 'dart:convert';
import 'dart:typed_data';
import '../providers/frame_provider.dart';
import '../services/image_service.dart';
import '../services/api_service.dart';
import '../widgets/frame_card.dart';

class UploadScreen extends StatefulWidget {
  final List<String>? recommendedFrameFilenames;
  final bool showHeader; // Add this parameter

  const UploadScreen({super.key, this.recommendedFrameFilenames, this.showHeader = false});

  @override
  State<UploadScreen> createState() => _UploadScreenState();
}

class _UploadScreenState extends State<UploadScreen> {
  File? _selectedImage;
  String _selectedFrame = '';
  double _sizeValue = 1.0; // 0.8=small, 1.0=medium, 1.2=large
  bool _isProcessing = false;
  Uint8List? _resultImageBytes;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final frameProvider = Provider.of<FrameProvider>(context, listen: false);
      frameProvider.loadFrames().then((_) {
        if (widget.recommendedFrameFilenames != null &&
            widget.recommendedFrameFilenames!.isNotEmpty) {
          setState(() {
            _selectedFrame = widget.recommendedFrameFilenames!.first;
          });
        } else if (frameProvider.frames.isNotEmpty) {
          setState(() {
            _selectedFrame = frameProvider.frames.first.filename;
          });
        }
      });
    });
  }

  String _getSizeKey() {
    if (_sizeValue <= 0.9) return 'small';
    if (_sizeValue <= 1.1) return 'medium';
    return 'large';
  }

  Future<void> _pickImage() async {
    try {
      final image = await ImageService.pickImageFromGallery();
      if (image != null) {
        setState(() {
          _selectedImage = image;
          _resultImageBytes = null;
        });
        _tryFrame();
      }
    } catch (e) {
      Fluttertoast.showToast(msg: 'Error picking image: $e');
    }
  }

  Future<void> _takePhoto() async {
    try {
      final image = await ImageService.captureImageFromCamera();
      if (image != null) {
        setState(() {
          _selectedImage = image;
          _resultImageBytes = null;
        });
        _tryFrame();
      }
    } catch (e) {
      Fluttertoast.showToast(msg: 'Error capturing photo: $e');
    }
  }

  Future<void> _tryFrame() async {
    if (_selectedImage == null || _selectedFrame.isEmpty) {
      Fluttertoast.showToast(msg: 'Please select an image and frame first');
      return;
    }

    setState(() {
      _isProcessing = true;
      _resultImageBytes = null;
    });

    try {
      final result = await ApiService.tryFrame(
        _selectedImage!,
        _selectedFrame,
        _getSizeKey(),
      );

      setState(() {
        _isProcessing = false;
      });

      if (result['success'] == true) {
        if (result.containsKey('processed_image')) {
          final dataUri = result['processed_image'] as String;
          final base64Str = dataUri.split(',').length > 1 ? dataUri.split(',')[1] : dataUri;
          setState(() {
            _resultImageBytes = base64Decode(base64Str);
          });
          Fluttertoast.showToast(msg: 'Frame applied successfully!');
        } else {
          Fluttertoast.showToast(msg: 'Failed: No processed image received');
        }
      } else {
        Fluttertoast.showToast(msg: 'Failed: ${result['error']}');
      }
    } catch (e) {
      setState(() {
        _isProcessing = false;
      });
      Fluttertoast.showToast(msg: 'Error: $e');
    }
  }

  Widget _buildSizeSlider() {
    return Container(
      width: 60,
      height: 200,
      child: Column(
        children: [
          // Vertical Slider
          Expanded(
            child: RotatedBox(
              quarterTurns: 3, // Make it vertical
              child: Slider(
                value: _sizeValue,
                min: 0.8,
                max: 1.2,
                divisions: 4,
                onChanged: (value) {
                  setState(() {
                    _sizeValue = value;
                  });
                },
                onChangeEnd: (value) {
                  if (_selectedImage != null && _selectedFrame.isNotEmpty) {
                    _tryFrame();
                  }
                },
                activeColor: Colors.blue,
                inactiveColor: Colors.grey,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildImageSection() {
    if (_isProcessing) {
      return Expanded(
        flex: 3,
        child: Stack(
          children: [
            Container(
              color: Colors.black,
              child: const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(color: Colors.white),
                    SizedBox(height: 16),
                    Text(
                      'Applying frame...',
                      style: TextStyle(color: Colors.white),
                    ),
                  ],
                ),
              ),
            ),
            Positioned(
              right: 1,
              top: MediaQuery.of(context).size.height * 0.25,
              child: _buildSizeSlider(),
            ),
          ],
        ),
      );
    }

    if (_resultImageBytes != null) {
      return Expanded(
        flex: 3,
        child: Stack(
          children: [
            Container(
              color: Colors.black,
              child: Center(
                child: Image.memory(
                  _resultImageBytes!,
                  fit: BoxFit.contain,
                ),
              ),
            ),
            Positioned(
              right: 1,
              top: MediaQuery.of(context).size.height * 0.25,
              child: _buildSizeSlider(),
            ),
          ],
        ),
      );
    }

    return Expanded(
      flex: 3,
      child: Stack(
        children: [
          Container(
            color: Colors.black,
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.photo_camera,
                    size: 80,
                    color: Colors.grey[300],
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'No photo selected',
                    style: TextStyle(
                      fontSize: 18,
                      color: Colors.grey,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      ElevatedButton.icon(
                        onPressed: _takePhoto,
                        icon: const Icon(Icons.camera_alt),
                        label: const Text('Take Photo'),
                      ),
                      const SizedBox(width: 10),
                      ElevatedButton.icon(
                        onPressed: _pickImage,
                        icon: const Icon(Icons.photo_library),
                        label: const Text('Choose from Gallery'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final frameProvider = Provider.of<FrameProvider>(context);

    return Scaffold(
      appBar: widget.showHeader
          ? AppBar(
        title: const Text('Upload Photo'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
      )
          : null,
      body: Column(
        children: [
          // Image/Result Section
          _buildImageSection(),

          // Frame Selection Section
          Expanded(
            flex: 2,
            child: Container(
              color: Colors.white,
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Text(
                      widget.recommendedFrameFilenames != null &&
                          widget.recommendedFrameFilenames!.isNotEmpty
                          ? 'Recommended Frames'
                          : 'All Frames',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  Expanded(
                    child: frameProvider.isLoading
                        ? const Center(child: CircularProgressIndicator())
                        : _buildFrameList(frameProvider),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFrameList(FrameProvider frameProvider) {
    final framesToShow = widget.recommendedFrameFilenames != null &&
        widget.recommendedFrameFilenames!.isNotEmpty
        ? frameProvider.frames.where((frame) =>
        widget.recommendedFrameFilenames!.contains(frame.filename)).toList()
        : frameProvider.frames;

    if (framesToShow.isEmpty) {
      return const Center(
        child: Text(
          'No frames available',
          style: TextStyle(color: Colors.grey),
        ),
      );
    }

    return ListView.builder(
      scrollDirection: Axis.horizontal,
      itemCount: framesToShow.length,
      itemBuilder: (context, index) {
        final frame = framesToShow[index];
        return Container(
          width: 120,
          margin: const EdgeInsets.symmetric(horizontal: 8),
          child: FrameCard(
            frame: frame,
            isSelected: _selectedFrame == frame.filename,
            onTap: () {
              setState(() {
                _selectedFrame = frame.filename;
              });
              if (_selectedImage != null) {
                _tryFrame();
              }
            },
          ),
        );
      },
    );
  }
}