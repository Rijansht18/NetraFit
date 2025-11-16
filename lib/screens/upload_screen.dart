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
  String? _resultImageUrl;
  Uint8List? _resultImageBytes;

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
      final frameProvider = Provider.of<FrameProvider>(context, listen: false);
      frameProvider.loadFrames().then((_) {
        // If recommended frames are provided, filter to show only those
        if (widget.recommendedFrameFilenames != null && widget.recommendedFrameFilenames!.isNotEmpty) {
          // Select first recommended frame
          if (widget.recommendedFrameFilenames!.isNotEmpty) {
            setState(() {
              _selectedFrame = widget.recommendedFrameFilenames!.first;
            });
          }
        } else if (frameProvider.frames.isNotEmpty) {
          // Select first available frame
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
          _resultImageUrl = null;
        });
        // Auto-try frame when image is selected
        if (_selectedFrame.isNotEmpty) {
          _tryFrame();
        }
      }
    } catch (e) {
      Fluttertoast.showToast(msg: 'Error picking image: $e');
    }
  }


  Future<void> _tryFrame() async {
    if (_selectedImage == null || _selectedFrame.isEmpty) {
      print('⚠ Cannot try frame: image=${_selectedImage != null}, frame=${_selectedFrame.isNotEmpty}');
      Fluttertoast.showToast(msg: 'Please select an image and frame first');
      return;
    }

    print('🖼️ Trying frame: $_selectedFrame with size: $_selectedSize');
    print('  - Selected frame: $_selectedFrame');
    print('  - Selected size: $_selectedSize');
    print('  - Image path: ${_selectedImage!.path}');

    setState(() {
      _isProcessing = true;
      // Clear previous result when starting new processing
      _resultImageUrl = null;
    });

    try {
      final result = await ApiService.tryFrame(
        _selectedImage!,
        _selectedFrame,
        _selectedSize,
      );

      print('📥 API Response: success=${result['success']}');

      setState(() {
        _isProcessing = false;
      });

        setState(() {
          _isProcessing = false;
        });

        if (result['success'] == true) {
          // If server returned processed_image (data URI), use it in-memory
          if (result.containsKey('processed_image')) {
            final dataUri = result['processed_image'] as String;
            // Data URI format: data:image/jpeg;base64,....
            final base64Str = dataUri.split(',').length > 1 ? dataUri.split(',')[1] : dataUri;
            setState(() {
              _resultImageBytes = base64Decode(base64Str);
              _resultImageUrl = null;
            });
          } else if (result.containsKey('result_url')) {
            setState(() {
              _resultImageUrl = result['result_url'];
              _resultImageBytes = null;
            });
          }

          Fluttertoast.showToast(msg: 'Frame applied successfully!');
        } else {
          Fluttertoast.showToast(msg: 'Failed: ${result['error']}');
        }
    } catch (e, stackTrace) {
      print('✗ Error trying frame: $e');
      print('Stack trace: $stackTrace');
      setState(() {
        _isProcessing = false;
      });
      Fluttertoast.showToast(msg: 'Error: $e');
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
                // Auto-try frame when size changes
                if (_selectedImage != null && _selectedFrame.isNotEmpty) {
                  _tryFrame();
                }
              },
            ),

            const SizedBox(height: 20),

            // Frames (Recommended or All)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.recommendedFrameFilenames != null && widget.recommendedFrameFilenames!.isNotEmpty
                          ? 'Recommended Frames'
                          : 'All Frames',
                      style: const TextStyle(
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
                      Builder(
                        builder: (context) {
                          // Filter frames if recommended frames are provided
                          final framesToShow = widget.recommendedFrameFilenames != null && widget.recommendedFrameFilenames!.isNotEmpty
                              ? frameProvider.frames.where((frame) => widget.recommendedFrameFilenames!.contains(frame.filename)).toList()
                              : frameProvider.frames;
                          
                          if (framesToShow.isEmpty) {
                            return const Text('No frames available');
                          }
                          
                          return GridView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 2,
                              crossAxisSpacing: 10,
                              mainAxisSpacing: 10,
                              childAspectRatio: 0.8,
                            ),
                            itemCount: framesToShow.length,
                            itemBuilder: (context, index) {
                              final frame = framesToShow[index];
                              return FrameCard(
                                frame: frame,
                                isSelected: _selectedFrame == frame.filename,
                                onTap: () {
                                  print('🖼️ Frame selected: ${frame.filename}');
                                  setState(() {
                                    _selectedFrame = frame.filename;
                                    _resultImageUrl = null;
                                  });
                                  // Auto-try frame when selected
                                  if (_selectedImage != null) {
                                    _tryFrame();
                                  }
                                },
                              );
                            },
                          );
                        },
                      ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 20),

            // Result Image (either from URL or in-memory bytes)
            if (_resultImageBytes != null)
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
                      Image.memory(
                        _resultImageBytes!,
                        height: 300,
                        fit: BoxFit.cover,
                      ),
                    ],
                  ),
                ),
              )
            else if (_resultImageUrl != null)
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