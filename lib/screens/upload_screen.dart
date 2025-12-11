import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'dart:io';
import 'dart:convert';
import 'dart:typed_data';
import '../models/frame_model.dart';
import '../providers/frame_provider.dart';
import '../services/image_service.dart';
import '../services/api_service.dart';
import '../services/category_service.dart';
import '../screens/FrameDetailsScreen.dart';
import '../providers/auth_provider.dart';
import '../providers/cart_provider.dart';

class UploadScreen extends StatefulWidget {
  final List<String>? recommendedFrameFilenames;
  final String? recommendedFrameId;
  final bool showHeader;

  const UploadScreen({
    super.key,
    this.recommendedFrameFilenames,
    this.recommendedFrameId,
    this.showHeader = false
  });

  @override
  State<UploadScreen> createState() => _UploadScreenState();
}

class _UploadScreenState extends State<UploadScreen> {
  File? _selectedImage;
  String _selectedFrame = '';
  double _sizeValue = 1.0;
  bool _isProcessing = false;
  Uint8List? _resultImageBytes;

  List<Map<String, dynamic>> _categories = [];
  String _selectedCategory = 'all';
  String _selectedCategoryName = 'All';
  Map<String, dynamic>? _selectedFrameData;
  final CategoryService _categoryService = CategoryService();

