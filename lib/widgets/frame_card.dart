import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../core/config/api_config.dart';   // <- contains ApiUrl.baseBackendUrl
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

  /* -------------------------------------------------
   * 1.  PUBLIC IMAGE URL  (fast path)
   * 2.  FALLBACK: download bytes via auth endpoint
   * ------------------------------------------------- */
  Future<Uint8List?> _fetchImageBytes() async {
    if (frame.imageUrls.isNotEmpty) {
      // Try public URL first
      try {
        final res = await http.get(Uri.parse(frame.imageUrls.first));
        if (res.statusCode == 200) return res.bodyBytes;
      } catch (_) {}
    }

    // Fallback: authenticated endpoint
    final url =
        '${ApiUrl.baseBackendUrl}/frames/images/${frame.id}/0'; // no brackets
    try {
      final res = await http.get(
        Uri.parse(url),
      );
      if (res.statusCode == 200) return res.bodyBytes;
    } catch (_) {}
    return null;
  }

  @override
  Widget build(BuildContext context) {
    debugPrint('🔍 FrameCard >>> '
        'id=${frame.id} | '
        'name=${frame.name} | '
        'shape=${frame.shape} | '
        'imageUrls=${frame.imageUrls} |'
        'image=${ApiUrl.baseBackendUrl}/frames/images/${frame.id}/0'
    );

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
              /* ---------- IMAGE AREA ---------- */
              SizedBox(
                height: 60,
                width: double.infinity,
                child: FutureBuilder<Uint8List?>(
                  future: _fetchImageBytes(),
                  builder: (context, snap) {
                    if (snap.connectionState == ConnectionState.waiting) {
                      return const Center(
                          child: SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(strokeWidth: 2)));
                    }
                    if (snap.hasData && snap.data != null) {
                      return ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.memory(
                          snap.data!,
                          fit: BoxFit.contain,
                        ),
                      );
                    }
                    // error / no data
                    return const Icon(Icons.broken_image,
                        size: 60, color: Colors.grey);
                  },
                ),
              ),
              const SizedBox(height: 8),

              /* ---------- NAME ---------- */
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

              /* ---------- SHAPE CHIP ---------- */
              if (showShape && frame.shape.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Container(
                    padding:
                    const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: _getShapeColor(frame.shape),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      frame.shape,
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