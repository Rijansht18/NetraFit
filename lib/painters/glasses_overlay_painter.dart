import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import '../models/glass_model.dart';

class GlassesOverlayPainter extends CustomPainter {
  final List<Face> faces;
  final Size imageSize;
  final CameraLensDirection cameraLensDirection;
  final GlassModel glasses;
  final ui.Image? glassesImage;

  // Improved calibration factors
  static const double glassesWidthFactor = 2.6;
  static const double verticalPositionOffset = -0.15;
  static const double bridgeAdjustment = 0.05;
  static const double rotationCorrection = 0.1;

  GlassesOverlayPainter({
    super.repaint,
    required this.faces,
    required this.imageSize,
    required this.cameraLensDirection,
    required this.glasses,
    required this.glassesImage,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (glassesImage == null) return;
    if (faces.isEmpty) return;

    for (var face in faces) {
      final leftEye = face.landmarks[FaceLandmarkType.leftEye];
      final rightEye = face.landmarks[FaceLandmarkType.rightEye];
      final noseBase = face.landmarks[FaceLandmarkType.noseBase];

      if (leftEye == null || rightEye == null || noseBase == null) {
        continue;
      }

      // Get the raw landmark positions
      final leftEyePos = leftEye.position;
      final rightEyePos = rightEye.position;
      final noseBasePos = noseBase.position;

      // Convert to screen coordinates
      final leftEyePoint = _landmarkToScreenPoint(leftEyePos, size);
      final rightEyePoint = _landmarkToScreenPoint(rightEyePos, size);
      final noseBasePoint = _landmarkToScreenPoint(noseBasePos, size);

      // Calculate the center between eyes
      final eyesCenter = Offset(
        (leftEyePoint.dx + rightEyePoint.dx) / 2,
        (leftEyePoint.dy + rightEyePoint.dy) / 2,
      );

      // Calculate distance between eyes for scaling
      final eyeDistance = (leftEyePoint - rightEyePoint).distance;

      // Use nose position for better vertical placement
      final noseToEyesDistance = (noseBasePoint - eyesCenter).distance;

      // Calculate glasses size
      final glassesWidth = eyeDistance * glassesWidthFactor;
      final aspectRatio = glassesImage!.height / glassesImage!.width;
      final glassesHeight = glassesWidth * aspectRatio;

      // Improved positioning: Use nose reference for better vertical placement
      final glassesCenter = Offset(
        eyesCenter.dx,
        eyesCenter.dy + (noseToEyesDistance * verticalPositionOffset),
      );

      // Calculate rotation based on eye alignment with nose reference
      var angle = math.atan2(
        rightEyePoint.dy - leftEyePoint.dy,
        rightEyePoint.dx - leftEyePoint.dx,
      );

      // Add nose-based rotation correction
      final noseAngle = math.atan2(
        noseBasePoint.dy - eyesCenter.dy,
        noseBasePoint.dx - eyesCenter.dx,
      );
      angle += noseAngle * rotationCorrection;

      // Mirror correction for front camera
      if (cameraLensDirection == CameraLensDirection.front) {
        angle = -angle;
      }

      canvas.save();

      // Move to glasses position
      canvas.translate(glassesCenter.dx, glassesCenter.dy);

      // Apply rotation
      canvas.rotate(angle);

      // Draw the glasses with high quality
      final srcRect = Rect.fromLTWH(0, 0, glassesImage!.width.toDouble(), glassesImage!.height.toDouble());
      final dstRect = Rect.fromCenter(
        center: Offset.zero,
        width: glassesWidth,
        height: glassesHeight,
      );

      canvas.drawImageRect(
        glassesImage!,
        srcRect,
        dstRect,
        Paint()
          ..filterQuality = FilterQuality.high
          ..isAntiAlias = true,
      );

      canvas.restore();
    }
  }

  Offset _landmarkToScreenPoint(math.Point<int> landmark, Size screenSize) {
    // Calculate the aspect ratios
    final imageAspect = imageSize.width / imageSize.height;
    final screenAspect = screenSize.width / screenSize.height;

    double x, y;

    if (cameraLensDirection == CameraLensDirection.front) {
      // Front camera - mirror horizontally for natural feel
      x = screenSize.width - (landmark.x / imageSize.width) * screenSize.width;
    } else {
      // Back camera - direct mapping
      x = (landmark.x / imageSize.width) * screenSize.width;
    }

    // Y coordinate - account for different aspect ratios
    if (imageAspect > screenAspect) {
      // Image is wider than screen - letterboxing on top/bottom
      final scale = screenSize.width / imageSize.width;
      final scaledHeight = imageSize.height * scale;
      final verticalOffset = (screenSize.height - scaledHeight) / 2;
      y = (landmark.y * scale) + verticalOffset;
    } else {
      // Image is taller than screen - letterboxing on sides
      final scale = screenSize.height / imageSize.height;
      final scaledWidth = imageSize.width * scale;
      final horizontalOffset = (screenSize.width - scaledWidth) / 2;
      x = (landmark.x * scale) + horizontalOffset;
      y = landmark.y * scale;
    }

    return Offset(x, y);
  }

  @override
  bool shouldRepaint(GlassesOverlayPainter oldDelegate) {
    return oldDelegate.faces != faces ||
        oldDelegate.glasses != glasses ||
        oldDelegate.glassesImage != glassesImage;
  }
}