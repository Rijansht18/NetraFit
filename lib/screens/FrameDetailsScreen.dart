import 'package:flutter/material.dart';
import 'package:netrafit/models/frame_model.dart';
import 'package:netrafit/services/frame_service.dart';
import 'package:netrafit/widgets/common/frame_card.dart';
import 'package:provider/provider.dart';
import 'package:netrafit/providers/auth_provider.dart';
import 'package:netrafit/providers/cart_provider.dart';
import 'package:netrafit/providers/favorites_provider.dart';
import 'OrderNowScreen.dart';

class FrameDetailsScreen extends StatefulWidget {
  final String frameId;
  final Frame? frame; // Optional: If frame data is already available

  const FrameDetailsScreen({
    super.key,
    required this.frameId,
    this.frame,
  });

  @override
  State<FrameDetailsScreen> createState() => _FrameDetailsScreenState();
}

class _FrameDetailsScreenState extends State<FrameDetailsScreen> {
  late Frame? _frame;
  bool _isLoading = true;
  String _errorMessage = '';
  int _selectedImageIndex = 0;
  bool _isFavorite = false;
  bool _isFavoriteLoading = false;
  String? _favoriteId;

  @override
  void initState() {
    super.initState();
    _frame = widget.frame;
    if (_frame == null) {
      _loadFrameDetails();
    } else {
      _isLoading = false;
      _checkIfFavorite();
    }
  }

  Future<void> _loadFrameDetails() async {
    try {
      final frameService = FrameService();
      final response = await frameService.getFrameById(widget.frameId);

      if (response.success) {
        final frameData = response.data?['data'];
        if (frameData != null) {
          setState(() {
            _frame = Frame.fromJson(frameData);
            _isLoading = false;
          });
          _checkIfFavorite();
        } else {
          setState(() {
            _errorMessage = 'Frame not found';
            _isLoading = false;
          });
        }
      } else {
        setState(() {
          _errorMessage = response.error ?? 'Failed to load frame details';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Error: ${e.toString()}';
        _isLoading = false;
      });
    }
  }

  void _checkIfFavorite() {
    if (_frame == null) return;

    final favoritesProvider = Provider.of<FavoritesProvider>(context, listen: false);
    final favorite = favoritesProvider.getFavoriteByFrameId(_frame!.id);

    if (favorite != null && favorite.containsKey('_id')) {
      setState(() {
        _isFavorite = true;
        _favoriteId = favorite['_id'] as String?;
      });
    } else {
      setState(() {
        _isFavorite = false;
        _favoriteId = null;
      });
    }
  }

  Future<void> _toggleFavorite() async {
    if (_isFavoriteLoading || _frame == null) return;

    setState(() {
      _isFavoriteLoading = true;
    });

    final favoritesProvider = Provider.of<FavoritesProvider>(context, listen: false);
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final token = authProvider.token;

    if (token == null || token.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please login to add to favorites'),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 2),
        ),
      );
      setState(() => _isFavoriteLoading = false);
      return;
    }

