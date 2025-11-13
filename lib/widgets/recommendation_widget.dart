import 'package:flutter/material.dart';
import '../models/frame_model.dart';
import 'frame_card.dart';

class RecommendationWidget extends StatelessWidget {
  final List<Frame> frames;
  final Function(Frame) onFrameSelected;
  final String selectedFrame;

  const RecommendationWidget({
    super.key,
    required this.frames,
    required this.onFrameSelected,
    required this.selectedFrame,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Colors.green[50],
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.recommend, color: Colors.green),
                const SizedBox(width: 8),
                const Text(
                  'Recommended Frames',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.green,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            const Text(
              'These frames are recommended for your face shape',
              style: TextStyle(color: Colors.green),
            ),
            const SizedBox(height: 10),
            SizedBox(
              height: 200,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: frames.length,
                itemBuilder: (context, index) {
                  final frame = frames[index];
                  return Container(
                    width: 150,
                    margin: const EdgeInsets.only(right: 10),
                    child: FrameCard(
                      frame: frame,
                      isSelected: selectedFrame == frame.filename,
                      onTap: () => onFrameSelected(frame),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}