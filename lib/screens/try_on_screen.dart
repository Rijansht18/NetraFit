import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:provider/provider.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';
import 'package:webview_flutter_wkwebview/webview_flutter_wkwebview.dart';
import 'package:permission_handler/permission_handler.dart';
import '../core/config/api_config.dart';
import '../providers/frame_provider.dart';
import '../widgets/frame_card.dart';

class TryOnScreen extends StatefulWidget {
  final List<String>? recommendedFrameFilenames;
  final bool showHeader;

  const TryOnScreen({super.key, this.recommendedFrameFilenames, this.showHeader = false});

  @override
  State<TryOnScreen> createState() => _TryOnScreenState();
}

class _TryOnScreenState extends State<TryOnScreen> {
  late WebViewController _webViewController;
  String _selectedFrame = '';
  double _sizeValue = 1.0;
  bool _isLoading = true;
  bool _hasError = false;
  bool _isPageLoaded = false;
  bool _framesLoaded = false;
  bool _processingStarted = false;
  bool _cameraPermissionGranted = false;

  @override
  void initState() {
    super.initState();
    _requestCameraPermission().then((_) {
      _initializeWebView();
      _loadFrames();
    });
  }

  Future<void> _requestCameraPermission() async {
    print('Requesting camera permission...');
    final status = await Permission.camera.request();
    if (status.isGranted) {
      print('Camera permission granted');
      setState(() {
        _cameraPermissionGranted = true;
      });
    } else {
      print('Camera permission denied: $status');
      setState(() {
        _cameraPermissionGranted = false;
      });

      // Show permission dialog
      if (mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Camera Permission Required'),
            content: const Text(
              'This app needs camera access for virtual try-on. '
                  'Please grant camera permission in app settings.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () => openAppSettings(),
                child: const Text('Open Settings'),
              ),
            ],
          ),
        );
      }
    }
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
      String frameToSelect;

      if (widget.recommendedFrameFilenames != null &&
          widget.recommendedFrameFilenames!.isNotEmpty) {
        frameToSelect = widget.recommendedFrameFilenames!.first;
      } else {
        frameToSelect = frameProvider.frames.first.filename;
      }

      setState(() {
        _selectedFrame = frameToSelect;
      });

      // Wait for webview to load before sending frame change
      if (_isPageLoaded) {
        _changeFrameOnWebView(frameToSelect);
      }
    }
  }

  void _initializeWebView() {
    final PlatformWebViewControllerCreationParams params;
    if (WebViewPlatform.instance is WebKitWebViewPlatform) {
      params = WebKitWebViewControllerCreationParams(
        allowsInlineMediaPlayback: true,
        mediaTypesRequiringUserAction: const <PlaybackMediaTypes>{},
      );
    } else {
      params = const PlatformWebViewControllerCreationParams();
    }

    _webViewController = WebViewController.fromPlatformCreationParams(params)
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(const Color(0x00000000))
      ..enableZoom(false)
      ..setNavigationDelegate(
        NavigationDelegate(
          onProgress: (int progress) {
            print('WebView loading progress: $progress%');
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
            print('WebView page loaded: $url');

            // Grant camera permissions via JavaScript
            _grantCameraPermissions();

            // Auto-select frame after page loads
            if (_selectedFrame.isNotEmpty) {
              _changeFrameOnWebView(_selectedFrame);
            }
          },
          onWebResourceError: (WebResourceError error) {
            setState(() {
              _isLoading = false;
              _hasError = true;
            });
            print('WebView error: ${error.errorCode} - ${error.description}');
            print('Error URL: ${error.url}');
            print('Error type: ${error.errorType}');
          },
          onUrlChange: (UrlChange change) {
            print('URL changed to: ${change.url}');
          },
          onNavigationRequest: (NavigationRequest request) {
            print('Navigation request to: ${request.url}');
            // Allow all navigation for ngrok
            return NavigationDecision.navigate;
          },
        ),
      );

    // Platform-specific configurations
    if (_webViewController.platform is AndroidWebViewController) {
      AndroidWebViewController.enableDebugging(true);
      final AndroidWebViewController androidController =
      _webViewController.platform as AndroidWebViewController;
      androidController.setMediaPlaybackRequiresUserGesture(false);
      androidController.setMixedContentMode(MixedContentMode.compatibilityMode);

      // Enable camera for Android WebView
      androidController.setOnPlatformPermissionRequest((request) {
        print('Platform permission request: ${request.types}');
        request.grant();
      });
    }

    // Load the URL with retry mechanism
    _loadUrlWithRetry();
  }

  void _loadUrlWithRetry({int retryCount = 0}) {
    const maxRetries = 2;

    final url = '${ApiUrl.baseUrl}/client_camera';
    print('Loading URL: $url (attempt ${retryCount + 1})');

    _webViewController.loadRequest(Uri.parse(url)).then((_) {
      print('URL loaded successfully');
    }).catchError((error) {
      print('Failed to load URL: $error');
      if (retryCount < maxRetries) {
        print('Retrying in 2 seconds...');
        Future.delayed(const Duration(seconds: 2), () {
          _loadUrlWithRetry(retryCount: retryCount + 1);
        });
      } else {
        setState(() {
          _hasError = true;
          _isLoading = false;
        });

        // Try alternative URLs as fallback
        _tryAlternativeUrls();
      }
    });
  }

  void _tryAlternativeUrls() {
    final urls = [
      '${ApiUrl.baseUrl}/client_camera',
      '${ApiUrl.baseUrl}/client_camera',
    ];

    print('Trying alternative URLs...');
    for (final url in urls) {
      _webViewController.loadRequest(Uri.parse(url));
      break;
    }
  }

  void _grantCameraPermissions() {
    if (!_cameraPermissionGranted) {
      print('Camera permission not granted, skipping JavaScript camera access');
      return;
    }

    // Grant camera permissions via JavaScript
    final jsCode = '''
      console.log('Attempting to grant camera permissions...');
      
      // Function to request camera access
      function requestCameraAccess() {
        if (navigator.mediaDevices && navigator.mediaDevices.getUserMedia) {
          navigator.mediaDevices.getUserMedia({ 
            video: { 
              facingMode: 'user',
              width: { ideal: 1280 },
              height: { ideal: 720 }
            } 
          })
          .then(function(stream) {
            console.log('Camera access granted successfully');
            // Create video element and play stream
            const video = document.createElement('video');
            video.srcObject = stream;
            video.autoplay = true;
            video.playsInline = true;
            document.body.appendChild(video);
          })
          .catch(function(error) {
            console.log('Camera access error:', error.name, error.message);
            // Retry after delay
            setTimeout(requestCameraAccess, 1000);
          });
        } else {
          console.log('getUserMedia not supported');
        }
      }
      
      // Override permission requests
      if (navigator.permissions && navigator.permissions.query) {
        navigator.permissions.query({name: 'camera'}).then(function(result) {
          console.log('Camera permission state:', result.state);
          if (result.state === 'prompt' || result.state === 'denied') {
            result.grant().then(function() {
              console.log('Permission granted via query API');
              requestCameraAccess();
            }).catch(function(error) {
              console.log('Permission grant failed:', error);
              requestCameraAccess();
            });
          } else if (result.state === 'granted') {
            requestCameraAccess();
          }
        }).catch(function(error) {
          console.log('Permission query failed:', error);
          requestCameraAccess();
        });
      } else {
        // Direct approach if permissions API not available
        requestCameraAccess();
      }
      
      // Listen for camera-related events
      document.addEventListener('click', function() {
        requestCameraAccess();
      });
      
      // Try initial request
      setTimeout(requestCameraAccess, 500);
    ''';

    _webViewController.runJavaScript(jsCode).then((_) {
      print('Camera permission JavaScript executed');
    }).catchError((error) {
      print('Error executing camera permission JavaScript: $error');
    });
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
    _changeFrameOnWebView(frameFilename);
  }

  void _changeFrameOnWebView(String frameFilename) {
    if (!_isPageLoaded) {
      print('WebView not ready, queuing frame change: $frameFilename');
      Future.delayed(const Duration(milliseconds: 500), () {
        _changeFrameOnWebView(frameFilename);
      });
      return;
    }

    final javascript = "changeFrame('$frameFilename', '${_getSizeKey()}');";
    _webViewController.runJavaScript(javascript).then((_) {
      print('Frame changed to: $frameFilename');
      if (!_processingStarted) {
        setState(() {
          _processingStarted = true;
        });
      }
    }).catchError((error) {
      print('Error changing frame: $error');
      // Retry after delay
      Future.delayed(const Duration(milliseconds: 1000), () {
        _changeFrameOnWebView(frameFilename);
      });
    });
  }

  void _changeSize(double newSize) {
    setState(() {
      _sizeValue = newSize;
    });

    if (!_isPageLoaded || _selectedFrame.isEmpty) return;

    final javascript = "changeSize('${_getSizeKey()}');";
    _webViewController.runJavaScript(javascript).then((_) {
      print('Size changed to: ${_getSizeKey()}');
    }).catchError((error) {
      print('Error changing size: $error');
    });
  }

  void _refreshCameraView() {
    setState(() {
      _isLoading = true;
      _hasError = false;
    });

    // Reload and re-grant permissions
    _webViewController.reload().then((_) {
      Future.delayed(const Duration(seconds: 2), () {
        if (_isPageLoaded) {
          _grantCameraPermissions();
        }
      });
    });
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
              'Make sure the server is running\nand you have internet connection',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white70),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
              ),
              onPressed: _refreshCameraView,
              child: const Text('Retry Connection'),
            ),
            const SizedBox(height: 8),
            if (!_cameraPermissionGranted)
              Column(
                children: [
                  const SizedBox(height: 8),
                  const Text(
                    'Camera permission required',
                    style: TextStyle(color: Colors.orange),
                  ),
                  const SizedBox(height: 8),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange,
                      foregroundColor: Colors.white,
                    ),
                    onPressed: _requestCameraPermission,
                    child: const Text('Grant Camera Permission'),
                  ),
                ],
              ),
          ],
        ),
      );
    }

    return Stack(
      children: [
        WebViewWidget(controller: _webViewController),

        // Loading indicator
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
                    style: TextStyle(color: Colors.white, fontSize: 16),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Please wait',
                    style: TextStyle(color: Colors.white70, fontSize: 14),
                  ),
                ],
              ),
            ),
          ),

        // Refresh button when loaded
        if (_isPageLoaded && !_isLoading)
          Positioned(
            top: 10,
            right: 10,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.7),
                shape: BoxShape.circle,
              ),
              child: IconButton(
                icon: const Icon(Icons.refresh, color: Colors.white),
                onPressed: _refreshCameraView,
                tooltip: 'Refresh Camera',
              ),
            ),
          ),

        // Camera status indicator
        // if (_isPageLoaded && !_isLoading && !_processingStarted)
        //   Positioned(
        //     top: 10,
        //     left: 10,
        //     child: Container(
        //       padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        //       decoration: BoxDecoration(
        //         color: Colors.orange.withOpacity(0.8),
        //         borderRadius: BorderRadius.circular(20),
        //       ),
        //       child: Row(
        //         children: [
        //           Icon(
        //             _cameraPermissionGranted ? Icons.camera_alt : Icons.camera,
        //             color: Colors.white,
        //             size: 16,
        //           ),
        //           const SizedBox(width: 6),
        //           Text(
        //             _cameraPermissionGranted ? 'Select a frame to start' : 'Camera access needed',
        //             style: const TextStyle(color: Colors.white, fontSize: 12),
        //           ),
        //         ],
        //       ),
        //     ),
        //   ),

        // Processing indicator
        // if (_processingStarted && _cameraPermissionGranted)
        //   Positioned(
        //     top: 10,
        //     left: 10,
        //     child: Container(
        //       padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        //       decoration: BoxDecoration(
        //         color: Colors.green.withOpacity(0.8),
        //         borderRadius: BorderRadius.circular(20),
        //       ),
        //       child: const Row(
        //         children: [
        //           Icon(Icons.check_circle, color: Colors.white, size: 16),
        //           SizedBox(width: 6),
        //           Text(
        //             'Live Processing',
        //             style: TextStyle(color: Colors.white, fontSize: 12),
        //           ),
        //         ],
        //       ),
        //     ),
        //   ),
      ],
    );
  }

  Widget _buildSizeSlider() {
    return Container(
      width: 70,
      height: 200,
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.7),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text(
            'SIZE',
            style: TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 10),
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
                onChangeEnd: _changeSize,
                activeColor: Colors.blue,
                inactiveColor: Colors.grey.shade600,
                label: _getSizeKey().toUpperCase(),
              ),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            _getSizeKey().toUpperCase(),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 10,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFrameSelectionSection(FrameProvider frameProvider) {
    final framesToShow = widget.recommendedFrameFilenames != null &&
        widget.recommendedFrameFilenames!.isNotEmpty
        ? frameProvider.frames
        .where((frame) =>
        widget.recommendedFrameFilenames!.contains(frame.filename))
        .toList()
        : frameProvider.frames;

    if (framesToShow.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.visibility_off, size: 48, color: Colors.grey),
            const SizedBox(height: 8),
            const Text(
              'No frames available',
              style: TextStyle(color: Colors.grey, fontSize: 16),
            ),
            const SizedBox(height: 8),
            ElevatedButton(
              onPressed: () {
                frameProvider.loadFrames();
              },
              child: const Text('Reload Frames'),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        // Header with frame count
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Select Frame (${framesToShow.length})',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              if (widget.recommendedFrameFilenames != null &&
                  widget.recommendedFrameFilenames!.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.green.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.green),
                  ),
                  child: const Text(
                    'Recommended',
                    style: TextStyle(
                      color: Colors.green,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
            ],
          ),
        ),

        // Frame list
        Expanded(
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: framesToShow.length,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            itemBuilder: (context, index) {
              final frame = framesToShow[index];
              return Container(
                width: 130,
                margin: const EdgeInsets.symmetric(horizontal: 6),
                child: FrameCard(
                  frame: frame,
                  isSelected: _selectedFrame == frame.filename,
                  onTap: () => _changeFrame(frame.filename),
                  showShape: true,
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final frameProvider = Provider.of<FrameProvider>(context);

    return Scaffold(
      appBar: widget.showHeader
          ? AppBar(
        title: const Text('Virtual Try-On'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.info_outline),
            onPressed: () {
              showDialog(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('How to Use'),
                  content: const Text(
                    '• Select a frame from the list below\n'
                        '• Adjust size using the slider on the right\n'
                        '• Position your face 40-70cm from camera\n'
                        '• Ensure good lighting for best results\n'
                        '• Grant camera permission when prompted',
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('OK'),
                    ),
                  ],
                ),
              );
            },
          ),
          if (!_cameraPermissionGranted)
            IconButton(
              icon: const Icon(Icons.camera_alt),
              onPressed: _requestCameraPermission,
              tooltip: 'Grant Camera Permission',
            ),
        ],
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

                  // Size Slider on right side
                  Positioned(
                    right: 8,
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
              color: Colors.grey[50],
              child: !_framesLoaded || frameProvider.isLoading
                  ? const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 16),
                    Text('Loading frames...'),
                  ],
                ),
              )
                  : _buildFrameSelectionSection(frameProvider),
            ),
          ),
        ],
      ),

      // Bottom navigation for quick actions
      persistentFooterButtons: _isPageLoaded && !_hasError
          ? [
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                icon: const Icon(Icons.camera_alt),
                label: const Text('Refresh Camera'),
                onPressed: _refreshCameraView,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: OutlinedButton.icon(
                icon: const Icon(Icons.settings),
                label: const Text('Reset Size'),
                onPressed: () => _changeSize(1.0),
              ),
            ),
            if (!_cameraPermissionGranted) ...[
              const SizedBox(width: 8),
              Expanded(
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.camera_alt),
                  label: const Text('Enable Camera'),
                  onPressed: _requestCameraPermission,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange,
                    foregroundColor: Colors.white,
                  ),
                ),
              ),
            ],
          ],
        ),
      ]
          : null,
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_framesLoaded) {
      _loadFrames();
    }
  }

  @override
  void dispose() {
    // Clean up webview resources
    _webViewController.clearCache();
    super.dispose();
  }
}