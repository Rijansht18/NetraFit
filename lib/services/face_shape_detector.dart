import 'dart:math';
import 'dart:math' as math;
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import '../models/face_shape.dart';

class FaceShapeDetectorService {
  final FaceDetector _faceDetector;
  bool _isProcessing = false;

  FaceShapeDetectorService()
      : _faceDetector = FaceDetector(
    options: FaceDetectorOptions(
      enableContours: true,
      enableClassification: true,
      enableLandmarks: true,
      enableTracking: true,
      performanceMode: FaceDetectorMode.accurate,
      minFaceSize: 0.1,
    ),
  );

  Future<FaceShape> detectFaceShape(InputImage inputImage) async {
    if (_isProcessing) return FaceShape.unknown;

    _isProcessing = true;
    try {
      final faces = await _faceDetector.processImage(inputImage);

      if (faces.isEmpty) return FaceShape.unknown;

      final face = faces.first;
      return _analyzeFaceShape(face);
    } catch (e) {
      return FaceShape.unknown;
    } finally {
      _isProcessing = false;
    }
  }

  FaceShape _analyzeFaceShape(Face face) {
    try {
      // Get face bounding box
      final rect = face.boundingBox;

      // Calculate face dimensions
      final faceWidth = rect.width.toDouble();
      final faceHeight = rect.height.toDouble();

      // Calculate face ratio
      final heightToWidthRatio = faceHeight / faceWidth;

      // Get landmarks for more accurate analysis
      final leftMouth = face.landmarks[FaceLandmarkType.leftMouth];
      final rightMouth = face.landmarks[FaceLandmarkType.rightMouth];
      final leftCheek = face.landmarks[FaceLandmarkType.leftCheek];
      final rightCheek = face.landmarks[FaceLandmarkType.rightCheek];

      // Estimate jaw width using mouth landmarks
      double jawWidth = faceWidth;
      if (leftMouth != null && rightMouth != null) {
        jawWidth = _calculateDistance(
          leftMouth.position,
          rightMouth.position,
        ) * 1.3; // Adjustment factor
      }

      // Estimate forehead width (typically narrower than face width)
      double foreheadWidth = faceWidth * 0.8;
      if (leftCheek != null && rightCheek != null) {
        foreheadWidth = _calculateDistance(leftCheek.position, rightCheek.position) * 0.9;
      }

      final jawToForeheadRatio = jawWidth / foreheadWidth;

      return _determineShape(
        heightToWidthRatio,
        jawToForeheadRatio,
        faceWidth,
        jawWidth,
      );
    } catch (e) {
      return FaceShape.unknown;
    }
  }

  FaceShape _determineShape(
      double heightToWidth,
      double jawToForehead,
      double faceWidth,
      double jawWidth,
      ) {
    // Adjusted thresholds based on testing
    if (heightToWidth > 1.5) {
      return FaceShape.oblong;
    } else if (heightToWidth < 1.0) {
      return FaceShape.round;
    } else if (jawToForehead > 1.1) {
      return FaceShape.heart;
    } else if (jawToForehead < 0.9) {
      return FaceShape.diamond;
    } else if ((faceWidth - jawWidth).abs() < faceWidth * 0.1) {
      return FaceShape.square;
    } else {
      return FaceShape.oval;
    }
  }

  double _calculateDistance(math.Point<int> point1, math.Point<int> point2) {
    final dx = point1.x - point2.x;
    final dy = point1.y - point2.y;
    return sqrt(dx * dx + dy * dy);
  }

  void dispose() {
    _faceDetector.close();
  }
}