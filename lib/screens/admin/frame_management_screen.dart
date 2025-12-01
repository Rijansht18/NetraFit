import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../services/frame_service.dart';
import '../../services/category_service.dart';
import '../../models/api_response.dart';
import '../../models/frame_model.dart';

class FrameManagementScreen extends StatefulWidget {
  const FrameManagementScreen({Key? key}) : super(key: key);

  @override
  State<FrameManagementScreen> createState() => _FrameManagementScreenState();
}

class _FrameManagementScreenState extends State<FrameManagementScreen> {
  final FrameService _frameService = FrameService();
  final CategoryService _categoryService = CategoryService();
  final ImagePicker _imagePicker = ImagePicker();

  List<Frame> _frames = [];
  List<dynamic> _mainCategories = [];
  List<dynamic> _subCategories = [];
  bool _isLoading = true;

  // Controllers
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _brandController = TextEditingController();
  final TextEditingController _priceController = TextEditingController();
  final TextEditingController _quantityController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();

  // Form state
  String? _selectedMainCategory;
  String? _selectedSubCategory;
  String? _selectedType;
  String? _selectedShape;
  String? _selectedSize;
  String? _selectedColor;
  List<String> _selectedColors = [];
  List<XFile> _selectedImages = [];
  XFile? _selectedOverlayImage;

  // For edit mode
  Frame? _editingFrame;
  List<String> _existingImageUrls = [];
  String? _existingOverlayUrl;

  final List<String> _frameTypes = ['full_rim', 'half_rim', 'rimless'];
  final List<String> _frameShapes = [
    'round', 'rectangle', 'square', 'aviator',
    'wayfarer', 'cate_eye', 'geometric', 'oval', 'browline'
  ];

  // Updated colors list for dropdown
  final List<String> _availableColors = [
    'Black', 'Brown', 'Silver', 'Gold', 'Blue', 'Red', 'Green',
    'Pink', 'Purple', 'White', 'Transparent', 'Tortoise', 'Navy',
    'Grey', 'Bronze', 'Rose Gold', 'Gunmetal', 'Crystal'
  ];

  @override
  void initState() {
    super.initState();
    _loadFrames();
    _loadCategories();
  }

