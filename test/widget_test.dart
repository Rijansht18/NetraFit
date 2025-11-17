// Add this import at the top
import 'dart:io';

// Add this method to test connection
Future<void> testServerConnection() async {
  try {
    final client = HttpClient();
    final request = await client.getUrl(Uri.parse('http://192.168.1.80:5000/'));
    final response = await request.close();
    print('✅ Server connection test: ${response.statusCode}');
    if (response.statusCode == 200) {
      print('✅ Server is reachable and responding');
    }
  } catch (e) {
    print('❌ Server connection test failed: $e');
  }
}