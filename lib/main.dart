import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'screens/face_detection_screen.dart';

List<CameraDescription> cameras = [];

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    cameras = await availableCameras();
  } on CameraException catch (e) {
    print('Camera Error: $e');
  }

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Netrafit - Face Shape Detector',
      theme: ThemeData(
        primarySwatch: Colors.deepPurple,
        useMaterial3: true,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      home: const FaceDetectionScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}