  Future<void> _loadFrames() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final ApiResponse response = await _frameService.getAllFrames();
      if (response.success == true) {
        final framesData = response.data?['data'] as List? ?? [];
        setState(() {
          _frames = framesData.map((frameData) => Frame.fromJson(frameData)).toList();
        });
      } else {
        _showErrorDialog(response.error ?? 'Failed to load frames');
      }
    } catch (e) {
      _showErrorDialog('Network error: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _loadCategories() async {
    try {
      final mainCatResponse = await _categoryService.getAllMainCategories();
      final subCatResponse = await _categoryService.getAllSubCategories();

      if (mainCatResponse.success == true) {
        setState(() {
          _mainCategories = mainCatResponse.data?['data'] ?? [];
        });
      }

      if (subCatResponse.success == true) {
        setState(() {
          _subCategories = subCatResponse.data?['data'] ?? [];
        });
      }
    } catch (e) {
      print('Error loading categories: $e');
    }
  }

  List<dynamic> _getSubCategoriesForMain(String mainCategoryId) {
    return _subCategories.where((subCat) =>
    subCat['mainCategory']?['_id'] == mainCategoryId ||
        subCat['mainCategory'] == mainCategoryId
    ).toList();
  }

  Future<void> _createFrame() async {
    if (!_validateForm()) return;

    try {
      final textFields = {
        'name': _nameController.text.trim(),
        'brand': _brandController.text.trim(),
        'mainCategory': _selectedMainCategory,
        'subCategory': _selectedSubCategory,
        'type': _selectedType,
        'shape': _selectedShape,
        'price': double.parse(_priceController.text),
        'quantity': int.parse(_quantityController.text),
        'colors': _selectedColors,
        'size': _selectedSize,
        'description': _descriptionController.text.trim(),
      };

      final ApiResponse response = await _frameService.createFrameWithImages(
        textFields: textFields,
        productImages: _selectedImages,
        overlayImage: _selectedOverlayImage!,
      );

      if (response.success == true) {
        _showSuccessDialog('Frame created successfully');
        _resetForm();
        _loadFrames();
      } else {
        _showErrorDialog(response.error ?? 'Failed to create frame');
      }
    } catch (e) {
      _showErrorDialog('Network error: $e');
    }
  }

  Future<void> _updateFrame(String frameId) async {
    if (!_validateFormForUpdate()) return;

    try {
      final textFields = {
        'name': _nameController.text.trim(),
        'brand': _brandController.text.trim(),
        'mainCategory': _selectedMainCategory,
        'subCategory': _selectedSubCategory,
        'type': _selectedType,
        'shape': _selectedShape,
        'price': double.parse(_priceController.text),
        'quantity': int.parse(_quantityController.text),
        'colors': _selectedColors,
        'size': _selectedSize,
        'description': _descriptionController.text.trim(),
      };

      final ApiResponse response = await _frameService.updateFrameWithImages(
        frameId: frameId,
        textFields: textFields,
        newProductImages: _selectedImages.isNotEmpty ? _selectedImages : null,
        newOverlayImage: _selectedOverlayImage != null ? _selectedOverlayImage : null,
      );

      if (response.success == true) {
        _showSuccessDialog('Frame updated successfully');
        _resetForm();
        _loadFrames();
      } else {
        _showErrorDialog(response.error ?? 'Failed to update frame');
      }
    } catch (e) {
      _showErrorDialog('Network error: $e');
    }
  }

  Future<void> _deleteFrame(String frameId, String frameName) async {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Frame'),
        content: Text('Are you sure you want to delete "$frameName"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              _confirmDeleteFrame(frameId);
            },
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmDeleteFrame(String frameId) async {
    try {
      final ApiResponse response = await _frameService.deleteFrame(frameId);
      if (response.success == true) {
        _showSuccessDialog('Frame deleted successfully');
        _loadFrames();
      } else {
        _showErrorDialog(response.error ?? 'Failed to delete frame');
      }
    } catch (e) {
      _showErrorDialog('Network error: $e');
    }
  }

  bool _validateForm() {
    if (_nameController.text.isEmpty ||
        _brandController.text.isEmpty ||
        _selectedMainCategory == null ||
        _selectedSubCategory == null ||
        _selectedType == null ||
        _selectedShape == null ||
        _priceController.text.isEmpty ||
        _quantityController.text.isEmpty ||
        _selectedColors.isEmpty ||
        _selectedSize == null) {
      _showErrorDialog('Please fill all required fields');
      return false;
    }

    if (_selectedImages.isEmpty) {
      _showErrorDialog('Please add at least one product image');
      return false;
    }

    if (_selectedOverlayImage == null) {
      _showErrorDialog('Please add an overlay image');
      return false;
    }

    return true;
  }

  bool _validateFormForUpdate() {
    if (_nameController.text.isEmpty ||
        _brandController.text.isEmpty ||
        _selectedMainCategory == null ||
        _selectedSubCategory == null ||
        _selectedType == null ||
        _selectedShape == null ||
        _priceController.text.isEmpty ||
        _quantityController.text.isEmpty ||
        _selectedColors.isEmpty ||
        _selectedSize == null) {
      _showErrorDialog('Please fill all required fields');
      return false;
    }

    // For update, images are optional (can keep existing ones)
    return true;
  }

  void _resetForm() {
    _nameController.clear();
    _brandController.clear();
    _priceController.clear();
    _quantityController.clear();
    _descriptionController.clear();
    setState(() {
      _selectedMainCategory = null;
      _selectedSubCategory = null;
      _selectedType = null;
      _selectedShape = null;
      _selectedSize = null;
      _selectedColor = null;
      _selectedColors = [];
      _selectedImages = [];
      _selectedOverlayImage = null;
      _editingFrame = null;
      _existingImageUrls = [];
      _existingOverlayUrl = null;
    });
  }

  Future<void> _pickProductImages() async {
    try {
      final List<XFile> images = await _imagePicker.pickMultiImage(
        maxWidth: 1200,
        maxHeight: 1200,
        imageQuality: 85,
      );

      if (images.isNotEmpty) {
        if (_selectedImages.length + images.length > 5) {
          _showErrorDialog('You can only upload up to 5 images. You already have ${_selectedImages.length} images.');
          return;
        }

        setState(() {
          _selectedImages.addAll(images);
        });
      }
    } catch (e) {
      _showErrorDialog('Failed to pick images: $e');
    }
  }

  Future<void> _pickOverlayImage() async {
    try {
      final XFile? image = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1200,
        maxHeight: 1200,
        imageQuality: 90,
      );

      if (image != null) {
        setState(() {
          _selectedOverlayImage = image;
        });
      }
    } catch (e) {
      _showErrorDialog('Failed to pick overlay image: $e');
    }
  }

  Future<void> _takeOverlayPhoto() async {
    try {
      final XFile? image = await _imagePicker.pickImage(
        source: ImageSource.camera,
        maxWidth: 1200,
        maxHeight: 1200,
        imageQuality: 90,
      );

      if (image != null) {
        setState(() {
          _selectedOverlayImage = image;
        });
      }
    } catch (e) {
      _showErrorDialog('Failed to take photo: $e');
    }
  }

  void _removeProductImage(int index) {
    setState(() {
      _selectedImages.removeAt(index);
    });
  }

  void _removeExistingImage(int index) {
    setState(() {
      _existingImageUrls.removeAt(index);
    });
  }

  void _removeOverlayImage() {
    setState(() {
      _selectedOverlayImage = null;
      _existingOverlayUrl = null;
    });
  }

  void _addColor() {
    if (_selectedColor != null && _selectedColor!.isNotEmpty) {
      if (!_selectedColors.contains(_selectedColor!)) {
        setState(() {
          _selectedColors.add(_selectedColor!);
          _selectedColor = null;
        });
      } else {
        _showErrorDialog('Color already added');
      }
    }
  }

  void _removeColor(String color) {
    setState(() {
      _selectedColors.remove(color);
    });
  }

  void _showAddFrameDialog() {
    _resetForm();
    showDialog(
      context: context,
      builder: (context) => _buildFrameDialog(isEditing: false),
    );
  }

  void _showEditFrameDialog(Frame frame) {
    _editingFrame = frame;
    _nameController.text = frame.name;
    _brandController.text = frame.brand;
    _priceController.text = frame.price.toString();
    _quantityController.text = frame.quantity.toString();
    _descriptionController.text = frame.description ?? '';

    setState(() {
      _selectedMainCategory = frame.mainCategory;
      _selectedSubCategory = frame.subCategory;
      _selectedType = frame.type;
      _selectedShape = frame.shape;
      _selectedSize = frame.size;
      _selectedColors = List.from(frame.colors);
      _existingImageUrls = List.from(frame.imageUrls);
      _existingOverlayUrl = frame.overlayUrl;
    });

    showDialog(
      context: context,
      builder: (context) => _buildFrameDialog(isEditing: true, frame: frame),
    );
  }

  Widget _buildFrameDialog({bool isEditing = false, Frame? frame}) {
    return StatefulBuilder(
      builder: (context, setDialogState) {
        return AlertDialog(
          title: Text(isEditing ? 'Edit Frame' : 'Add New Frame'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Basic Information
                _buildBasicInfoSection(),
                const SizedBox(height: 16),

                // Category Selection
                _buildCategorySection(setDialogState),
                const SizedBox(height: 16),

                // Specifications
                _buildSpecificationsSection(setDialogState),
                const SizedBox(height: 16),

                // Colors Selection
                _buildColorsSection(setDialogState),
                const SizedBox(height: 16),

                // Product Images
                _buildProductImagesSection(setDialogState, isEditing),
                const SizedBox(height: 16),

                // Overlay Image
                _buildOverlayImageSection(setDialogState, isEditing),
                const SizedBox(height: 16),

                // Description
                _buildDescriptionSection(),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                if (isEditing && frame != null) {
                  _updateFrame(frame.id);
                } else {
                  _createFrame();
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF275BCD),
              ),
              child: Text(isEditing ? 'Update' : 'Create'),
            ),
          ],
        );
      },
    );
  }

  Widget _buildBasicInfoSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Basic Information', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),
        TextField(
          controller: _nameController,
          decoration: const InputDecoration(
            labelText: 'Frame Name *',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _brandController,
          decoration: const InputDecoration(
            labelText: 'Brand *',
            border: OutlineInputBorder(),
          ),
        ),
      ],
    );
  }

  Widget _buildCategorySection(StateSetter setDialogState) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Category', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),
        DropdownButtonFormField<String>(
          value: _selectedMainCategory,
          decoration: const InputDecoration(
            labelText: 'Main Category *',
            border: OutlineInputBorder(),
          ),
          items: _mainCategories.map((category) {
            return DropdownMenuItem<String>(
              value: category['_id'],
              child: Text(category['name']),
            );
          }).toList(),
          onChanged: (value) {
            setDialogState(() {
              _selectedMainCategory = value;
              _selectedSubCategory = null;
            });
          },
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<String>(
          value: _selectedSubCategory,
          decoration: const InputDecoration(
            labelText: 'Sub Category *',
            border: OutlineInputBorder(),
          ),
          items: _getSubCategoriesForMain(_selectedMainCategory ?? '').map((subCat) {
            return DropdownMenuItem<String>(
              value: subCat['_id'],
              child: Text(subCat['name']),
            );
          }).toList(),
          onChanged: _selectedMainCategory != null ? (value) {
            setDialogState(() {
              _selectedSubCategory = value;
            });
          } : null,
        ),
      ],
    );
  }

  Widget _buildSpecificationsSection(StateSetter setDialogState) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Specifications', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),
        DropdownButtonFormField<String>(
          value: _selectedType,
          decoration: const InputDecoration(
            labelText: 'Frame Type *',
            border: OutlineInputBorder(),
          ),
          items: _frameTypes.map((type) {
            return DropdownMenuItem<String>(
              value: type,
              child: Text(_formatType(type)),
            );
          }).toList(),
          onChanged: (value) {
            setDialogState(() {
              _selectedType = value;
            });
          },
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<String>(
          value: _selectedShape,
          decoration: const InputDecoration(
            labelText: 'Frame Shape *',
            border: OutlineInputBorder(),
          ),
          items: _frameShapes.map((shape) {
            return DropdownMenuItem<String>(
              value: shape,
              child: Text(_formatShape(shape)),
            );
          }).toList(),
          onChanged: (value) {
            setDialogState(() {
              _selectedShape = value;
            });
          },
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _priceController,
                decoration: const InputDecoration(
                  labelText: 'Price *',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.numberWithOptions(decimal: true),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: TextField(
                controller: _quantityController,
                decoration: const InputDecoration(
                  labelText: 'Quantity *',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<String>(
          value: _selectedSize,
          decoration: const InputDecoration(
            labelText: 'Size *',
            border: OutlineInputBorder(),
          ),
          items: const [
            DropdownMenuItem(value: 'extra-small', child: Text('Extra Small')),
            DropdownMenuItem(value: 'small', child: Text('Small')),
            DropdownMenuItem(value: 'medium', child: Text('Medium')),
            DropdownMenuItem(value: 'large', child: Text('Large')),
            DropdownMenuItem(value: 'extra-large', child: Text('Extra Large')),
          ],
          onChanged: (value) {
            setDialogState(() {
              _selectedSize = value;
            });
          },
        ),
      ],
    );
  }

  Widget _buildColorsSection(StateSetter setDialogState) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Colors *', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: DropdownButtonFormField<String>(
                value: _selectedColor,
                decoration: const InputDecoration(
                  labelText: 'Select Color',
                  border: OutlineInputBorder(),
                ),
                items: _availableColors.map((color) {
                  return DropdownMenuItem<String>(
                    value: color,
                    child: Text(color),
                  );
                }).toList(),
                onChanged: (value) {
                  setDialogState(() {
                    _selectedColor = value;
                  });
                },
              ),
            ),
            const SizedBox(width: 8),
            ElevatedButton(
              onPressed: _addColor,
              child: const Text('Add'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (_selectedColors.isNotEmpty) ...[
          const Text('Selected Colors:', style: TextStyle(fontSize: 14)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _selectedColors.map((color) {
              return Chip(
                label: Text(color),
                onDeleted: () => _removeColor(color),
                deleteIconColor: Colors.red,
              );
            }).toList(),
          ),
        ],
      ],
    );
  }

  Widget _buildProductImagesSection(StateSetter setDialogState, bool isEditing) {
    final totalImages = _selectedImages.length + _existingImageUrls.length;
    final canAddMore = totalImages < 5;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Product Images *', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Text('Upload up to 5 images (${totalImages}/5)',
            style: const TextStyle(fontSize: 12, color: Colors.grey)),
        const SizedBox(height: 8),

        // Display existing images (for edit mode)
        if (isEditing && _existingImageUrls.isNotEmpty)
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Existing Images:', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  crossAxisSpacing: 8,
                  mainAxisSpacing: 8,
                  childAspectRatio: 1,
                ),
                itemCount: _existingImageUrls.length,
                itemBuilder: (context, index) {
                  return Stack(
                    children: [
                      Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.grey.shade300),
                        ),
                        child: Image.network(
                          _existingImageUrls[index],
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            return const Center(child: Icon(Icons.broken_image));
                          },
                        ),
                      ),
                      Positioned(
                        top: 4,
                        right: 4,
                        child: CircleAvatar(
                          radius: 12,
                          backgroundColor: Colors.red,
                          child: IconButton(
                            padding: EdgeInsets.zero,
                            icon: const Icon(Icons.close, size: 12, color: Colors.white),
                            onPressed: () => _removeExistingImage(index),
                          ),
                        ),
                      ),
                      Positioned(
                        bottom: 4,
                        left: 4,
                        right: 4,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.black54,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text(
                            'Existing',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 8),
            ],
          ),

        // Display newly selected images
        if (_selectedImages.isNotEmpty)
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
              childAspectRatio: 1,
            ),
            itemCount: _selectedImages.length,
            itemBuilder: (context, index) {
              return Stack(
                children: [
                  Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: Image.file(
                      File(_selectedImages[index].path),
                      fit: BoxFit.cover,
                    ),
                  ),
                  Positioned(
                    top: 4,
                    right: 4,
                    child: CircleAvatar(
                      radius: 12,
                      backgroundColor: Colors.red,
                      child: IconButton(
                        padding: EdgeInsets.zero,
                        icon: const Icon(Icons.close, size: 12, color: Colors.white),
                        onPressed: () => _removeProductImage(index),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),

        const SizedBox(height: 12),
        ElevatedButton.icon(
          onPressed: canAddMore ? _pickProductImages : null,
          icon: const Icon(Icons.photo_library),
          label: Text('Add Images (${totalImages}/5)'),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF275BCD),
            foregroundColor: Colors.white,
          ),
        ),
      ],
    );
  }

  Widget _buildOverlayImageSection(StateSetter setDialogState, bool isEditing) {
    final hasOverlay = _selectedOverlayImage != null || _existingOverlayUrl != null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Overlay Image *', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),

        if (hasOverlay)
          Column(
            children: [
              Container(
                height: 150,
                width: double.infinity,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: _selectedOverlayImage != null
                    ? Image.file(
                  File(_selectedOverlayImage!.path),
                  fit: BoxFit.cover,
                )
                    : _existingOverlayUrl != null
                    ? Image.network(
                  _existingOverlayUrl!,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) {
                    return const Center(child: Icon(Icons.broken_image, size: 50));
                  },
                )
                    : const Center(child: Icon(Icons.image, size: 50)),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  if (_selectedOverlayImage != null || _existingOverlayUrl != null)
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _removeOverlayImage,
                        child: const Text('Remove Overlay', style: TextStyle(color: Colors.red)),
                      ),
                    ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _pickOverlayImage,
                      icon: const Icon(Icons.photo_library),
                      label: const Text('Change'),
                    ),
                  ),
                ],
              ),
            ],
          )
        else
          Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _pickOverlayImage,
                      icon: const Icon(Icons.photo_library),
                      label: const Text('Gallery'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _takeOverlayPhoto,
                      icon: const Icon(Icons.camera_alt),
                      label: const Text('Camera'),
                    ),
                  ),
                ],
              ),
            ],
          ),
      ],
    );
  }

  Widget _buildDescriptionSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Description', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        TextField(
          controller: _descriptionController,
          decoration: const InputDecoration(
            labelText: 'Frame Description',
            border: OutlineInputBorder(),
            hintText: 'Describe the frame features, materials, etc.',
          ),
          maxLines: 3,
        ),
      ],
    );
  }

  String _formatType(String type) {
    switch (type) {
      case 'full_rim': return 'Full Rim';
      case 'half_rim': return 'Half Rim';
      case 'rimless': return 'Rimless';
      default: return type;
    }
  }

  String _formatShape(String shape) {
    switch (shape) {
      case 'cate_eye': return 'Cat Eye';
      case 'wayfarer': return 'Wayfarer';
      case 'aviator': return 'Aviator';
      case 'browline': return 'Browline';
      default: return shape[0].toUpperCase() + shape.substring(1);
    }
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.error_outline, color: Colors.red),
            SizedBox(width: 8),
            Text('Error'),
          ],
        ),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _showSuccessDialog(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.check_circle, color: Colors.green),
            SizedBox(width: 8),
            Text('Success'),
          ],
        ),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Frame Management'),
        backgroundColor: const Color(0xFF275BCD),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadFrames,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddFrameDialog,
        backgroundColor: const Color(0xFF275BCD),
        child: const Icon(Icons.add),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _frames.isEmpty
          ? _buildEmptyState()
          : _buildFrameList(),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.inventory, size: 64, color: Colors.grey),
          const SizedBox(height: 16),
          const Text(
            'No frames found',
            style: TextStyle(fontSize: 16, color: Colors.grey),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: _showAddFrameDialog,
            child: const Text('Add First Frame'),
          ),
        ],
      ),
    );
  }

  Widget _buildFrameList() {
    return ListView.builder(
      itemCount: _frames.length,
      itemBuilder: (context, index) {
        final frame = _frames[index];
        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: ListTile(
            leading: frame.imageUrls.isNotEmpty
                ? Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                image: DecorationImage(
                  image: NetworkImage(frame.imageUrls.first),
                  fit: BoxFit.cover,
                ),
              ),
            )
                : const Icon(Icons.photo, size: 40),
            title: Text(
              frame.name,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Brand: ${frame.brand}'),
                Text('Price: \$${frame.price.toStringAsFixed(2)}'),
                Text('Stock: ${frame.quantity}'),
                Text('Colors: ${frame.colors.join(', ')}'),
                if (frame.mainCategoryName != null && frame.subCategoryName != null)
                  Text('Category: ${frame.mainCategoryName} > ${frame.subCategoryName}'),
              ],
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.edit, color: Colors.blue),
                  onPressed: () => _showEditFrameDialog(frame),
                ),
                IconButton(
                  icon: const Icon(Icons.delete, color: Colors.red),
                  onPressed: () => _deleteFrame(frame.id, frame.name),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _brandController.dispose();
    _priceController.dispose();
    _quantityController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }
}