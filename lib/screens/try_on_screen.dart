import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:provider/provider.dart';
import '../providers/frame_provider.dart';
import '../widgets/frame_card.dart';
import '../widgets/size_selector.dart';

class TryOnScreen extends StatefulWidget {
  final List<String>? recommendedFrameFilenames;

  const TryOnScreen({super.key, this.recommendedFrameFilenames});

  @override
  State<TryOnScreen> createState() => _TryOnScreenState();
}

class _TryOnScreenState extends State<TryOnScreen> {
  late WebViewController _webViewController;
  String _selectedFrame = '';
  String _selectedSize = 'medium';
  bool _isLoading = true;
  bool _hasError = false;
  bool _isPageLoaded = false;
  bool _framesLoaded = false;

  final Map<String, String> frameSizes = {
    'small': 'Small',
    'medium': 'Medium',
    'large': 'Large',
  };

  @override
  void initState() {
    super.initState();
    _initializeWebView();
    _loadFrames();
  }

  void _loadFrames() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final frameProvider = Provider.of<FrameProvider>(context, listen: false);
      if (frameProvider.frames.isEmpty) {
        frameProvider.loadFrames().then((_) {
          if (mounted) {
            setState(() {
              _framesLoaded = true;
            });
            _autoSelectFrame(frameProvider);
          }
        });
      } else {
        setState(() {
          _framesLoaded = true;
        });
        _autoSelectFrame(frameProvider);
      }
    });
  }

  void _autoSelectFrame(FrameProvider frameProvider) {
    if (frameProvider.frames.isNotEmpty && _selectedFrame.isEmpty) {
      if (widget.recommendedFrameFilenames != null &&
          widget.recommendedFrameFilenames!.isNotEmpty) {
        setState(() {
          _selectedFrame = widget.recommendedFrameFilenames!.first;
        });
      } else {
        setState(() {
          _selectedFrame = frameProvider.frames.first.filename;
        });
      }
    }
  }

  void _initializeWebView() {
    _webViewController = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(const Color(0x00000000))
      ..setNavigationDelegate(
        NavigationDelegate(
          onProgress: (int progress) {
            print('Loading progress: $progress%');
          },
          onPageStarted: (String url) {
            setState(() {
              _isLoading = true;
              _hasError = false;
              _isPageLoaded = false;
            });
          },
          onPageFinished: (String url) {
            setState(() {
              _isLoading = false;
              _isPageLoaded = true;
            });
            print('Page loaded: $url');
            // Inject CSS to hide controls and show only camera
            _hideWebControls();
          },
          onWebResourceError: (WebResourceError error) {
            setState(() {
              _isLoading = false;
              _hasError = true;
            });
            print('WebResourceError: ${error.errorCode} - ${error.description}');
          },
        ),
      )
      ..loadRequest(Uri.parse('http://192.168.1.80:5000/real_time'));
  }

  void _hideWebControls() {
    // Since your Flask app uses /video_feed which returns an image stream,
    // let's target the image element specifically
    final targetedJS = """
    // Targeted approach for Flask video_feed
    function setupCleanCameraView() {
      console.log('Setting up clean camera view for Flask...');
      
      // Clean up body
      document.body.style.margin = '0';
      document.body.style.padding = '0';
      document.body.style.overflow = 'hidden';
      document.body.style.background = 'black';
      document.body.style.width = '100vw';
      document.body.style.height = '100vh';
      
      // Look for the camera image (from /video_feed)
      let cameraImg = null;
      
      // Method 1: Look for img tags that might be the camera
      const allImages = document.querySelectorAll('img');
      for (let img of allImages) {
        const src = img.src || '';
        if (src.includes('video_feed') || img.alt.includes('camera') || 
            img.id.includes('video') || img.className.includes('video')) {
          cameraImg = img;
          break;
        }
      }
      
      // Method 2: If no specific image found, take the largest visible image
      if (!cameraImg) {
        let largestImg = null;
        let maxArea = 0;
        
        allImages.forEach(img => {
          const rect = img.getBoundingClientRect();
          const area = rect.width * rect.height;
          if (area > maxArea && rect.width > 100 && rect.height > 100) {
            maxArea = area;
            largestImg = img;
          }
        });
        
        cameraImg = largestImg;
      }
      
      if (cameraImg) {
        console.log('Found camera image:', cameraImg.src);
        
        // Hide all other elements except the camera image and its parents
        const hideElement = (el) => {
          if (el === cameraImg || el.contains(cameraImg)) {
            // This is the camera or its container, don't hide but clean up
            el.style.margin = '0';
            el.style.padding = '0';
            el.style.background = 'transparent';
            el.style.border = 'none';
            el.style.width = '100%';
            el.style.height = '100%';
          } else {
            // Hide other elements
            el.style.display = 'none';
          }
        };
        
        // Hide all children of body
        Array.from(document.body.children).forEach(hideElement);
        
        // Make camera image full screen
        cameraImg.style.position = 'fixed';
        cameraImg.style.top = '0';
        cameraImg.style.left = '0';
        cameraImg.style.width = '100%';
        cameraImg.style.height = '100%';
        cameraImg.style.objectFit = 'cover';
        cameraImg.style.zIndex = '9999';
        
      } else {
        console.log('No camera image found. Page structure:');
        console.log('Body children:', document.body.children.length);
        Array.from(document.body.children).forEach((child, i) => {
          console.log('Child ' + i + ':', child.tagName, child.id, child.className);
        });
      }
    }
    
    setupCleanCameraView();
    
    // Keep trying as page loads
    const interval = setInterval(setupCleanCameraView, 500);
    setTimeout(() => clearInterval(interval), 5000);
  """;

    _webViewController.runJavaScript(targetedJS);
  }

  void _changeFrame(String frameFilename) {
    setState(() {
      _selectedFrame = frameFilename;
    });

    final javascript = """
      fetch('/change_frame', {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({
          frame: '$frameFilename',
          size: '$_selectedSize'
        })
      }).then(response => {
        console.log('Frame changed to: $frameFilename');
      }).catch(error => {
        console.log('Frame change error:', error);
      });
    """;

    _webViewController.runJavaScript(javascript);
  }

  void _changeSize(String size) {
    setState(() {
      _selectedSize = size;
    });

    final javascript = """
      fetch('/change_frame', {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({
          frame: '$_selectedFrame',
          size: '$size'
        })
      }).then(response => {
        console.log('Size changed to: $size');
      }).catch(error => {
        console.log('Size change error:', error);
      });
    """;

    _webViewController.runJavaScript(javascript);
  }

  void _refreshCameraView() {
    // Refresh the page to ensure clean camera view
    _webViewController.reload();
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
              'Connection Failed',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              'Make sure Flask server is running\nat 192.168.1.80:5000',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _initializeWebView,
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    return Stack(
      children: [
        WebViewWidget(controller: _webViewController),

        if (_isLoading)
          Container(
            color: Colors.black,
            child: const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(color: Colors.white),
                  SizedBox(height: 16),
                  Text(
                    'Loading Camera...',
                    style: TextStyle(color: Colors.white),
                  ),
                ],
              ),
            ),
          ),

        // Refresh button - only show when page is loaded
        if (_isPageLoaded && !_isLoading)
          Positioned(
            top: 10,
            right: 10,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.7),
                borderRadius: BorderRadius.circular(20),
              ),
              child: IconButton(
                icon: const Icon(Icons.refresh, color: Colors.white),
                onPressed: _refreshCameraView,
                tooltip: 'Refresh Camera',
              ),
            ),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final frameProvider = Provider.of<FrameProvider>(context);

    return Scaffold(
      body: Column(
        children: [
          // Camera View Section
          Expanded(
            flex: 3,
            child: Container(
              color: Colors.black,
              child: _buildWebViewContent(),
            ),
          ),

          // Flutter Controls Section
          Expanded(
            flex: 2,
            child: Container(
              color: Colors.white,
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    // Size Selector
                    SizeSelector(
                      sizes: frameSizes,
                      selectedSize: _selectedSize,
                      onSizeSelected: _changeSize,
                    ),

                    const SizedBox(height: 16),

                    // Frame Selection
                    Container(
                      height: 140,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Select Frame:',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Expanded(
                            child: !_framesLoaded || frameProvider.isLoading
                                ? const Center(child: CircularProgressIndicator())
                                : _buildFrameList(frameProvider),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFrameList(FrameProvider frameProvider) {
    final framesToShow = widget.recommendedFrameFilenames != null &&
        widget.recommendedFrameFilenames!.isNotEmpty
        ? frameProvider.frames.where((frame) =>
        widget.recommendedFrameFilenames!.contains(frame.filename)).toList()
        : frameProvider.frames;

    if (framesToShow.isEmpty) {
      return const Center(
        child: Text(
          'No frames available',
          style: TextStyle(color: Colors.grey),
        ),
      );
    }

    return ListView.builder(
      scrollDirection: Axis.horizontal,
      itemCount: framesToShow.length,
      itemBuilder: (context, index) {
        final frame = framesToShow[index];
        return Container(
          width: 110,
          margin: const EdgeInsets.only(right: 8),
          child: FrameCard(
            frame: frame,
            isSelected: _selectedFrame == frame.filename,
            onTap: () => _changeFrame(frame.filename),
          ),
        );
      },
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Ensure frames are loaded when dependencies change (like when coming back from another screen)
    if (!_framesLoaded) {
      _loadFrames();
    }
  }
}