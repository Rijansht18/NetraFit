import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:provider/provider.dart';
import 'package:fluttertoast/fluttertoast.dart';
import '../providers/frame_provider.dart';
import '../services/camera_service.dart';
import '../widgets/frame_card.dart';
import '../widgets/size_selector.dart';

class RealTimeScreen extends StatefulWidget {
  const RealTimeScreen({super.key});

  @override
  State<RealTimeScreen> createState() => _RealTimeScreenState();
}

class _RealTimeScreenState extends State<RealTimeScreen> {
  late CameraService _cameraService;
  String _selectedFrame = '';
  String _selectedSize = 'medium';
  String? _processedImage;
  String _faceShape = 'Unknown';
  String _distanceMessage = 'No face detected';
  String _distanceStatus = 'unknown';
  bool _isProcessing = false;
  bool _isCameraInitialized = false;
  bool _showCameraPreview = true;

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
      Provider.of<FrameProvider>(context, listen: false).loadFrames().then((_) {
        final frames = Provider.of<FrameProvider>(context, listen: false).frames;
        if (frames.isNotEmpty && _selectedFrame.isEmpty) {
          setState(() {
            _selectedFrame = frames.first.filename;
          });
        }
      });
    });
  }

  Future<void> _initializeCamera() async {
    try {
      await _cameraService.initializeCamera();
      setState(() {
        _isCameraInitialized = true;
      });
    } catch (e) {
      print('Camera initialization failed: $e');
      Fluttertoast.showToast(msg: 'Camera initialization failed');
    }
  }

  void _startRealtimeProcessing() {
    if (_selectedFrame.isEmpty) {
      Fluttertoast.showToast(msg: 'Please select a frame first');
      return;
    }

    if (!_isCameraInitialized) {
      Fluttertoast.showToast(msg: 'Camera not ready');
      return;
    }

    setState(() {
      _isProcessing = true;
      _showCameraPreview = false;
    });

    _processFramesLoop();
  }

  void _stopRealtimeProcessing() {
    setState(() {
      _isProcessing = false;
      _showCameraPreview = true;
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
              _faceShape = result['face_shape'] ?? 'Unknown';
              _distanceMessage = result['distance_message'] ?? 'No face detected';
              _distanceStatus = result['distance_status'] ?? 'unknown';
            } else {
              _faceShape = 'Error';
              _distanceMessage = result['error'] ?? 'Processing failed';
              _distanceStatus = 'error';
            }
          });
        }
      } catch (e) {
        if (mounted && _isProcessing) {
          setState(() {
            _faceShape = 'Error';
            _distanceMessage = 'Processing error: $e';
            _distanceStatus = 'error';
          });
        }
      }

      // Add delay between frames (2 FPS for better performance)
      await Future.delayed(const Duration(milliseconds: 500));
    }
  }

  void _onFrameChanged(String newFrame) {
    if (newFrame != _selectedFrame) {
      setState(() {
        _selectedFrame = newFrame;
      });

      // Restart processing if active
      if (_isProcessing) {
        _stopRealtimeProcessing();
        Future.delayed(const Duration(milliseconds: 300), () {
          if (mounted) {
            _startRealtimeProcessing();
          }
        });
      }
    }
  }

  void _onSizeChanged(String newSize) {
    if (newSize != _selectedSize) {
      setState(() {
        _selectedSize = newSize;
      });

      // Restart processing if active
      if (_isProcessing) {
        _stopRealtimeProcessing();
        Future.delayed(const Duration(milliseconds: 300), () {
          if (mounted) {
            _startRealtimeProcessing();
          }
        });
      }
    }
  }

  Color _getStatusColor() {
    switch (_distanceStatus) {
      case 'optimal':
        return Colors.green;
      case 'too_close':
        return Colors.orange;
      case 'too_far':
        return Colors.red;
      case 'error':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  String _getFrameDisplayName(String filename) {
    return filename.split('.').first.replaceAll('_', ' ').toUpperCase();
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
            IconButton(
              icon: const Icon(Icons.stop),
              onPressed: _stopRealtimeProcessing,
              tooltip: 'Stop Processing',
            )
          else
            IconButton(
              icon: const Icon(Icons.play_arrow),
              onPressed: _startRealtimeProcessing,
              tooltip: 'Start Processing',
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
                  // Camera Preview (only show when not processing)
                  if (_isCameraInitialized && _showCameraPreview)
                    CameraPreview(_cameraService.controller!),

                  // Processed Image (only show when processing)
                  if (_processedImage != null && _isProcessing)
                    Image.network(
                      _processedImage!,
                      fit: BoxFit.cover,
                      width: double.infinity,
                      height: double.infinity,
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
                      errorBuilder: (context, error, stackTrace) {
                        return Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.error, color: Colors.red, size: 50),
                              const SizedBox(height: 10),
                              Text(
                                'Image load error',
                                style: TextStyle(color: Colors.red[300]),
                              ),
                            ],
                          ),
                        );
                      },
                    ),

                  // Status Overlay
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
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.face, size: 16, color: Colors.white),
                              const SizedBox(width: 8),
                              Text(
                                'Face: $_faceShape',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(
                            _distanceMessage,
                            style: TextStyle(
                              color: _getStatusColor(),
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          if (_isProcessing) ...[
                            const SizedBox(height: 6),
                            Row(
                              children: [
                                const Icon(Icons.photo, size: 14, color: Colors.white),
                                const SizedBox(width: 6),
                                Text(
                                  'Frame: ${_getFrameDisplayName(_selectedFrame)}',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ],
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
                              : frameProvider.frames.isEmpty
                              ? const Center(
                            child: Text(
                              'No frames available',
                              style: TextStyle(color: Colors.grey),
                            ),
                          )
                              : ListView.builder(
                            scrollDirection: Axis.horizontal,
                            itemCount: frameProvider.frames.length,
                            itemBuilder: (context, index) {
                              final frame = frameProvider.frames[index];
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
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Control Buttons
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: _isProcessing ? _stopRealtimeProcessing : _startRealtimeProcessing,
                          icon: Icon(_isProcessing ? Icons.stop : Icons.play_arrow),
                          label: Text(_isProcessing ? 'Stop Real-time' : 'Start Real-time'),
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            backgroundColor: _isProcessing ? Colors.red : Colors.green,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),

                  // Status Information
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.blue[50],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.info,
                              color: Colors.blue[700],
                              size: 18,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              _isProcessing ? 'Live Processing' : 'Ready to Start',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.blue[700],
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          _isProcessing
                              ? '• Processing at 2 FPS\n'
                              '• Frame: ${_getFrameDisplayName(_selectedFrame)}\n'
                              '• Size: ${frameSizes[_selectedSize]}\n'
                              '• Face: $_faceShape\n'
                              '• $_distanceMessage'
                              : '1. Select a frame and size\n'
                              '2. Click "Start Real-time"\n'
                              '3. Position face in camera\n'
                              '4. Move to optimal distance (40-70cm)',
                          style: const TextStyle(fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}