  @override
  void initState() {
    super.initState();
    print('UploadScreen init - Recommended frames: ${widget.recommendedFrameFilenames}');
    print('UploadScreen init - Recommended frame ID: ${widget.recommendedFrameId}');

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final frameProvider = Provider.of<FrameProvider>(context, listen: false);

      // Load categories
      final categoriesResponse = await _categoryService.getAllMainCategories();
      if (categoriesResponse.success) {
        final categoriesData = categoriesResponse.data['data'] ?? [];
        final List<Map<String, dynamic>> categories = [];

        categories.add({'name': 'All', '_id': 'all'});

        for (var cat in categoriesData) {
          if (cat is Map<String, dynamic>) {
            final categoryName = cat['name']?.toString() ?? 'Category';
            final categoryId = cat['_id']?.toString() ?? '';
            categories.add({
              'name': categoryName,
              '_id': categoryId,
            });
            print('UploadScreen - Loaded category: $categoryName');
          }
        }

        setState(() {
          _categories = categories;
        });
      }

      // Load frames
      await frameProvider.loadFrames();

      print('=== UploadScreen DEBUG: All loaded frames ===');
      for (var frame in frameProvider.frames) {
        print('Frame: ${frame.name}, ID: ${frame.id}, Filename: ${frame.filename}');
      }
      print('===========================================');

      // Try to select the recommended frame
      String frameToSelect = '';
      Frame? selectedFrameObject;

      // First try by ID
      if (widget.recommendedFrameId != null && widget.recommendedFrameId!.isNotEmpty) {
        print('Looking for frame by ID: ${widget.recommendedFrameId}');
        try {
          selectedFrameObject = frameProvider.frames.firstWhere(
                (frame) => frame.id == widget.recommendedFrameId,
          );
          frameToSelect = selectedFrameObject.filename;
          print('Found frame by ID: ${selectedFrameObject.name}, Filename: $frameToSelect');
        } catch (e) {
          print('Frame not found by ID: ${widget.recommendedFrameId}');
        }
      }

      // If not found by ID, try by filename
      if (frameToSelect.isEmpty &&
          widget.recommendedFrameFilenames != null &&
          widget.recommendedFrameFilenames!.isNotEmpty) {
        frameToSelect = widget.recommendedFrameFilenames!.first;
        print('Looking for frame by filename: $frameToSelect');

        final matchingFrames = frameProvider.frames.where(
                (frame) => frame.filename == frameToSelect
        ).toList();

        if (matchingFrames.isNotEmpty) {
          selectedFrameObject = matchingFrames.first;
          print('Found frame by filename: ${selectedFrameObject.name}');
        } else {
          print('WARNING: Frame not found by filename!');
        }
      }

      // If still not found, use first available
      if (frameToSelect.isEmpty && frameProvider.frames.isNotEmpty) {
        selectedFrameObject = frameProvider.frames.first;
        frameToSelect = selectedFrameObject.filename;
        print('Using first available frame: ${selectedFrameObject.name}');
      }

      if (selectedFrameObject != null) {
        setState(() {
          _selectedFrame = frameToSelect;
          _selectedFrameData = {
            'id': selectedFrameObject?.id,
            'name': selectedFrameObject?.name,
            'brand': selectedFrameObject?.brand,
            'price': selectedFrameObject?.price,
            'imageUrls': selectedFrameObject?.imageUrls,
            'description': selectedFrameObject?.description,
            'type': selectedFrameObject?.type,
            'shape': selectedFrameObject?.shape,
            'size': selectedFrameObject?.size,
            'colors': selectedFrameObject?.colors,
            'quantity': selectedFrameObject?.quantity,
            'mainCategory': selectedFrameObject?.mainCategory,
          };
        });
        print('UploadScreen - Selected frame: ${selectedFrameObject.name}');
      }
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
      print('Trying frame: $_selectedFrame, size: ${_getSizeKey()}');

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
      print('Error in _tryFrame: $e');
    }
  }

  Widget _buildModernSizeSlider() {
    return Container(
        width: 60,
        height: 160,
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.7),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              'SIZE',
              style: TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 10),
            Expanded(
              child: RotatedBox(
                quarterTurns: 3,
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
                  activeColor: const Color(0xFF275BCD),
                  inactiveColor: Colors.grey,
                ),
              ),
            ),
            const SizedBox(height: 10),
            Text(
              _getSizeKey().toUpperCase(),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 10,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ));
    }

  Widget _buildPhotoButton({
    required IconData icon,
    required String label,
    required VoidCallback onPressed,
  }) {
    return Column(
      children: [
        Container(
          width: 60,
          height: 60,
          decoration: BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.2),
                blurRadius: 6,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: IconButton(
            onPressed: onPressed,
            icon: Icon(icon, size: 28, color: Colors.black),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            color: Colors.white,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildImagePreview() {
    if (_isProcessing) {
      return Container(
        color: Colors.black,
        child: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(color: Color(0xFF275BCD)),
              SizedBox(height: 16),
              Text(
                'Applying frame...',
                style: TextStyle(color: Colors.white),
              ),
            ],
          ),
        ),
      );
    }

    if (_resultImageBytes != null) {
      return Container(
        color: Colors.black,
        child: Center(
          child: Image.memory(
            _resultImageBytes!,
            fit: BoxFit.contain,
          ),
        ),
      );
    }

    if (_selectedImage != null) {
      return Container(
        decoration: BoxDecoration(
          image: DecorationImage(
            image: FileImage(_selectedImage!),
            fit: BoxFit.cover,
          ),
        ),
      );
    }

    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.photo_camera,
            size: 60,
            color: Colors.grey,
          ),
          SizedBox(height: 16),
          Text(
            'No photo selected',
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey,
            ),
          ),
        ],
      ),
    );
  }

  List<dynamic> _getFilteredFrames(FrameProvider frameProvider) {
    if (_selectedCategory == 'all') {
      return frameProvider.frames;
    }

    return frameProvider.frames.where((frame) {
      if (frame.mainCategory is Map<String, dynamic>) {
        final mainCat = frame.mainCategory as Map<String, dynamic>;
        final categoryName = mainCat['name']?.toString() ?? '';
        return categoryName == _selectedCategoryName;
      }
      final frameCategory = frame.mainCategory?.toString() ?? '';
      return frameCategory == _selectedCategory;
    }).toList();
  }

  void _selectCategory(String categoryId, String categoryName) {
    setState(() {
      _selectedCategory = categoryId;
      _selectedCategoryName = categoryName;
    });
  }

  void _changeFrame(String frameFilename, FrameProvider frameProvider) {
    print('UploadScreen - Changing frame to: $frameFilename');
    setState(() {
      _selectedFrame = frameFilename;
      final selectedFrame = frameProvider.frames.firstWhere(
            (frame) => frame.filename == frameFilename,
      );
      _selectedFrameData = {
        'id': selectedFrame.id,
        'name': selectedFrame.name,
        'brand': selectedFrame.brand,
        'price': selectedFrame.price,
        'imageUrls': selectedFrame.imageUrls,
        'description': selectedFrame.description,
        'type': selectedFrame.type,
        'shape': selectedFrame.shape,
        'size': selectedFrame.size,
        'colors': selectedFrame.colors,
        'quantity': selectedFrame.quantity,
        'mainCategory': selectedFrame.mainCategory,
      };
    });
    if (_selectedImage != null) {
      _tryFrame();
    }
  }

  @override
  Widget build(BuildContext context) {
    final frameProvider = Provider.of<FrameProvider>(context);
    final frames = _getFilteredFrames(frameProvider);

    return Scaffold(
      backgroundColor: Colors.white,
      body: Column(
        children: [
          // Image Preview Section
          Expanded(
            flex: 3,
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: Colors.grey[900],
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Stack(
                children: [
                  _buildImagePreview(),

                  // Size slider on right
                  Positioned(
                    right: 8,
                    top: MediaQuery.of(context).size.height * 0.25,
                    child: _buildModernSizeSlider(),
                  ),

                  // Camera/Gallery buttons at bottom
                  if (_selectedImage == null)
                    Positioned(
                      bottom: 20,
                      left: 0,
                      right: 0,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          _buildPhotoButton(
                            icon: Icons.camera_alt,
                            label: 'Take Photo',
                            onPressed: _takePhoto,
                          ),
                          _buildPhotoButton(
                            icon: Icons.photo_library,
                            label: 'Choose from Gallery',
                            onPressed: _pickImage,
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Category Filter
          SizedBox(
            height: 50,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: _categories.length,
              itemBuilder: (context, index) {
                final category = _categories[index];
                final isSelected = _selectedCategory == category['_id'];

                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(category['name']),
                    selected: isSelected,
                    onSelected: (selected) {
                      _selectCategory(category['_id'], category['name']);
                    },
                    selectedColor: const Color(0xFF275BCD),
                    labelStyle: TextStyle(
                      color: isSelected ? Colors.white : Colors.black,
                    ),
                  ),
                );
              },
            ),
          ),

          // Frame Selection Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Frames (${frames.length})',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                  ),
                ),
                Text(
                  'Size: ${_getSizeKey().toUpperCase()}',
                  style: const TextStyle(
                    fontSize: 14,
                    color: Colors.grey,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 8),

          // Frames List
          SizedBox(
            height: 140,
            child: frameProvider.isLoading
                ? const Center(child: CircularProgressIndicator())
                : _buildFrameSelectionSection(frameProvider, frames),
          ),

          const SizedBox(height: 16),

          // Action Buttons
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      if (_selectedFrameData != null) {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => FrameDetailsScreen(
                              frameId: _selectedFrameData!['id'],
                              frame: Frame.fromJson({
                                '_id': _selectedFrameData!['id'],
                                'name': _selectedFrameData!['name'],
                                'brand': _selectedFrameData!['brand'],
                                'price': _selectedFrameData!['price'],
                                'imageUrls': _selectedFrameData!['imageUrls'],
                                'description': _selectedFrameData!['description'],
                                'type': _selectedFrameData!['type'],
                                'shape': _selectedFrameData!['shape'],
                                'size': _selectedFrameData!['size'],
                                'colors': _selectedFrameData!['colors'],
                                'quantity': _selectedFrameData!['quantity'],
                                'isActive': true,
                                'mainCategory': _selectedFrameData!['mainCategory'],
                                'filename': _selectedFrame,
                              }),
                            ),
                          ),
                        );
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Please select a frame first'),
                            backgroundColor: Colors.red,
                            duration: Duration(seconds: 2),
                          ),
                        );
                      }
                    },
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF275BCD),
                      side: const BorderSide(color: Color(0xFF275BCD)),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    icon: const Icon(Icons.remove_red_eye),
                    label: const Text(
                      'View Details',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () async {
                      if (_selectedFrameData != null) {
                        final authProvider = Provider.of<AuthProvider>(context, listen: false);
                        final cartProvider = Provider.of<CartProvider>(context, listen: false);
                        final token = authProvider.token;

                        if (token == null) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Please login to add items to cart'),
                              backgroundColor: Colors.red,
                              duration: Duration(seconds: 2),
                            ),
                          );
                          return;
                        }

                        final success = await cartProvider.addToCart(
                          token: token,
                          frameId: _selectedFrameData!['id'],
                          quantity: 1,
                        );

                        if (success) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Added ${_selectedFrameData!['name']} to cart'),
                              backgroundColor: Colors.green,
                              duration: const Duration(seconds: 2),
                            ),
                          );
                        } else {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(cartProvider.errorMessage ?? 'Failed to add to cart'),
                              backgroundColor: Colors.red,
                              duration: const Duration(seconds: 2),
                            ),
                          );
                        }
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Please select a frame first'),
                            backgroundColor: Colors.red,
                            duration: Duration(seconds: 2),
                          ),
                        );
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF275BCD),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    icon: const Icon(Icons.add_shopping_cart),
                    label: const Text(
                      'Add to Cart',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildFrameSelectionSection(FrameProvider frameProvider, List<dynamic> frames) {
    if (frames.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.visibility_off, size: 48, color: Colors.grey),
            const SizedBox(height: 8),
            Text(
              _selectedCategory == 'all'
                  ? 'No frames available'
                  : 'No frames in $_selectedCategoryName category',
              style: const TextStyle(color: Colors.grey, fontSize: 16),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: frames.length,
      itemBuilder: (context, index) {
        final frame = frames[index];
        return _buildFrameCard(context, frame, frameProvider);
      },
    );
  }

  Widget _buildFrameCard(BuildContext context, dynamic frame, FrameProvider frameProvider) {
    return GestureDetector(
      onTap: () => _changeFrame(frame.filename, frameProvider),
      child: Container(
        width: 140,
        margin: const EdgeInsets.only(right: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: _selectedFrame == frame.filename
                ? const Color(0xFF275BCD)
                : Colors.grey[200]!,
            width: 2,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Frame Image
            Container(
              height: 100,
              width: double.infinity,
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(10),
                  topRight: Radius.circular(10),
                ),
              ),
              child: Center(
                child: frame.imageUrls.isNotEmpty
                    ? Image.network(
                  frame.imageUrls.first,
                  fit: BoxFit.contain,
                  width: 80,
                  height: 60,
                )
                    : const Icon(Icons.image, color: Colors.grey, size: 40),
              ),
            ),

            // Frame Info
            Padding(
              padding: const EdgeInsets.all(8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    frame.name,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Colors.black,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}