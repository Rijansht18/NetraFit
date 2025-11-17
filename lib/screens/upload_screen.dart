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
import '../widgets/size_selector.dart';

class UploadScreen extends StatefulWidget {
  final List<String>? recommendedFrameFilenames;

  const UploadScreen({super.key, this.recommendedFrameFilenames});

  @override
  State<UploadScreen> createState() => _UploadScreenState();
}

class _UploadScreenState extends State<UploadScreen> {
  File? _selectedImage;
  String _selectedFrame = '';
  String _selectedSize = 'medium';
  bool _isProcessing = false;
  Uint8List? _resultImageBytes;

  final Map<String, String> frameSizes = {
    'small': 'Small',
    'medium': 'Medium',
    'large': 'Large',
  };

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
        _selectedSize,
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

  Widget _buildImageSection() {
    if (_isProcessing) {
      return const Expanded(
        flex: 3,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('Applying frame...'),
            ],
          ),
        ),
      );
    }

    if (_resultImageBytes != null) {
      return Expanded(
        flex: 3,
        child: Card(
          margin: const EdgeInsets.all(16),
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
                Expanded(
                  child: Image.memory(
                    _resultImageBytes!,
                    fit: BoxFit.contain,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Expanded(
      flex: 3,
      child: Card(
        margin: const EdgeInsets.all(16),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
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
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _takePhoto,
                      icon: const Icon(Icons.camera_alt),
                      label: const Text('Take Photo'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _pickImage,
                      icon: const Icon(Icons.photo_library),
                      label: const Text('Choose from Gallery'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final frameProvider = Provider.of<FrameProvider>(context);

    return Column(
      children: [
        // Image/Result Section
        _buildImageSection(),

        // Controls Section
        Expanded(
          flex: 2,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                // Size Selector
                SizeSelector(
                  sizes: frameSizes,
                  selectedSize: _selectedSize,
                  onSizeSelected: (size) {
                    setState(() {
                      _selectedSize = size;
                    });
                    if (_selectedImage != null && _selectedFrame.isNotEmpty) {
                      _tryFrame();
                    }
                  },
                ),

                const SizedBox(height: 16),

                // Frame Selection
                Container(
                  height: 140,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.recommendedFrameFilenames != null &&
                            widget.recommendedFrameFilenames!.isNotEmpty
                            ? 'Recommended Frames'
                            : 'All Frames',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Expanded(
                        child: frameProvider.isLoading
                            ? const Center(child: CircularProgressIndicator())
                            : Builder(
                          builder: (context) {
                            final framesToShow =
                            widget.recommendedFrameFilenames != null &&
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
                                  width: 110,
                                  margin: const EdgeInsets.only(right: 8),
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
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}