    try {
      if (_isFavorite) {
        // Remove from favorites
        String? favoriteIdToRemove = _favoriteId;

        if (favoriteIdToRemove == null) {
          final existingFavorite = favoritesProvider.getFavoriteByFrameId(_frame!.id);
          if (existingFavorite != null && existingFavorite.containsKey('_id')) {
            favoriteIdToRemove = existingFavorite['_id'] as String?;
          }
        }

        if (favoriteIdToRemove != null) {
          final success = await favoritesProvider.removeFavorite(
            token: token,
            favoriteId: favoriteIdToRemove,
          );

          if (success) {
            setState(() {
              _isFavorite = false;
              _favoriteId = null;
            });
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Removed from favorites'),
                backgroundColor: Colors.red,
                duration: Duration(seconds: 2),
              ),
            );
          }
        }
      } else {
        // Add to favorites
        final result = await favoritesProvider.addFavorite(
          token: token,
          frameId: _frame!.id,
        );

        if (result != null) {
          setState(() {
            _isFavorite = true;
            _favoriteId = result['_id'] as String?;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Added to favorites'),
              backgroundColor: Color(0xFF275BCD),
              duration: Duration(seconds: 2),
            ),
          );
        }
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: ${e.toString().replaceAll('Exception: ', '')}'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 2),
        ),
      );
    } finally {
      setState(() => _isFavoriteLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text(
          'Frame Details',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.black,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          // Favorite button with loading state
          _isFavoriteLoading
              ? Container(
            padding: const EdgeInsets.all(12),
            child: const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(Colors.red),
              ),
            ),
          )
              : IconButton(
            icon: Icon(
              _isFavorite ? Icons.favorite : Icons.favorite_border,
              color: _isFavorite ? Colors.red : Colors.black,
            ),
            onPressed: _toggleFavorite,
          ),
        ],
      ),
      body: _buildContent(),
    );
  }

  Widget _buildContent() {
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
              onPressed: _loadFrameDetails,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF275BCD),
              ),
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    if (_frame == null) {
      return const Center(
        child: Text('Frame not found'),
      );
    }

    final frame = _frame!;

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Image Gallery
          _buildImageGallery(frame),

          // Frame Info
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Brand and Name
                Text(
                  frame.brand,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: Colors.grey,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  frame.name,
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                  ),
                ),
                const SizedBox(height: 16),

                // Price and Rating
                Row(
                  children: [
                    Text(
                      frame.displayPrice,
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF275BCD),
                      ),
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.amber.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.star, size: 16, color: Colors.amber),
                          const SizedBox(width: 4),
                          const Text(
                            '5.0',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: Colors.black,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '(10)',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  '${frame.quantity} Sold',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[600],
                  ),
                ),
                const SizedBox(height: 24),

                // Description
                if (frame.description?.isNotEmpty ?? false) ...[
                  const Text(
                    'Description',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.black,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    frame.description!,
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey[700],
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 24),
                ],

                // Specifications
                const Text(
                  'Specifications',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                  ),
                ),
                const SizedBox(height: 12),
                _buildSpecificationItem('Type', frame.type),
                _buildSpecificationItem('Shape', frame.shape),
                _buildSpecificationItem('Size', frame.size),
                if (frame.colors.isNotEmpty)
                  _buildSpecificationItem('Colors', frame.colors.join(', ')),
                const SizedBox(height: 24),

                // Action Buttons
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () {
                          // Try on action
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF275BCD),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        icon: const Icon(Icons.camera_alt),
                        label: const Text(
                          'Try On',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () async {
                          final authProvider = Provider.of<AuthProvider>(context, listen: false);
                          final token = authProvider.token;

                          if (token == null) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Please login to add items to cart'),
                                backgroundColor: Colors.red,
                              ),
                            );
                            return;
                          }

                          final cartProvider = Provider.of<CartProvider>(context, listen: false);
                          final success = await cartProvider.addToCart(
                            token: token,
                            frameId: frame.id,
                            quantity: 1,
                          );

                          if (success) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Added ${frame.name} to cart'),
                                backgroundColor: Colors.green,
                                duration: const Duration(seconds: 2),
                              ),
                            );
                          } else {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(cartProvider.errorMessage),
                                backgroundColor: Colors.red,
                              ),
                            );
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: const Color(0xFF275BCD),
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                            side: const BorderSide(
                              color: Color(0xFF275BCD),
                              width: 1,
                            ),
                          ),
                        ),
                        icon: const Icon(Icons.add_shopping_cart),
                        label: const Text(
                          'Add to Cart',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () {
                          // Navigate to OrderNowScreen
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => OrderNowScreen(
                                frame: frame,
                                quantity: 1,
                              ),
                            ),
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        icon: const Icon(Icons.shopping_bag),
                        label: const Text(
                          'Order Now',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildImageGallery(Frame frame) {
    return Column(
      children: [
        // Main Image
        Container(
          height: 300,
          color: Colors.grey[100],
          child: Center(
            child: Image.network(
              frame.getImageUrl(_selectedImageIndex),
              fit: BoxFit.contain,
              loadingBuilder: (context, child, loadingProgress) {
                if (loadingProgress == null) return child;
                return const Center(
                  child: CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF275BCD)),
                  ),
                );
              },
              errorBuilder: (context, error, stackTrace) {
                return Container(
                  color: Colors.grey[100],
                  child: const Center(
                    child: Icon(
                      Icons.image,
                      size: 60,
                      color: Colors.grey,
                    ),
                  ),
                );
              },
            ),
          ),
        ),

        // Thumbnail Images
        if (frame.imageUrls.length > 1)
          Container(
            height: 80,
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: frame.imageUrls.length,
              itemBuilder: (context, index) {
                return GestureDetector(
                  onTap: () {
                    setState(() {
                      _selectedImageIndex = index;
                    });
                  },
                  child: Container(
                    width: 60,
                    height: 60,
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: _selectedImageIndex == index
                            ? const Color(0xFF275BCD)
                            : Colors.transparent,
                        width: 2,
                      ),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: Image.network(
                        frame.imageUrls[index],
                        fit: BoxFit.cover,
                        loadingBuilder: (context, child, loadingProgress) {
                          if (loadingProgress == null) return child;
                          return const Center(
                            child: SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                              ),
                            ),
                          );
                        },
                        errorBuilder: (context, error, stackTrace) {
                          return Container(
                            color: Colors.grey[200],
                            child: const Icon(Icons.image),
                          );
                        },
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
      ],
    );
  }

  Widget _buildSpecificationItem(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 2,
            child: Text(
              '$label:',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: Colors.grey[700],
              ),
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w400,
                color: Colors.black,
              ),
            ),
          ),
        ],
      ),
    );
  }
}