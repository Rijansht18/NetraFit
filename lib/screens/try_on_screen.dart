import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:provider/provider.dart';
import '../providers/frame_provider.dart';
import '../widgets/frame_card.dart';

class TryOnScreen extends StatefulWidget {
  final List<String>? recommendedFrameFilenames;
  final bool showHeader; // Add this parameter

  const TryOnScreen({super.key, this.recommendedFrameFilenames, this.showHeader = false});

  @override
  State<TryOnScreen> createState() => _TryOnScreenState();
}

class _TryOnScreenState extends State<TryOnScreen> {
  late WebViewController _webViewController;
  String _selectedFrame = '';
  double _sizeValue = 1.0; // 0.8=small, 1.0=medium, 1.2=large
  bool _isLoading = true;
  bool _hasError = false;
  bool _isPageLoaded = false;
  bool _framesLoaded = false;

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
    final targetedJS = """
    function setupCleanCameraView() {
      document.body.style.margin = '0';
      document.body.style.padding = '0';
      document.body.style.overflow = 'hidden';
      document.body.style.background = 'black';
      document.body.style.width = '100vw';
      document.body.style.height = '100vh';
      
      let cameraImg = null;
      const allImages = document.querySelectorAll('img');
      for (let img of allImages) {
        const src = img.src || '';
        if (src.includes('video_feed') || img.alt.includes('camera') || 
            img.id.includes('video') || img.className.includes('video')) {
          cameraImg = img;
          break;
        }
      }
      
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
        const hideElement = (el) => {
          if (el === cameraImg || el.contains(cameraImg)) {
            el.style.margin = '0';
            el.style.padding = '0';
            el.style.background = 'transparent';
            el.style.border = 'none';
            el.style.width = '100%';
            el.style.height = '100%';
          } else {
            el.style.display = 'none';
          }
        };
        
        Array.from(document.body.children).forEach(hideElement);
        
        cameraImg.style.position = 'fixed';
        cameraImg.style.top = '0';
        cameraImg.style.left = '0';
        cameraImg.style.width = '100%';
        cameraImg.style.height = '100%';
        cameraImg.style.objectFit = 'cover';
        cameraImg.style.zIndex = '9999';
      }
    }
    
    setupCleanCameraView();
    const interval = setInterval(setupCleanCameraView, 500);
    setTimeout(() => clearInterval(interval), 5000);
  """;

    _webViewController.runJavaScript(targetedJS);
  }

  String _getSizeKey() {
    if (_sizeValue <= 0.9) return 'small';
    if (_sizeValue <= 1.1) return 'medium';
    return 'large';
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
          size: '${_getSizeKey()}'
        })
      }).then(response => {
        console.log('Frame changed to: $frameFilename');
      }).catch(error => {
        console.log('Frame change error:', error);
      });
    """;

    _webViewController.runJavaScript(javascript);
  }

  void _changeSize(double newSize) {
    setState(() {
      _sizeValue = newSize;
    });

    final javascript = """
      fetch('/change_frame', {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({
          frame: '$_selectedFrame',
          size: '${_getSizeKey()}'
        })
      }).then(response => {
        console.log('Size changed to: ${_getSizeKey()}');
      }).catch(error => {
        console.log('Size change error:', error);
      });
    """;

    _webViewController.runJavaScript(javascript);
  }

  void _refreshCameraView() {
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
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
            ),
            const SizedBox(height: 8),
            const Text(
              'Make sure Flask server is running\nat 192.168.1.80:5000',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white),
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

  Widget _buildSizeSlider() {
    return Container(
      width: 60,
      height: 200,
      child: Column(
        children: [
          // Vertical Slider
          Expanded(
            child: RotatedBox(
              quarterTurns: 3, // Make it vertical
              child: Slider(
                value: _sizeValue,
                min: 0.8,
                max: 1.2,
                divisions: 4,
                onChanged: _changeSize,
                activeColor: Colors.blue,
                inactiveColor: Colors.grey,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final frameProvider = Provider.of<FrameProvider>(context);

    return Scaffold(
      appBar: widget.showHeader
          ? AppBar(
        title: const Text('AR Try On'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
      )
          : null,
      body: Column(
        children: [
          // Camera View Section
          Expanded(
            flex: 3,
            child: Container(
              color: Colors.black,
              child: Stack(
                children: [
                  _buildWebViewContent(),
                  // Simple Size Slider on right side
                  Positioned(
                    right: 1,
                    top: MediaQuery.of(context).size.height * 0.25,
                    child: _buildSizeSlider(),
                  ),
                ],
              ),
            ),
          ),

          // Frame Selection Section
          Expanded(
            flex: 2,
            child: Container(
              color: Colors.white,
              child: Column(
                children: [
                  const Padding(
                    padding: EdgeInsets.all(16.0),
                    child: Text(
                      'Select Frame',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  Expanded(
                    child: !_framesLoaded || frameProvider.isLoading
                        ? const Center(child: CircularProgressIndicator())
                        : _buildFrameList(frameProvider),
                  ),
                ],
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
          width: 120,
          margin: const EdgeInsets.symmetric(horizontal: 8),
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
    if (!_framesLoaded) {
      _loadFrames();
    }
  }
}