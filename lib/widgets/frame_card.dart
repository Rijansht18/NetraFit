import 'package:flutter/material.dart';
import '../models/frame_model.dart';

class FrameCard extends StatelessWidget {
  final Frame frame;
  final bool isSelected;
  final VoidCallback onTap;
  final bool showShape;

  const FrameCard({
    super.key,
    required this.frame,
    required this.isSelected,
    required this.onTap,
    this.showShape = false,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: isSelected ? Colors.blue : Colors.grey.shade300,
          width: isSelected ? 2 : 1,
        ),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(8.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Frame image
              Container(
                height: 60,
                width: double.infinity,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  image: DecorationImage(
                    image: NetworkImage(
                      'https://violetlike-onward-marley.ngrok-free.dev/frame_image/${frame.filename}',
                    ),
                    fit: BoxFit.contain,
                    onError: (exception, stackTrace) {
                      // Handle image loading errors
                    },
                  ),
                ),
              ),
              const SizedBox(height: 8),

              // Frame name
              Text(
                frame.name,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: isSelected ? Colors.blue : Colors.black87,
                ),
                maxLines: 2,
                textAlign: TextAlign.center,
                overflow: TextOverflow.ellipsis,
              ),

              // Frame shape (if enabled)
              if (showShape && frame.shape != null && frame.shape!.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: _getShapeColor(frame.shape!),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      frame.shape!,
                      style: const TextStyle(
                        fontSize: 10,
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Color _getShapeColor(String shape) {
    switch (shape.toLowerCase()) {
      case 'round':
        return Colors.blue;
      case 'rectangle':
        return Colors.green;
      case 'square':
        return Colors.orange;
      case 'aviator':
        return Colors.purple;
      case 'geometric':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }
}