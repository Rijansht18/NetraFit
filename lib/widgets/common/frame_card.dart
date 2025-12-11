import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:netrafit/models/frame_model.dart';
import 'package:netrafit/providers/favorites_provider.dart';
import 'package:netrafit/services/favorites_service.dart';
import '../../providers/auth_provider.dart';
import '../../screens/FrameDetailsScreen.dart';
import '../../screens/main_try_on_screen.dart'; // Add this import

class FrameCard extends StatefulWidget {
  final Frame frame;
  final double? height;
  final double? width;
  final bool showCartButton;

  const FrameCard({
    Key? key,
    required this.frame,
    this.height,
    this.width,
    this.showCartButton = false,
  }) : super(key: key);

  @override
  State<FrameCard> createState() => _FrameCardState();
}

class _FrameCardState extends State<FrameCard> {
  bool _isFavorite = false;
  bool _isLoading = false;
  String? _favoriteId;

  @override
  void initState() {
    super.initState();
    _checkIfFavorite();
  }

  Future<void> _toggleFavorite() async {
    if (_isLoading) return;

    setState(() {
      _isLoading = true;
    });

    final favoritesProvider = Provider.of<FavoritesProvider>(context, listen: false);
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final token = authProvider.token;

    if (token == null || token.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please login to manage favorites'),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 2),
        ),
      );
      setState(() => _isLoading = false);
      return;
    }

    try {
      if (_isFavorite) {
        // REMOVE FROM FAVORITES
        print('Attempting to remove from favorites');
        print('Current favoriteId: $_favoriteId');
        print('Frame ID: ${widget.frame.id}');

        // First, try to get the favorite ID from the provider
        final existingFavorite = favoritesProvider.getFavoriteByFrameId(widget.frame.id);
        print('Existing favorite from provider: $existingFavorite');

        String? favoriteIdToRemove = _favoriteId;

        if (favoriteIdToRemove == null && existingFavorite != null) {
          favoriteIdToRemove = existingFavorite['_id'] as String?;
          print('Using favoriteId from provider: $favoriteIdToRemove');
        }

        if (favoriteIdToRemove != null) {
          print('Removing favorite with ID: $favoriteIdToRemove');

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
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Failed to remove from favorites'),
                backgroundColor: Colors.red,
                duration: Duration(seconds: 2),
              ),
            );
          }
        } else {
          print('Could not find favorite ID to remove');
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Favorite not found'),
              backgroundColor: Colors.red,
              duration: Duration(seconds: 2),
            ),
          );
        }
      } else {
        // ADD TO FAVORITES
        print('Adding frame to favorites: ${widget.frame.id}');

        final result = await favoritesProvider.addFavorite(
          token: token,
          frameId: widget.frame.id,
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
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Failed to add to favorites'),
              backgroundColor: Colors.red,
              duration: Duration(seconds: 2),
            ),
          );
        }
      }
    } catch (e) {
      print('Error in _toggleFavorite: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: ${e.toString().replaceAll('Exception: ', '')}'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 2),
        ),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _checkIfFavorite() {
    final favoritesProvider = Provider.of<FavoritesProvider>(context, listen: false);

    // Check if provider has loaded favorites
    if (favoritesProvider.favorites.isNotEmpty) {
      final favorite = favoritesProvider.getFavoriteByFrameId(widget.frame.id);

      if (favorite != null) {
        print('Found favorite for frame ${widget.frame.id}:');
        print('Favorite ID: ${favorite['_id']}');
        print('Frame ID from favorite: ${favorite['frameId']}');

        setState(() {
          _isFavorite = true;
          _favoriteId = favorite['_id'] as String?;
        });
      } else {
        print('No favorite found for frame ${widget.frame.id}');
        setState(() {
          _isFavorite = false;
          _favoriteId = null;
        });
      }
    } else {
      // If favorites haven't been loaded yet, set default state
      setState(() {
        _isFavorite = false;
        _favoriteId = null;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => FrameDetailsScreen(
              frameId: widget.frame.id,
              frame: widget.frame,
            ),
          ),
        );
      },
      child: Container(
        width: widget.width ?? 160,
        height: widget.height,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.1),
              spreadRadius: 1,
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: LayoutBuilder(
          builder: (context, constraints) {
            return Stack(
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Image Section
                    Container(
                      height: constraints.maxWidth * 0.8,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: Colors.grey[100],
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(12),
                          topRight: Radius.circular(12),
                        ),
                      ),
                      child: ClipRRect(
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(12),
                          topRight: Radius.circular(12),
                        ),
                        child: _buildImage(),
                      ),
                    ),

                    // Content Section
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            // Brand and Name
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  widget.frame.brand.isNotEmpty ? widget.frame.brand : 'Brand',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                    color: Colors.grey,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                  maxLines: 1,
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  widget.frame.name.isNotEmpty ? widget.frame.name : 'Frame Name',
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.black,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                  maxLines: 1,
                                ),
                              ],
                            ),

                            // Rating and Sold
                            Row(
                              children: [
                                const Icon(Icons.star, size: 12, color: Colors.amber),
                                const SizedBox(width: 4),
                                const Text(
                                  '5.0',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Colors.black,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                const SizedBox(width: 2),
                                const Text(
                                  '(10)',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Colors.grey,
                                  ),
                                ),
                                const Spacer(),
                                Text(
                                  '${widget.frame.quantity} Sold',
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: Colors.grey,
                                  ),
                                ),
                              ],
                            ),

                            // Price and Action Buttons
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                // Price
                                Text(
                                  'रु ${widget.frame.price.toInt()}',
                                  style: const TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF275BCD),
                                  ),
                                ),

                                // Action Buttons
                                Row(
                                  children: [
                                    // Try On Button - UPDATED
                                    Container(
                                      height: 28,
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF275BCD).withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(6),
                                        border: Border.all(
                                          color: const Color(0xFF275BCD),
                                          width: 1,
                                        ),
                                      ),
                                      child: Material(
                                        color: Colors.transparent,
                                        child: InkWell(
                                          onTap: () {
                                            print('Try On clicked for frame: ${widget.frame.name}');
                                            print('Frame ID: ${widget.frame.id}');
                                            print('Frame filename: ${widget.frame.filename}');

                                            Navigator.push(
                                              context,
                                              MaterialPageRoute(
                                                builder: (context) => MainTryOnScreen(
                                                  recommendedFrameId: widget.frame.id,
                                                  recommendedFrameFilenames: [widget.frame.filename],
                                                ),
                                              ),
                                            );
                                          },
                                          borderRadius: BorderRadius.circular(6),
                                          child: const Padding(
                                            padding: EdgeInsets.symmetric(
                                              horizontal: 10,
                                              vertical: 4,
                                            ),
                                            child: Text(
                                              'Try On',
                                              style: TextStyle(
                                                fontSize: 11,
                                                fontWeight: FontWeight.w600,
                                                color: Color(0xFF275BCD),
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),

                // Favorite Button (Top Right)
                Positioned(
                  top: 8,
                  right: 8,
                  child: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: () {
                          _toggleFavorite();
                        },
                        borderRadius: BorderRadius.circular(20),
                        child: Center(
                          child: _isLoading
                              ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.red),
                            ),
                          )
                              : Icon(
                            _isFavorite ? Icons.favorite : Icons.favorite_border,
                            color: _isFavorite ? Colors.red : Colors.grey[600],
                            size: 20,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildImage() {
    final imageUrl = widget.frame.firstImageUrl;

    return Image.network(
      imageUrl,
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
            strokeWidth: 2,
            valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF275BCD)),
          ),
        );
      },
      errorBuilder: (context, error, stackTrace) {
        return Container(
          color: Colors.grey[100],
          child: const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.image,
                  size: 30,
                  color: Colors.grey,
                ),
                SizedBox(height: 4),
                Text(
                  'No Image',
                  style: TextStyle(
                    fontSize: 10,
                    color: Colors.grey,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}