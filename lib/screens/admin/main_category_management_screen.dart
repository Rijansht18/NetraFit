import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../services/category_service.dart';
import '../../models/api_response.dart';

class MainCategoryManagementScreen extends StatefulWidget {
  const MainCategoryManagementScreen({Key? key}) : super(key: key);

  @override
  State<MainCategoryManagementScreen> createState() =>
      _MainCategoryManagementScreenState();
}

class _MainCategoryManagementScreenState
    extends State<MainCategoryManagementScreen> {
  final CategoryService _categoryService = CategoryService();
  final ImagePicker _imagePicker = ImagePicker();

  List<dynamic> _mainCategories = [];
  List<dynamic> _subCategories = [];
  bool _isLoading = true;

  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _editNameController = TextEditingController();
  final TextEditingController _subCategoryNameController = TextEditingController();
  final TextEditingController _editSubCategoryNameController = TextEditingController();

  String? _editingCategoryId;
  String? _expandedCategoryId;
  String? _selectedMainCategoryId;
  String? _editingSubCategoryId;
  String? _selectedImageBase64;

  @override
  void initState() {
    super.initState();
    _loadMainCategories();
    _loadAllSubCategories();
  }

  Future<void> _loadMainCategories() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final ApiResponse response =
      await _categoryService.getAllMainCategories();

      if (response.success == true) {
        setState(() {
          _mainCategories = response.data?['data'] ?? [];
        });
      } else {
        _showErrorDialog(response.error ?? 'Failed to load categories');
      }
    } catch (e) {
      _showErrorDialog('Network error: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _loadAllSubCategories() async {
    try {
      final ApiResponse response = await _categoryService.getAllSubCategories();
      if (response.success == true) {
        setState(() {
          _subCategories = response.data?['data'] ?? [];
        });
      }
    } catch (e) {
      print('Error loading sub-categories: $e');
    }
  }

  List<dynamic> _getSubCategoriesForMainCategory(String mainCategoryId) {
    return _subCategories.where((subCategory) =>
    subCategory['mainCategory']?['_id'] == mainCategoryId ||
        subCategory['mainCategory'] == mainCategoryId
    ).toList();
  }

  Future<void> _createMainCategory() async {
    if (_nameController.text.isEmpty) {
      _showErrorDialog('Please enter category name');
      return;
    }

    try {
      final ApiResponse response =
      await _categoryService.createMainCategory(_nameController.text);

      if (response.success == true) {
        _showSuccessDialog('Category created successfully');
        _nameController.clear();
        _loadMainCategories();
      } else {
        _showErrorDialog(response.error ?? 'Failed to create category');
      }
    } catch (e) {
      _showErrorDialog('Network error: $e');
    }
  }

  Future<void> _updateMainCategory() async {
    if (_editNameController.text.isEmpty || _editingCategoryId == null) {
      _showErrorDialog('Please enter category name');
      return;
    }

    try {
      final ApiResponse response = await _categoryService.updateMainCategory(
          _editingCategoryId!, _editNameController.text);

      if (response.success == true) {
        _showSuccessDialog('Category updated successfully');
        _editingCategoryId = null;
        _editNameController.clear();
        _loadMainCategories();
      } else {
        _showErrorDialog(response.error ?? 'Failed to update category');
      }
    } catch (e) {
      _showErrorDialog('Network error: $e');
    }
  }

  Future<void> _createSubCategory() async {
    if (_subCategoryNameController.text.isEmpty || _selectedMainCategoryId == null) {
      _showErrorDialog('Please enter sub-category name');
      return;
    }

    try {
      final ApiResponse response = await _categoryService.createSubCategory(
        _subCategoryNameController.text,
        _selectedMainCategoryId!,
        _selectedImageBase64,
      );

      if (response.success == true) {
        _showSuccessDialog('Sub-category created successfully');
        _subCategoryNameController.clear();
        _selectedImageBase64 = null;
        _loadAllSubCategories();
        setState(() {
          _selectedMainCategoryId = null;
        });
      } else {
        _showErrorDialog(response.error ?? 'Failed to create sub-category');
      }
    } catch (e) {
      _showErrorDialog('Network error: $e');
    }
  }

  Future<void> _updateSubCategory() async {
    if (_editSubCategoryNameController.text.isEmpty || _editingSubCategoryId == null) {
      _showErrorDialog('Please enter sub-category name');
      return;
    }

    try {
      final ApiResponse response = await _categoryService.updateSubCategory(
        _editingSubCategoryId!,
        _editSubCategoryNameController.text,
        _selectedMainCategoryId ?? _getMainCategoryIdForSubCategory(_editingSubCategoryId!)!,
        _selectedImageBase64,
      );

      if (response.success == true) {
        _showSuccessDialog('Sub-category updated successfully');
        _editSubCategoryNameController.clear();
        _selectedImageBase64 = null;
        _editingSubCategoryId = null;
        _loadAllSubCategories();
      } else {
        _showErrorDialog(response.error ?? 'Failed to update sub-category');
      }
    } catch (e) {
      _showErrorDialog('Network error: $e');
    }
  }

  String? _getMainCategoryIdForSubCategory(String subCategoryId) {
    final subCategory = _subCategories.firstWhere(
          (sc) => sc['_id'] == subCategoryId,
      orElse: () => null,
    );
    return subCategory?['mainCategory']?['_id'] ?? subCategory?['mainCategory'];
  }

  Future<void> _pickImage() async {
    try {
      final XFile? image = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 800,
        maxHeight: 800,
        imageQuality: 80,
      );

      if (image != null) {
        final File imageFile = File(image.path);
        final bytes = await imageFile.readAsBytes();
        final base64Image = base64Encode(bytes);

        setState(() {
          _selectedImageBase64 = base64Image;
        });
      }
    } catch (e) {
      _showErrorDialog('Failed to pick image: $e');
    }
  }

  Future<void> _takePhoto() async {
    try {
      final XFile? image = await _imagePicker.pickImage(
        source: ImageSource.camera,
        maxWidth: 800,
        maxHeight: 800,
        imageQuality: 80,
      );

      if (image != null) {
        final File imageFile = File(image.path);
        final bytes = await imageFile.readAsBytes();
        final base64Image = base64Encode(bytes);

        setState(() {
          _selectedImageBase64 = base64Image;
        });
      }
    } catch (e) {
      _showErrorDialog('Failed to take photo: $e');
    }
  }

  void _removeImage() {
    setState(() {
      _selectedImageBase64 = null;
    });
  }

  Future<void> _deleteMainCategory(String id, String name) async {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Category'),
        content: Text('Are you sure you want to delete "$name"? This will also delete all its sub-categories.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              _confirmDeleteCategory(id);
            },
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteSubCategory(String id, String name) async {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Sub-Category'),
        content: Text('Are you sure you want to delete "$name"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              _confirmDeleteSubCategory(id);
            },
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmDeleteCategory(String id) async {
    try {
      final ApiResponse response =
      await _categoryService.deleteMainCategory(id);

      if (response.success == true) {
        _showSuccessDialog('Category deleted successfully');
        _loadMainCategories();
        _loadAllSubCategories();
      } else {
        _showErrorDialog(response.error ?? 'Failed to delete category');
      }
    } catch (e) {
      _showErrorDialog('Network error: $e');
    }
  }

  Future<void> _confirmDeleteSubCategory(String id) async {
    try {
      final ApiResponse response = await _categoryService.deleteSubCategory(id);
      if (response.success == true) {
        _showSuccessDialog('Sub-category deleted successfully');
        _loadAllSubCategories();
      } else {
        _showErrorDialog(response.error ?? 'Failed to delete sub-category');
      }
    } catch (e) {
      _showErrorDialog('Network error: $e');
    }
  }

  // ------------------- Dialogs -------------------

  void _showAddCategoryDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add Main Category'),
        content: TextField(
          controller: _nameController,
          decoration: const InputDecoration(
            labelText: 'Category Name',
            hintText: 'e.g., Sunglasses, Prescription Glasses',
            border: OutlineInputBorder(),
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
              _createMainCategory();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF275BCD),
            ),
            child: const Text('Create'),
          ),
        ],
      ),
    );
  }

  void _showEditCategoryDialog(Map category) {
    _editingCategoryId = category['_id'];
    _editNameController.text = category['name'];

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Main Category'),
        content: TextField(
          controller: _editNameController,
          decoration: const InputDecoration(
            labelText: 'Category Name',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _editingCategoryId = null;
            },
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _updateMainCategory();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF275BCD),
            ),
            child: const Text('Update'),
          ),
        ],
      ),
    );
  }

  void _showAddSubCategoryDialog(String mainCategoryId, String mainCategoryName) {
    _selectedMainCategoryId = mainCategoryId;
    _subCategoryNameController.clear();
    _selectedImageBase64 = null;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            title: Text('Add Sub-Category to $mainCategoryName'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: _subCategoryNameController,
                    decoration: const InputDecoration(
                      labelText: 'Sub-Category Name',
                      hintText: 'e.g., Men, Women, Kids, Sports',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Image Preview
                  if (_selectedImageBase64 != null)
                    Column(
                      children: [
                        Container(
                          height: 100,
                          width: 100,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.grey),
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.memory(
                              base64Decode(_selectedImageBase64!),
                              fit: BoxFit.cover,
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextButton(
                          onPressed: _removeImage,
                          child: const Text('Remove Image', style: TextStyle(color: Colors.red)),
                        ),
                      ],
                    )
                  else
                    Column(
                      children: [
                        const Text('Add Image (Optional)', style: TextStyle(fontSize: 12, color: Colors.grey)),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: _pickImage,
                                icon: const Icon(Icons.photo_library, size: 16),
                                label: const Text('Gallery', style: TextStyle(fontSize: 12)),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: _takePhoto,
                                icon: const Icon(Icons.camera_alt, size: 16),
                                label: const Text('Camera', style: TextStyle(fontSize: 12)),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                  _selectedMainCategoryId = null;
                  _selectedImageBase64 = null;
                },
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  _createSubCategory();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF275BCD),
                ),
                child: const Text('Create'),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showEditSubCategoryDialog(Map subCategory) {
    _editingSubCategoryId = subCategory['_id'];
    _editSubCategoryNameController.text = subCategory['name'];
    _selectedImageBase64 = subCategory['image'];
    _selectedMainCategoryId = subCategory['mainCategory']?['_id'] ?? subCategory['mainCategory'];

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            title: const Text('Edit Sub-Category'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: _editSubCategoryNameController,
                    decoration: const InputDecoration(
                      labelText: 'Sub-Category Name',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Image Preview
                  if (_selectedImageBase64 != null)
                    Column(
                      children: [
                        Container(
                          height: 100,
                          width: 100,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.grey),
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.memory(
                              base64Decode(_selectedImageBase64!),
                              fit: BoxFit.cover,
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextButton(
                          onPressed: _removeImage,
                          child: const Text('Remove Image', style: TextStyle(color: Colors.red)),
                        ),
                      ],
                    )
                  else
                    Column(
                      children: [
                        const Text('Add Image (Optional)', style: TextStyle(fontSize: 12, color: Colors.grey)),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: _pickImage,
                                icon: const Icon(Icons.photo_library, size: 16),
                                label: const Text('Gallery', style: TextStyle(fontSize: 12)),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: _takePhoto,
                                icon: const Icon(Icons.camera_alt, size: 16),
                                label: const Text('Camera', style: TextStyle(fontSize: 12)),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                  _editingSubCategoryId = null;
                  _selectedImageBase64 = null;
                },
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  _updateSubCategory();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF275BCD),
                ),
                child: const Text('Update'),
              ),
            ],
          );
        },
      ),
    );
  }

  // ------------------- Alerts -------------------

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

  // ------------------- UI -------------------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Category Management'),
        backgroundColor: const Color(0xFF275BCD),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              _loadMainCategories();
              _loadAllSubCategories();
            },
          ),
        ],
      ),

      floatingActionButton: FloatingActionButton(
        onPressed: _showAddCategoryDialog,
        backgroundColor: const Color(0xFF275BCD),
        child: const Icon(Icons.add),
      ),

      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _mainCategories.isEmpty
          ? _buildEmptyState()
          : _buildCategoryList(),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.category, size: 64, color: Colors.grey),
          const SizedBox(height: 16),
          const Text(
            'No categories found',
            style: TextStyle(fontSize: 16, color: Colors.grey),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: _showAddCategoryDialog,
            child: const Text('Create First Category'),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryList() {
    return ListView.builder(
      itemCount: _mainCategories.length,
      itemBuilder: (context, index) {
        final category = _mainCategories[index];
        final isExpanded = _expandedCategoryId == category['_id'];
        final subCategories = _getSubCategoriesForMainCategory(category['_id']);

        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: Column(
            children: [
              // Main Category Header
              ListTile(
                leading: const Icon(Icons.category, color: Color(0xFF275BCD)),
                title: Text(
                  category['name'],
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: Text(
                  '${subCategories.length} sub-categories • Created: ${_formatDate(category['createdAt'])}',
                  style: const TextStyle(fontSize: 12),
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.add, size: 20),
                      onPressed: () {
                        _showAddSubCategoryDialog(category['_id'], category['name']);
                      },
                      tooltip: 'Add Sub-Category',
                    ),
                    IconButton(
                      icon: Icon(
                        isExpanded ? Icons.expand_less : Icons.expand_more,
                        size: 20,
                      ),
                      onPressed: () {
                        setState(() {
                          _expandedCategoryId = isExpanded ? null : category['_id'];
                        });
                      },
                      tooltip: isExpanded ? 'Collapse' : 'Expand',
                    ),
                    PopupMenuButton<String>(
                      onSelected: (value) {
                        if (value == 'edit') {
                          _showEditCategoryDialog(category);
                        } else if (value == 'delete') {
                          _deleteMainCategory(category['_id'], category['name']);
                        }
                      },
                      itemBuilder: (context) => [
                        const PopupMenuItem(
                          value: 'edit',
                          child: Row(
                            children: [
                              Icon(Icons.edit, color: Colors.blue),
                              SizedBox(width: 8),
                              Text('Edit'),
                            ],
                          ),
                        ),
                        const PopupMenuItem(
                          value: 'delete',
                          child: Row(
                            children: [
                              Icon(Icons.delete, color: Colors.red),
                              SizedBox(width: 8),
                              Text('Delete'),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // Sub-Categories List (Expandable)
              if (isExpanded)
                Padding(
                  padding: const EdgeInsets.only(left: 16, right: 16, bottom: 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Divider(),
                      if (subCategories.isEmpty)
                        Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Row(
                            children: [
                              const Icon(Icons.info_outline, color: Colors.grey, size: 16),
                              const SizedBox(width: 8),
                              const Expanded(
                                child: Text(
                                  'No sub-categories yet',
                                  style: TextStyle(color: Colors.grey, fontSize: 12),
                                ),
                              ),
                              TextButton(
                                onPressed: () {
                                  _showAddSubCategoryDialog(category['_id'], category['name']);
                                },
                                child: const Text('Add First Sub-Category'),
                              ),
                            ],
                          ),
                        )
                      else
                        ...subCategories.map((subCategory) => _buildSubCategoryItem(subCategory)).toList(),
                    ],
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSubCategoryItem(Map subCategory) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 0),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 2,
            offset: Offset(0, 1),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Dismissible(
          key: Key(subCategory['_id']),
          direction: DismissDirection.endToStart,
          background: Container(
            color: Colors.red,
            alignment: Alignment.centerRight,
            padding: const EdgeInsets.only(right: 20),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Icon(Icons.delete, color: Colors.white, size: 24),
                SizedBox(width: 8),
                Text(
                  'Delete',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(width: 16),
              ],
            ),
          ),
          secondaryBackground: Container(
            color: Colors.red,
            alignment: Alignment.centerRight,
            padding: const EdgeInsets.only(right: 20),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Icon(Icons.delete, color: Colors.white, size: 24),
                SizedBox(width: 8),
                Text(
                  'Delete',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(width: 16),
              ],
            ),
          ),
          confirmDismiss: (direction) async {
            return await showDialog(
              context: context,
              builder: (context) => AlertDialog(
                title: const Text('Delete Sub-Category'),
                content: Text('Are you sure you want to delete "${subCategory['name']}"?'),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(false),
                    child: const Text('Cancel'),
                  ),
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(true),
                    child: const Text('Delete', style: TextStyle(color: Colors.red)),
                  ),
                ],
              ),
            );
          },
          onDismissed: (direction) {
            _deleteSubCategory(subCategory['_id'], subCategory['name']);
          },
          child: Card(
            elevation: 1,
            color: Colors.grey[50],
            margin: EdgeInsets.zero, // Remove card margin since container handles it
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            child: ListTile(
              dense: true,
              leading: _buildSubCategoryImage(subCategory['image']),
              title: Text(
                subCategory['name'],
                style: const TextStyle(fontSize: 14),
              ),
              subtitle: Text(
                'Created: ${_formatDate(subCategory['createdAt'])}',
                style: const TextStyle(fontSize: 10),
              ),
              trailing: IconButton(
                icon: const Icon(Icons.edit, size: 16, color: Colors.blue),
                onPressed: () {
                  _showEditSubCategoryDialog(subCategory);
                },
                tooltip: 'Edit Sub-Category',
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSubCategoryImage(String? imageBase64) {
    if (imageBase64 != null && imageBase64.isNotEmpty) {
      return Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: Colors.grey.shade300),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: Image.memory(
            base64Decode(imageBase64),
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) {
              return const Icon(Icons.photo, size: 16, color: Colors.grey);
            },
          ),
        ),
      );
    } else {
      return const Icon(Icons.subdirectory_arrow_right, size: 16, color: Colors.grey);
    }
  }

  String _formatDate(String dateString) {
    try {
      final date = DateTime.parse(dateString);
      return '${date.day}/${date.month}/${date.year}';
    } catch (e) {
      return 'Unknown';
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _editNameController.dispose();
    _subCategoryNameController.dispose();
    _editSubCategoryNameController.dispose();
    super.dispose();
  }
}