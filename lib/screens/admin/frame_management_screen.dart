import 'package:flutter/material.dart';
import '../../services/frame_service.dart';
import '../../models/api_response.dart';
import '../../models/frame_model.dart';
import 'frame_webview_screen.dart'; // Import the new WebView screen

class FrameManagementScreen extends StatefulWidget {
  const FrameManagementScreen({Key? key}) : super(key: key);

  @override
  State<FrameManagementScreen> createState() => _FrameManagementScreenState();
}

class _FrameManagementScreenState extends State<FrameManagementScreen> {
  final FrameService _frameService = FrameService();
  List<Frame> _frames = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadFrames();
  }

  Future<void> _loadFrames() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final ApiResponse response = await _frameService.getAllFrames();
      if (response.success == true) {
        final framesData = response.data?['data'] as List? ?? [];
        setState(() {
          _frames = framesData.map((frameData) => Frame.fromJson(frameData)).toList();
        });
      } else {
        _showErrorDialog(response.error ?? 'Failed to load frames');
      }
    } catch (e) {
      _showErrorDialog('Network error: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  // Navigate to Add Frame WebView
  void _navigateToAddFrame() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const FrameWebViewScreen(),
      ),
    ).then((value) {
      // Refresh frames list if a frame was added/updated
      if (value == true) {
        _loadFrames();
      }
    });
  }

  // Navigate to Edit Frame WebView
  void _navigateToEditFrame(Frame frame) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => FrameWebViewScreen(frame: frame),
      ),
    ).then((value) {
      // Refresh frames list if a frame was updated
      if (value == true) {
        _loadFrames();
      }
    });
  }

  Future<void> _deleteFrame(String frameId, String frameName) async {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Frame'),
        content: Text('Are you sure you want to delete "$frameName"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              _confirmDeleteFrame(frameId);
            },
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmDeleteFrame(String frameId) async {
    try {
      final ApiResponse response = await _frameService.deleteFrame(frameId);
      if (response.success == true) {
        _showSuccessDialog('Frame deleted successfully');
        _loadFrames();
      } else {
        _showErrorDialog(response.error ?? 'Failed to delete frame');
      }
    } catch (e) {
      _showErrorDialog('Network error: $e');
    }
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.error_outline, color: Colors.red),
            SizedBox(width: 8),
            Text('Error'),
          ],
        ),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _showSuccessDialog(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.check_circle, color: Colors.green),
            SizedBox(width: 8),
            Text('Success'),
          ],
        ),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Frame Management'),
        backgroundColor: const Color(0xFF275BCD),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadFrames,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _navigateToAddFrame,
        backgroundColor: const Color(0xFF275BCD),
        child: const Icon(Icons.add),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _frames.isEmpty
          ? _buildEmptyState()
          : _buildFrameList(),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.inventory, size: 64, color: Colors.grey),
          const SizedBox(height: 16),
          const Text(
            'No frames found',
            style: TextStyle(fontSize: 16, color: Colors.grey),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: _navigateToAddFrame,
            child: const Text('Add First Frame'),
          ),
        ],
      ),
    );
  }

  Widget _buildFrameList() {
    return ListView.builder(
      itemCount: _frames.length,
      itemBuilder: (context, index) {
        final frame = _frames[index];
        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: ListTile(
            leading: frame.imageUrls.isNotEmpty
                ? Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                image: DecorationImage(
                  image: NetworkImage(frame.imageUrls.first),
                  fit: BoxFit.cover,
                ),
              ),
            )
                : const Icon(Icons.photo, size: 40),
            title: Text(
              frame.name,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Brand: ${frame.brand}'),
                Text('Price: \ रु ${frame.price.toStringAsFixed(2)}'),
                Text('Stock: ${frame.quantity}'),
                Text('Colors: ${frame.colors.join(', ')}'),
                if (frame.mainCategoryName != null && frame.subCategoryName != null)
                  Text('Category: ${frame.mainCategoryName} > ${frame.subCategoryName}'),
              ],
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.edit, color: Colors.blue),
                  onPressed: () => _navigateToEditFrame(frame),
                ),
                IconButton(
                  icon: const Icon(Icons.delete, color: Colors.red),
                  onPressed: () => _deleteFrame(frame.id, frame.name),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}