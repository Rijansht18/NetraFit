import 'dart:ui';

import 'package:flutter/material.dart';

enum FaceShape {
  oval,
  round,
  square,
  heart,
  diamond,
  oblong,
  unknown
}

extension FaceShapeExtension on FaceShape {
  String get name {
    switch (this) {
      case FaceShape.oval:
        return 'Oval';
      case FaceShape.round:
        return 'Round';
      case FaceShape.square:
        return 'Square';
      case FaceShape.heart:
        return 'Heart';
      case FaceShape.diamond:
        return 'Diamond';
      case FaceShape.oblong:
        return 'Oblong';
      case FaceShape.unknown:
        return 'No Face Detected';
    }
  }

  Color get color {
    switch (this) {
      case FaceShape.oval:
        return Colors.green;
      case FaceShape.round:
        return Colors.blue;
      case FaceShape.square:
        return Colors.orange;
      case FaceShape.heart:
        return Colors.pink;
      case FaceShape.diamond:
        return Colors.purple;
      case FaceShape.oblong:
        return Colors.teal;
      case FaceShape.unknown:
        return Colors.grey;
    }
  }

  String get description {
    switch (this) {
      case FaceShape.oval:
        return 'Balanced and symmetrical face shape';
      case FaceShape.round:
        return 'Full cheeks with soft angles';
      case FaceShape.square:
        return 'Strong jawline and forehead';
      case FaceShape.heart:
        return 'Wide forehead and narrow chin';
      case FaceShape.diamond:
        return 'Wide cheekbones, narrow forehead and jaw';
      case FaceShape.oblong:
        return 'Long and narrow face shape';
      case FaceShape.unknown:
        return 'Position your face in the camera';
    }
  }
}