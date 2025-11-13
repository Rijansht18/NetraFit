import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:provider/provider.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'dart:convert';
import '../providers/frame_provider.dart';
import '../services/camera_service.dart';
import '../widgets/frame_card.dart';
import '../widgets/size_selector.dart';

class RealTimeScreen extends StatefulWidget {
  final List<String>? recommendedFrameFilenames;
  
  const RealTimeScreen({super.key, this.recommendedFrameFilenames});

  @override
  State<RealTimeScreen> createState() => _RealTimeScreenState();
}

class _RealTimeScreenState extends State<RealTimeScreen> {
  late CameraService _cameraService;
  String _selectedFrame = '';
  String _selectedSize = 'medium';
  String? _processedImage;
  bool _isProcessing = false;
  bool _isCameraInitialized = false;

  final Map<String, String> frameSizes = {
    'small': 'Small',
    'medium': 'Medium',
    'large': 'Large',
  };

  @override
  void initState() {
    super.initState();
    _cameraService = CameraService();
    _initializeCamera();

    // Load frames
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final frameProvider = Provider.of<FrameProvider>(context, listen: false);
      frameProvider.loadFrames().then((_) {
        final frames = frameProvider.frames;
        if (frames.isNotEmpty && _selectedFrame.isEmpty) {
          // If recommended frames are provided, use first recommended frame
          if (widget.recommendedFrameFilenames != null && widget.recommendedFrameFilenames!.isNotEmpty) {
            setState(() {
              _selectedFrame = widget.recommendedFrameFilenames!.first;
            });
          } else {
            setState(() {
              _selectedFrame = frames.first.filename;
            });
          }
          // Auto-start processing when frame is selected
          if (_isCameraInitialized) {
            _startRealtimeProcessing();
          }
        }
      });
    });
  }

  Future<void> _initializeCamera() async {
    try {
      print('🔄 Initializing camera in RealTimeScreen...');
      await _cameraService.initializeCamera();
      
      if (_cameraService.isInitialized && _cameraService.controller != null) {
        print('✓ Camera initialized successfully in RealTimeScreen');
        print('  - Controller initialized: ${_cameraService.controller!.value.isInitialized}');
        print('  - Preview size: ${_cameraService.controller!.value.previewSize}');
        
        setState(() {
          _isCameraInitialized = true;
        });
        
        // Auto-start processing if frame is already selected
        if (_selectedFrame.isNotEmpty) {
          Future.delayed(const Duration(milliseconds: 500), () {
            if (mounted) {
              _startRealtimeProcessing();
            }
          });
        }
      } else {
        throw Exception('Camera controller is null or not initialized');
      }
    } catch (e) {
      print('✗ Camera initialization failed in RealTimeScreen: $e');
      final errorMsg = _cameraService.initializationError ?? 'Camera initialization failed: $e';
      setState(() {
        _isCameraInitialized = false;
      });
      Fluttertoast.showToast(
        msg: errorMsg.length > 50 ? 'Camera initialization failed' : errorMsg,
        toastLength: Toast.LENGTH_LONG,
      );
    }
  }

  void _startRealtimeProcessing() {
    if (_selectedFrame.isEmpty) {
      return; // Wait for frame selection
    }

    if (!_isCameraInitialized) {
      return; // Wait for camera initialization
    }

    if (_isProcessing) {
      return; // Already processing
    }

    setState(() {
      _isProcessing = true;
    });

    _processFramesLoop();
  }

  void _stopRealtimeProcessing() {
    setState(() {
      _isProcessing = false;
      _processedImage = null;
    });
  }

  Future<void> _processFramesLoop() async {
    while (_isProcessing) {
      try {
        final result = await _cameraService.captureAndProcessFrame(
          frameFilename: _selectedFrame,
          size: _selectedSize,
        );

        if (mounted && _isProcessing) {
          setState(() {
            if (result['success'] == true) {
              _processedImage = result['processed_image'];
            }
          });
        }
      } catch (e) {
        print('✗ Error processing frame: $e');
        // Continue processing even on error
      }

      // Optimized delay - faster processing for smoother experience
      await Future.delayed(const Duration(milliseconds: 300));
    }
  }

  void _onFrameChanged(String newFrame) {
    if (newFrame != _selectedFrame) {
      setState(() {
        _selectedFrame = newFrame;
      });
      // Frame change will be picked up in next processing cycle
    }
  }

  void _onSizeChanged(String newSize) {
    if (newSize != _selectedSize) {
      setState(() {
        _selectedSize = newSize;
      });
      // Size change will be picked up in next processing cycle
    }
  }

  String _getFrameDisplayName(String filename) {
    return filename.split('.').first.replaceAll('_', ' ').toUpperCase();
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

    // CameraPreview handles sizing automatically
    return SizedBox.expand(
      child: CameraPreview(controller),
    );
  }

  Widget _buildProcessedImage() {
    if (_processedImage == null) {
      return const SizedBox.shrink();
    }

    // Handle base64 data URL
    try {
      // Check if it's a base64 data URL
      if (_processedImage!.startsWith('data:image')) {
        // Extract base64 part
        final base64String = _processedImage!.split(',')[1];
        final imageBytes = base64Decode(base64String);
        
        return Image.memory(
          imageBytes,
          fit: BoxFit.cover,
          width: double.infinity,
          height: double.infinity,
          gaplessPlayback: true, // Smooth transitions between frames
        );
      } else {
        // Regular network image
        return Image.network(
          _processedImage!,
          fit: BoxFit.cover,
          width: double.infinity,
          height: double.infinity,
          gaplessPlayback: true,
          loadingBuilder: (context, child, loadingProgress) {
            if (loadingProgress == null) return child;
            return const SizedBox.shrink();
          },
          errorBuilder: (context, error, stackTrace) {
            return const SizedBox.shrink();
          },
        );
      }
    } catch (e) {
      return const SizedBox.shrink();
    }
  }

  @override
  void dispose() {
    _stopRealtimeProcessing();
    _cameraService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final frameProvider = Provider.of<FrameProvider>(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Real-time Try-On'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        actions: [
          if (_isProcessing)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.green.withOpacity(0.2),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.circle, color: Colors.green, size: 12),
                  SizedBox(width: 6),
                  Text(
                    'LIVE',
                    style: TextStyle(
                      color: Colors.green,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
      body: Column(
        children: [
          // Camera Preview and Processed Image
          Expanded(
            flex: 3,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.black,
                border: Border.all(color: Colors.grey),
              ),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  // Camera Preview (show when not processing)
                  if (_isCameraInitialized && !_isProcessing && _cameraService.controller != null)
                    _buildCameraPreview(),

                  // Processed Image (show when processing) - replaces camera preview
                  if (_processedImage != null && _isProcessing)
                    Positioned.fill(
                      child: _buildProcessedImage(),
                    ),

                  // Frame Info Overlay
                  if (_isProcessing && _selectedFrame.isNotEmpty)
                    Positioned(
                      top: 10,
                      left: 10,
                      right: 10,
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.7),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.photo, size: 16, color: Colors.white),
                            const SizedBox(width: 8),
                            Text(
                              'Frame: ${_getFrameDisplayName(_selectedFrame)}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                  // Processing Indicator
                  if (_isProcessing)
                    Positioned(
                      bottom: 15,
                      right: 15,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.green.withOpacity(0.9),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Row(
                          children: [
                            Icon(Icons.circle, color: Colors.white, size: 12),
                            SizedBox(width: 6),
                            Text(
                              'LIVE',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                  // Camera not initialized message
                  if (!_isCameraInitialized)
                    Container(
                      color: Colors.black,
                      child: Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const CircularProgressIndicator(color: Colors.white),
                            const SizedBox(height: 16),
                            Text(
                              _cameraService.initializationError != null
                                  ? 'Camera Error'
                                  : 'Initializing Camera...',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                              ),
                            ),
                            if (_cameraService.initializationError != null) ...[
                              const SizedBox(height: 8),
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 32),
                                child: Text(
                                  _cameraService.initializationError!,
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: Colors.red[300],
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 16),
                              ElevatedButton.icon(
                                onPressed: _initializeCamera,
                                icon: const Icon(Icons.refresh),
                                label: const Text('Retry'),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),

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
                    onSizeSelected: _onSizeChanged,
                  ),

                  const SizedBox(height: 16),

                  // Frame Selection
                  Container(
                    height: 140,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Select Frame:',
                          style: TextStyle(
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
                                    // Filter frames if recommended frames are provided
                                    final framesToShow = widget.recommendedFrameFilenames != null && widget.recommendedFrameFilenames!.isNotEmpty
                                        ? frameProvider.frames.where((frame) => widget.recommendedFrameFilenames!.contains(frame.filename)).toList()
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
                                            onTap: () => _onFrameChanged(frame.filename),
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

                        const SizedBox(height: 16),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}