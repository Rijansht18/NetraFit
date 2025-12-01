import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:netrafit/providers/auth_provider.dart';
import 'package:netrafit/models/frame_model.dart';
import 'package:netrafit/services/category_service.dart';
import 'package:netrafit/services/frame_service.dart';
import 'package:netrafit/widgets/common/bottom_nav_bar.dart';
import 'package:netrafit/widgets/common/frame_card.dart';
import 'package:netrafit/screens/shop_screen.dart';
import 'package:netrafit/screens/favorites_screen.dart';
import 'package:netrafit/screens/settings_screen.dart';
import 'package:netrafit/screens/main_try_on_screen.dart';

import 'UserOrdersScreen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;
  List<Map<String, dynamic>> _mainCategories = [];
  Map<String, List<Frame>> _categoryFrames = {};
  List<Frame> _featuredFrames = [];
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

      final categoriesResponse = await categoryService.getAllMainCategories();
      if (categoriesResponse.success) {
        final categories = List<Map<String, dynamic>>.from(
            categoriesResponse.data['data'] ?? []);

        final allFramesResponse = await frameService.getAllFrames();
        if (allFramesResponse.success) {
          final framesData = allFramesResponse.data['data'] ?? [];

          final List<Frame> allFrames = [];
          for (var frameData in framesData) {
            try {
              final frame = Frame.fromJson(frameData);
              allFrames.add(frame);
            } catch (e) {
              print('Error parsing frame: $e');
            }
          }

          setState(() {
            _featuredFrames = allFrames
                .where((frame) => frame.isActive)
                .take(4)
                .toList();
          });

          final Map<String, List<Frame>> tempCategoryFrames = {};

          for (var category in categories) {
            final categoryId = category['_id']?.toString() ?? '';
            final List<Frame> categoryFrames = [];
            for (var frame in allFrames) {
              if (frame.isActive && frame.mainCategory == categoryId) {
                categoryFrames.add(frame);
              }
            }
            if (categoryFrames.isNotEmpty) {
              tempCategoryFrames[categoryId] = categoryFrames;
            }
          }

          final List<Map<String, dynamic>> categoriesWithFrames = [];
          for (var category in categories) {
            final categoryId = category['_id']?.toString() ?? '';
            if (tempCategoryFrames.containsKey(categoryId) &&
                tempCategoryFrames[categoryId]!.isNotEmpty) {
              categoriesWithFrames.add(category);
            }
          }

          setState(() {
            _mainCategories = categoriesWithFrames;
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

  void _onNavItemTapped(int index) {
    setState(() {
      _currentIndex = index;
    });
  }

  Widget _buildCategorySection(String categoryId, String categoryName) {
    final frames = _categoryFrames[categoryId] ?? [];
    if (frames.isEmpty) return Container();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                categoryName,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                ),
              ),
              TextButton(
                onPressed: () {
                  // Navigate to shop with category filter
                  // Navigator.push(
                  //   context,
                  //   MaterialPageRoute(
                  //     builder: (context) => ShopScreen(
                  //       initialCategoryId: categoryId,
                  //     ),
                  //   ),
                  // );
                },
                child: const Text(
                  'View All',
                  style: TextStyle(
                    color: Color(0xFF275BCD),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ),
        SizedBox(
          height: 250,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: frames.length,
            itemBuilder: (context, index) {
              final frame = frames[index];
              return Container(
                margin: EdgeInsets.only(
                  right: 12,
                  left: index == 0 ? 0 : 0,
                ),
                child: FrameCard(
                  frame: frame,
                  width: 160,
                  height: 250,
                  showCartButton: false, // No cart button in home
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 20),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: _currentIndex == 0
          ? AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.menu, color: Colors.black),
          onPressed: () {},
        ),
        title: const Text(
          'NETRA',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: Colors.black,
          ),
        ),
        centerTitle: true,
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
      )
          : null,
      body: _buildCurrentScreen(),
      bottomNavigationBar: CustomBottomNavBar(
        currentIndex: _currentIndex,
        onTap: _onNavItemTapped,
      ),
    );
  }

  Widget _buildCurrentScreen() {
    switch (_currentIndex) {
      case 0:
        return _buildHomeContent();
      case 1:
        return const ShopScreen();
      case 2:
        return const MainTryOnScreen();
      case 3:
        return const FavoritesScreen();
      case 4:
        return const SettingsScreen();
      default:
        return _buildHomeContent();
    }
  }

  Widget _buildHomeContent() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF275BCD)),
        ),
      );
    }

    if (_errorMessage.isNotEmpty) {
      return Center(
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
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Search Bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: BorderRadius.circular(12),
            ),
            child: const TextField(
              decoration: InputDecoration(
                hintText: 'Search glasses',
                border: InputBorder.none,
                prefixIcon: Icon(Icons.search, color: Colors.grey),
              ),
            ),
          ),

          const SizedBox(height: 24),

          // Action Buttons
          Row(
            children: [
              Expanded(
                child: _buildActionButton(
                  icon: Icons.camera_alt,
                  label: 'Try On',
                  onPressed: () {
                    setState(() {
                      _currentIndex = 2;
                    });
                  },
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildActionButton(
                  icon: Icons.recommend,
                  label: 'Recommendations',
                  onPressed: () {},
                ),
              ),
            ],
          ),

          const SizedBox(height: 24),

          // Featured Products
          if (_featuredFrames.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Featured Products',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.black,
                    ),
                  ),
                  TextButton(
                    onPressed: () {
                      setState(() {
                        _currentIndex = 1; // Navigate to Shop
                      });
                    },
                    child: const Text(
                      'View All',
                      style: TextStyle(
                        color: Color(0xFF275BCD),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
                childAspectRatio: 0.7,
              ),
              itemCount: _featuredFrames.length,
              itemBuilder: (context, index) {
                final frame = _featuredFrames[index];
                return FrameCard(
                  frame: frame,
                  showCartButton: false, // No cart button in home featured
                );
              },
            ),

            const SizedBox(height: 32),
          ],

          // Categories with Frames
          if (_mainCategories.isNotEmpty) ...[
            ..._mainCategories.map((category) {
              final categoryId = category['_id']?.toString() ?? '';
              final categoryName = category['name']?.toString() ?? 'Category';
              return _buildCategorySection(categoryId, categoryName);
            }).toList(),
          ],

          const SizedBox(height: 80),
        ],
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required VoidCallback onPressed,
  }) {
    return ElevatedButton.icon(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFF275BCD),
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
      icon: Icon(icon, size: 20),
      label: Text(
        label,
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}