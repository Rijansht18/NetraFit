import 'package:flutter/material.dart';
import 'package:netrafit/models/frame_model.dart';
import 'package:netrafit/services/category_service.dart';
import 'package:netrafit/services/frame_service.dart';
import 'package:netrafit/widgets/common/frame_card.dart';

import 'UserOrdersScreen.dart';

class ShopScreen extends StatefulWidget {
  const ShopScreen({super.key});

  @override
  State<ShopScreen> createState() => _ShopScreenState();
}

class _ShopScreenState extends State<ShopScreen> {
  List<Frame> _allFrames = [];
  List<Map<String, dynamic>> _mainCategories = [];
  Map<String, List<Frame>> _categoryFrames = {};
  int _selectedCategoryIndex = 0; // 0 for "All", then categories
  bool _isLoading = true;
  String _errorMessage = '';

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      final categoryService = CategoryService();
      final frameService = FrameService();

      // Load main categories
      final categoriesResponse = await categoryService.getAllMainCategories();
      if (categoriesResponse.success) {
        final categories = List<Map<String, dynamic>>.from(
            categoriesResponse.data['data'] ?? []);

        // Load all frames
        final allFramesResponse = await frameService.getAllFrames();
        if (allFramesResponse.success) {
          final framesData = allFramesResponse.data['data'] ?? [];

          // Parse frames
          final List<Frame> allFrames = [];
          for (var frameData in framesData) {
            try {
              final frame = Frame.fromJson(frameData);
              if (frame.isActive) {
                allFrames.add(frame);
              }
            } catch (e) {
              print('Error parsing frame: $e');
            }
          }

          // Group frames by main category
          final Map<String, List<Frame>> tempCategoryFrames = {};
          for (var category in categories) {
            final categoryId = category['_id']?.toString() ?? '';

            // Filter frames for this category
            final categoryFrames = allFrames.where((frame) {
              return frame.mainCategory == categoryId;
            }).toList();

            if (categoryFrames.isNotEmpty) {
              tempCategoryFrames[categoryId] = categoryFrames;
            }
          }

          setState(() {
            _allFrames = allFrames;
            _mainCategories = categories.where((category) {
              final categoryId = category['_id']?.toString() ?? '';
              return tempCategoryFrames.containsKey(categoryId) &&
                  tempCategoryFrames[categoryId]!.isNotEmpty;
            }).toList();
            _categoryFrames = tempCategoryFrames;
            _isLoading = false;
          });
        } else {
          setState(() {
            _errorMessage = 'Failed to load frames';
            _isLoading = false;
          });
        }
      } else {
        setState(() {
          _errorMessage = 'Failed to load categories';
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Error in _loadData: $e');
      setState(() {
        _errorMessage = 'Error: ${e.toString()}';
        _isLoading = false;
      });
    }
  }

  Widget _buildCategoryChips() {
    return SizedBox(
      height: 50,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          // "All" category chip
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: ChoiceChip(
              label: const Text('All'),
              selected: _selectedCategoryIndex == 0,
              onSelected: (selected) {
                setState(() {
                  _selectedCategoryIndex = 0;
                });
              },
              selectedColor: const Color(0xFF275BCD),
              labelStyle: TextStyle(
                color: _selectedCategoryIndex == 0 ? Colors.white : Colors.black,
              ),
            ),
          ),

          // Category chips
          ..._mainCategories.asMap().entries.map((entry) {
            final index = entry.key + 1; // +1 because 0 is "All"
            final category = entry.value;
            final categoryName = category['name']?.toString() ?? 'Category';

            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: ChoiceChip(
                label: Text(categoryName),
                selected: _selectedCategoryIndex == index,
                onSelected: (selected) {
                  setState(() {
                    _selectedCategoryIndex = index;
                  });
                },
                selectedColor: const Color(0xFF275BCD),
                labelStyle: TextStyle(
                  color: _selectedCategoryIndex == index ? Colors.white : Colors.black,
                ),
              ),
            );
          }).toList(),
        ],
      ),
    );
  }

  Widget _buildContent() {
    if (_selectedCategoryIndex == 0) {
      // Show all frames
      return _allFrames.isEmpty
          ? const Center(
        child: Text(
          'No frames available',
          style: TextStyle(color: Colors.grey),
        ),
      )
          : GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: 0.8,
        ),
        itemCount: _allFrames.length,
        itemBuilder: (context, index) {
          final frame = _allFrames[index];
          return Container(
            constraints: const BoxConstraints(
              maxHeight: 400,
            ),
            child: FrameCard(frame: frame),
          );
        },
      );
    } else {
      // Show frames for selected category
      final categoryIndex = _selectedCategoryIndex - 1;
      if (categoryIndex >= _mainCategories.length) {
        return const Center(child: Text('Category not found'));
      }

      final category = _mainCategories[categoryIndex];
      final categoryId = category['_id']?.toString() ?? '';
      final frames = _categoryFrames[categoryId] ?? [];

      return frames.isEmpty
          ? Center(
        child: Text(
          'No frames in ${category['name']} category',
          style: const TextStyle(color: Colors.grey),
        ),
      )
          : GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: 0.8,
        ),
        itemCount: frames.length,
        itemBuilder: (context, index) {
          final frame = frames[index];
          return Container(
            constraints: const BoxConstraints(
              maxHeight: 400,
            ),
            child: FrameCard(frame: frame),
          );
        },
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text(
          'Shop',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: Colors.black,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        actions: [
          // Cart Button
          IconButton(
            icon: Stack(
              children: [
                const Icon(Icons.shopping_cart, color: Colors.black),
                Positioned(
                  right: 0,
                  child: Container(
                    padding: const EdgeInsets.all(1),
                    decoration: BoxDecoration(
                      color: Colors.red,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    constraints: const BoxConstraints(
                      minWidth: 12,
                      minHeight: 12,
                    ),
                    child: const Text(
                      '3',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 8,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
              ],
            ),
            onPressed: () {
              // Navigate to cart
            },
          ),

          // Orders Button
          IconButton(
            icon: const Icon(Icons.receipt_long, color: Colors.black),
            onPressed: () {
              // Navigate to orders
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const UserOrdersScreen(),
                ),
              );
            },
          ),
        ],
      ),
      body: _isLoading
          ? const Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF275BCD)),
        ),
      )
          : _errorMessage.isNotEmpty
          ? Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.error_outline,
              size: 60,
              color: Colors.red,
            ),
            const SizedBox(height: 16),
            Text(
              _errorMessage,
              style: const TextStyle(color: Colors.red),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadData,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF275BCD),
              ),
              child: const Text('Retry'),
            ),
          ],
        ),
      )
          : SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Category Chips
            _buildCategoryChips(),

            const SizedBox(height: 20),

            // Content based on selected category
            _buildContent(),

            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}