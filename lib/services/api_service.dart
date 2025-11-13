import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import '../models/frame_model.dart';

class ApiService {
  static const String baseUrl = 'http://192.168.1.80:5000'; // Change to your computer's IP

  // Get all available frames
  static Future<List<Frame>> getFrames() async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/api/frames'));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          List<Frame> frames = [];
          for (var frameData in data['frames']) {
            frames.add(Frame.fromJson(frameData));
          }
          return frames;
        }
      }
      throw Exception('Failed to load frames');
    } catch (e) {
      throw Exception('Network error: $e');
    }
  }

  // Analyze face from image
  static Future<Map<String, dynamic>> analyzeFace(File imageFile) async {
    try {
      var request = http.MultipartRequest(
        'POST',
        Uri.parse('$baseUrl/api/analyze_face'),
      );

      request.files.add(
        await http.MultipartFile.fromPath(
          'file',
          imageFile.path,
        ),
      );

      var response = await request.send();
      final responseData = await response.stream.bytesToString();
      final data = json.decode(responseData);

      if (response.statusCode == 200 && data['success'] == true) {
        return {
          'success': true,
          'face_shape': data['face_shape'],
          'message': data['message'],
        };
      } else {
        return {
          'success': false,
          'error': data['error'] ?? 'Analysis failed',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'error': 'Network error: $e',
      };
    }
  }

  // Try frame on image
  static Future<Map<String, dynamic>> tryFrame(
      File imageFile,
      String frameFilename,
      String size
      ) async {
    try {
      var request = http.MultipartRequest(
        'POST',
        Uri.parse('$baseUrl/api/try_frame'),
      );

      request.files.add(
        await http.MultipartFile.fromPath(
          'file',
          imageFile.path,
        ),
      );

      request.fields['frame'] = frameFilename;
      request.fields['size'] = size;

      var response = await request.send();
      final responseData = await response.stream.bytesToString();
      final data = json.decode(responseData);

      if (response.statusCode == 200 && data['success'] == true) {
        return {
          'success': true,
          'result_url': data['result_url'],
          'message': data['message'],
        };
      } else {
        return {
          'success': false,
          'error': data['error'] ?? 'Frame application failed',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'error': 'Network error: $e',
      };
    }
  }

  // Get recommendations for face shape
  static Future<List<Frame>> getRecommendations(String faceShape) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/api/recommendations/$faceShape'),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          List<Frame> frames = [];
          for (var frameData in data['recommended_frames']) {
            frames.add(Frame.fromJson(frameData));
          }
          return frames;
        }
      }
      throw Exception('Failed to load recommendations');
    } catch (e) {
      throw Exception('Network error: $e');
    }
  }

  // Process frame for real-time
  static Future<Map<String, dynamic>> processFrame(
      String imageData,
      String frameFilename,
      String size
      ) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/process_frame'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'image': imageData,
          'frame': frameFilename,
          'size': size,
        }),
      );

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        return {
          'success': false,
          'error': 'Server error: ${response.statusCode}',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'error': 'Network error: $e',
      };
    }
  }

  // Start real-time session
  static Future<Map<String, dynamic>> startRealtimeSession() async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/start_realtime'),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data;
      } else {
        throw Exception('Failed to start real-time session');
      }
    } catch (e) {
      throw Exception('Network error: $e');
    }
  }

  // Stop real-time session
  static Future<Map<String, dynamic>> stopRealtimeSession() async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/stop_realtime'),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data;
      } else {
        throw Exception('Failed to stop real-time session');
      }
    } catch (e) {
      throw Exception('Network error: $e');
    }
  }
}