import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';
import 'package:webview_flutter_wkwebview/webview_flutter_wkwebview.dart';
import '../../core/config/api_config.dart';
import '../../models/frame_model.dart';

class FrameWebViewScreen extends StatefulWidget {
  final Frame? frame; // If null, it's add mode; if provided, it's edit mode
  final String? webViewUrl; // Optional custom URL

  const FrameWebViewScreen({
    Key? key,
    this.frame,
    this.webViewUrl,
  }) : super(key: key);

  @override
  State<FrameWebViewScreen> createState() => _FrameWebViewScreenState();
}

class _FrameWebViewScreenState extends State<FrameWebViewScreen> {
  late final WebViewController _controller;
  bool _isLoading = true;
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    _initializeWebView();
  }

  void _initializeWebView() {
    late final PlatformWebViewControllerCreationParams params;
    if (WebViewPlatform.instance is WebKitWebViewPlatform) {
      params = WebKitWebViewControllerCreationParams(
        allowsInlineMediaPlayback: true,
        mediaTypesRequiringUserAction: const <PlaybackMediaTypes>{},
      );
    } else {
      params = const PlatformWebViewControllerCreationParams();
    }

    final WebViewController controller = WebViewController.fromPlatformCreationParams(params);

    if (controller.platform is AndroidWebViewController) {
      AndroidWebViewController.enableDebugging(true);
      (controller.platform as AndroidWebViewController).setMediaPlaybackRequiresUserGesture(false);
    }

    controller
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(const Color(0x00000000))
      ..setNavigationDelegate(
        NavigationDelegate(
          onProgress: (int progress) {
            // Update loading bar.
          },
          onPageStarted: (String url) {
            setState(() {
              _isLoading = true;
              _hasError = false;
            });
          },
          onPageFinished: (String url) {
            setState(() {
              _isLoading = false;
            });

            // Inject frame data if in edit mode
            if (widget.frame != null) {
              _injectFrameData(widget.frame!);
            }
          },
          onWebResourceError: (WebResourceError error) {
            setState(() {
              _hasError = true;
              _isLoading = false;
            });
            print('WebView Error: ${error.description}');
          },
          onNavigationRequest: (NavigationRequest request) {
            // Handle navigation requests if needed
            return NavigationDecision.navigate;
          },
          onUrlChange: (UrlChange change) {
            print('URL changed to: ${change.url}');
          },
        ),
      )
      ..addJavaScriptChannel(
        'FlutterChannel',
        onMessageReceived: (JavaScriptMessage message) {
          _handleWebViewMessage(message.message);
        },
      )
      ..loadRequest(Uri.parse(_getWebViewUrl()));

    _controller = controller;
  }

  // In FrameWebViewScreen
  String _getWebViewUrl() {
    // Use custom URL if provided
    if (widget.webViewUrl != null) {
      return widget.webViewUrl!;
    }

    // Generate URL based on mode
    final baseUrl = ApiUrl.baseUrl; // This should be your Flask app URL
    if (widget.frame != null) {
      // Edit mode
      return '$baseUrl/frame_management/edit/${widget.frame!.id}';
    } else {
      // Add mode
      return '$baseUrl/frame_management/add';
    }
  }

  Future<void> _injectFrameData(Frame frame) async {
    try {
      // Prepare frame data for JavaScript
      final frameData = {
        'name': frame.name,
        'brand': frame.brand,
        'price': frame.price.toString(),
        'quantity': frame.quantity.toString(),
        'type': frame.type,
        'shape': frame.shape,
        'size': frame.size,
        'description': frame.description ?? '',
        'colors': frame.colors.join(','),
        'mainCategory': frame.mainCategory,
        'subCategory': frame.subCategory,
      };

      final jsonData = jsonEncode(frameData);

      // Inject the data into the webview
      await _controller.runJavaScript('''
        if (window.frameForm && window.frameForm.setFrameData) {
          window.frameForm.setFrameData($jsonData);
        }
      ''');

      print('Frame data injected successfully');
    } catch (e) {
      print('Error injecting frame data: $e');
    }
  }

  void _handleWebViewMessage(String message) {
    try {
      final data = jsonDecode(message);
      final type = data['type'];

      switch (type) {
        case 'frame_saved':
          final bool success = data['success'] ?? false;
          final bool isEdit = data['isEdit'] ?? false;

          if (success) {
            _showSuccessDialog(isEdit);
          }
          break;

        case 'cancel':
          Navigator.pop(context);
          break;

        default:
          print('Unknown message type: $type');
      }
    } catch (e) {
      print('Error parsing webview message: $e');
    }
  }

  void _showSuccessDialog(bool isEdit) {
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
        content: Text('Frame ${isEdit ? 'updated' : 'added'} successfully!'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context); // Close dialog
              Navigator.pop(context, true); // Return success to parent screen
            },
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  Future<void> _reloadWebView() async {
    setState(() {
      _hasError = false;
      _isLoading = true;
    });
    await _controller.reload();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.frame != null ? 'Edit Frame' : 'Add New Frame'),
        backgroundColor: const Color(0xFF275BCD),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _reloadWebView,
          ),
        ],
      ),
      body: _buildWebViewContent(),
    );
  }

  Widget _buildWebViewContent() {
    if (_hasError) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 64, color: Colors.red),
            const SizedBox(height: 16),
            const Text(
              'Failed to load form',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              'Please check your internet connection and try again',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _reloadWebView,
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    return Stack(
      children: [
        WebViewWidget(controller: _controller),
        if (_isLoading)
          Container(
            color: Colors.white,
            child: const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Loading form...'),
                ],
              ),
            ),
          ),
      ],
    );
  }
}