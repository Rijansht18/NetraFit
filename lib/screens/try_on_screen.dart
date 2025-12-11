import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:provider/provider.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';
import 'package:webview_flutter_wkwebview/webview_flutter_wkwebview.dart';
import 'package:permission_handler/permission_handler.dart';
import '../core/config/api_config.dart';
import '../models/frame_model.dart';
import '../providers/frame_provider.dart';
import '../services/category_service.dart';
import '../screens/FrameDetailsScreen.dart';
import '../providers/auth_provider.dart';
import '../providers/cart_provider.dart';

class TryOnScreen extends StatefulWidget {
  final List<String>? recommendedFrameFilenames;
  final String? recommendedFrameId;
  final bool showHeader;

  const TryOnScreen({
    super.key,
    this.recommendedFrameFilenames,
    this.recommendedFrameId,
    this.showHeader = false
  });

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

  List<Map<String, dynamic>> _categories = [];
  String _selectedCategory = 'all';
  String _selectedCategoryName = 'All';
  Map<String, dynamic>? _selectedFrameData;
  final CategoryService _categoryService = CategoryService();

  @override
  void initState() {
    super.initState();
    print('TryOnScreen init - Recommended frames: ${widget.recommendedFrameFilenames}');
    print('TryOnScreen init - Recommended frame ID: ${widget.recommendedFrameId}');

    _requestCameraPermission().then((_) {
      _initializeWebView();
      _loadFramesAndCategories();
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

  void _loadFramesAndCategories() {
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final frameProvider = Provider.of<FrameProvider>(context, listen: false);

      // Load categories
      final categoriesResponse = await _categoryService.getAllMainCategories();
      if (categoriesResponse.success) {
        final categoriesData = categoriesResponse.data['data'] ?? [];
        final List<Map<String, dynamic>> categories = [];

        categories.add({'name': 'All', '_id': 'all'});

        for (var cat in categoriesData) {
          if (cat is Map<String, dynamic>) {
            final categoryName = cat['name']?.toString() ?? 'Category';
            final categoryId = cat['_id']?.toString() ?? '';
            categories.add({
              'name': categoryName,
              '_id': categoryId,
            });
            print('Loaded category: $categoryName - ID: $categoryId');
          }
        }

        setState(() {
          _categories = categories;
        });
      }

      // Load frames
      if (frameProvider.frames.isEmpty) {
        await frameProvider.loadFrames();

        print('=== DEBUG: All loaded frames ===');
        for (var frame in frameProvider.frames) {
          print('Frame: ${frame.name}, ID: ${frame.id}, Filename: ${frame.filename}');
          if (frame.mainCategory is Map) {
            final mainCat = frame.mainCategory as Map<String, dynamic>;
            print('  Category Name: ${mainCat['name']}');
          }
        }
        print('=============================');

        if (mounted) {
          setState(() {
            _framesLoaded = true;
          });
          _autoSelectFrame(frameProvider);
        }
      } else {
        print('Frames already loaded: ${frameProvider.frames.length}');
        setState(() {
          _framesLoaded = true;
        });
        _autoSelectFrame(frameProvider);
      }
    });
  }

  void _autoSelectFrame(FrameProvider frameProvider) {
    print('=== DEBUG: _autoSelectFrame called ===');
    print('Frames available: ${frameProvider.frames.length}');
    print('Recommended frames: ${widget.recommendedFrameFilenames}');
    print('Recommended frame ID: ${widget.recommendedFrameId}');
    print('Current selected frame: $_selectedFrame');

    if (frameProvider.frames.isNotEmpty && _selectedFrame.isEmpty) {
      String frameToSelect = '';
      Frame? selectedFrameObject;

      // First try to find by ID (more reliable)
      if (widget.recommendedFrameId != null && widget.recommendedFrameId!.isNotEmpty) {
        print('Looking for frame by ID: ${widget.recommendedFrameId}');
        try {
          selectedFrameObject = frameProvider.frames.firstWhere(
                (frame) => frame.id == widget.recommendedFrameId,
          );
          frameToSelect = selectedFrameObject.filename;
          print('Found frame by ID: ${selectedFrameObject.name}, Filename: $frameToSelect');
        } catch (e) {
          print('Frame not found by ID: ${widget.recommendedFrameId}');
        }
      }

      // If not found by ID, try by filename
      if (frameToSelect.isEmpty &&
          widget.recommendedFrameFilenames != null &&
          widget.recommendedFrameFilenames!.isNotEmpty) {
        frameToSelect = widget.recommendedFrameFilenames!.first;
        print('Looking for frame by filename: $frameToSelect');

        final matchingFrames = frameProvider.frames.where(
                (frame) => frame.filename == frameToSelect
        ).toList();

        print('Found ${matchingFrames.length} matching frames');
        if (matchingFrames.isNotEmpty) {
          selectedFrameObject = matchingFrames.first;
          print('Found frame by filename: ${selectedFrameObject.name}');
        } else {
          print('WARNING: Frame not found by filename!');
          print('Available filenames (first 5):');
          for (var frame in frameProvider.frames.take(5)) {
            print('  - ${frame.filename}');
          }
        }
      }

      // If still not found, use first available frame
      if (frameToSelect.isEmpty) {
        selectedFrameObject = frameProvider.frames.first;
        frameToSelect = selectedFrameObject.filename;
        print('Using first available frame: ${selectedFrameObject.name}, Filename: $frameToSelect');
      }

      setState(() {
        _selectedFrame = frameToSelect;
        if (selectedFrameObject != null) {
          _selectedFrameData = {
            'id': selectedFrameObject.id,
            'name': selectedFrameObject.name,
            'brand': selectedFrameObject.brand,
            'price': selectedFrameObject.price,
            'imageUrls': selectedFrameObject.imageUrls,
            'description': selectedFrameObject.description,
            'type': selectedFrameObject.type,
            'shape': selectedFrameObject.shape,
            'size': selectedFrameObject.size,
            'colors': selectedFrameObject.colors,
            'quantity': selectedFrameObject.quantity,
            'mainCategory': selectedFrameObject.mainCategory,
          };
          print('Successfully selected frame: ${selectedFrameObject.name}');
        }
      });

      print('WebView page loaded: $_isPageLoaded');
      if (_isPageLoaded) {
        print('WebView ready, changing frame...');
        _changeFrameOnWebView(frameToSelect);
      } else {
        print('WebView not ready yet, frame will be selected when page loads');
      }
    } else {
      print('Skipping auto-select: frames empty or already selected');
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
      ..setBackgroundColor(const Color(0xFF000000))
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
            print('WebView page finished loading: $url');
            setState(() {
              _isLoading = false;
              _isPageLoaded = true;
            });

            print('Granting camera permissions...');
            _grantCameraPermissions();

            Future.delayed(const Duration(milliseconds: 800), () {
              if (_selectedFrame.isNotEmpty) {
                print('Page loaded, changing to selected frame: $_selectedFrame');
                _changeFrameOnWebView(_selectedFrame);
              } else {
                print('No frame selected yet, checking if we have frames...');
                if (_framesLoaded) {
                  final frameProvider = Provider.of<FrameProvider>(context, listen: false);
                  if (frameProvider.frames.isNotEmpty && _selectedFrame.isEmpty) {
                    print('Auto-selecting first available frame');
                    _autoSelectFrame(frameProvider);
                  }
                }
              }
            });
          },
          onWebResourceError: (WebResourceError error) {
            setState(() {
              _isLoading = false;
              _hasError = true;
            });
            print('WebView error: ${error.errorCode} - ${error.description}');
          },
          onUrlChange: (UrlChange change) {
            print('URL changed to: ${change.url}');
          },
          onNavigationRequest: (NavigationRequest request) {
            print('Navigation request to: ${request.url}');
            return NavigationDecision.navigate;
          },
        ),
      );

    if (_webViewController.platform is AndroidWebViewController) {
      AndroidWebViewController.enableDebugging(true);
      final AndroidWebViewController androidController =
      _webViewController.platform as AndroidWebViewController;
      androidController.setMediaPlaybackRequiresUserGesture(false);
      androidController.setMixedContentMode(MixedContentMode.compatibilityMode);

      androidController.setOnPlatformPermissionRequest((request) {
        print('Platform permission request: ${request.types}');
        request.grant();
      });
    }

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

    final jsCode = '''
      console.log('Attempting to grant camera permissions...');
      
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
            const video = document.createElement('video');
            video.srcObject = stream;
            video.autoplay = true;
            video.playsInline = true;
            document.body.appendChild(video);
          })
          .catch(function(error) {
            console.log('Camera access error:', error.name, error.message);
            setTimeout(requestCameraAccess, 1000);
          });
        } else {
          console.log('getUserMedia not supported');
        }
      }
      
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
        requestCameraAccess();
      }
      
      document.addEventListener('click', function() {
        requestCameraAccess();
      });
      
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

  void _changeFrame(String frameFilename, FrameProvider frameProvider) {
    print('Manual frame change requested: $frameFilename');
    setState(() {
      _selectedFrame = frameFilename;
      final selectedFrame = frameProvider.frames.firstWhere(
            (frame) => frame.filename == frameFilename,
      );
      _selectedFrameData = {
        'id': selectedFrame.id,
        'name': selectedFrame.name,
        'brand': selectedFrame.brand,
        'price': selectedFrame.price,
        'imageUrls': selectedFrame.imageUrls,
        'description': selectedFrame.description,
        'type': selectedFrame.type,
        'shape': selectedFrame.shape,
        'size': selectedFrame.size,
        'colors': selectedFrame.colors,
        'quantity': selectedFrame.quantity,
        'mainCategory': selectedFrame.mainCategory,
      };
    });
    _changeFrameOnWebView(frameFilename);
  }

  void _changeFrameOnWebView(String frameFilename) {
    print('=== DEBUG: _changeFrameOnWebView called ===');
    print('Frame to change: $frameFilename');
    print('WebView page loaded: $_isPageLoaded');

    if (!_isPageLoaded) {
      print('WebView not ready, scheduling retry in 500ms...');
      Future.delayed(const Duration(milliseconds: 500), () {
        _changeFrameOnWebView(frameFilename);
      });
      return;
    }

    String cleanFilename = frameFilename;
    // Remove path if present
    if (frameFilename.contains('/')) {
      cleanFilename = frameFilename.split('/').last;
    }
    // Remove extension if present
    if (cleanFilename.contains('.')) {
      cleanFilename = cleanFilename.split('.').first;
    }

    print('Original filename: $frameFilename');
    print('Cleaned filename: $cleanFilename');
    print('Size key: ${_getSizeKey()}');

    final javascript = "changeFrame('$cleanFilename', '${_getSizeKey()}');";
    print('Executing JavaScript: $javascript');

    _webViewController.runJavaScript(javascript).then((_) {
      print('Frame changed successfully to: $cleanFilename');
      if (!_processingStarted) {
        setState(() {
          _processingStarted = true;
        });
      }
    }).catchError((error) {
      print('Error changing frame: $error');
      print('Retrying with different filename variations...');

      // Try different filename variations
      final variations = [
        cleanFilename,
        frameFilename,
        frameFilename.split('/').last,
        frameFilename.replaceAll('.png', ''),
        frameFilename.replaceAll('.jpg', ''),
        frameFilename.replaceAll('.jpeg', ''),
      ];

      // Try each variation
      _tryFilenameVariations(variations, 0);
    });
  }

  void _tryFilenameVariations(List<String> variations, int index) {
    if (index >= variations.length) {
      print('All filename variations failed');
      return;
    }

    final variation = variations[index];
    print('Trying filename variation $index: $variation');

    final javascript = "changeFrame('$variation', '${_getSizeKey()}');";

    _webViewController.runJavaScript(javascript).then((_) {
      print('Success with variation: $variation');
      setState(() {
        _selectedFrame = variation;
      });
    }).catchError((error) {
      print('Failed with variation: $variation, error: $error');
      Future.delayed(const Duration(milliseconds: 500), () {
        _tryFilenameVariations(variations, index + 1);
      });
    });
  }

  void _changeSize(double newSize) {
    setState(() {
      _sizeValue = newSize;
    });

    if (!_isPageLoaded || _selectedFrame.isEmpty) return;

    final javascript = "changeSize('${_getSizeKey()}');";
    print('Changing size: $javascript');
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
                backgroundColor: const Color(0xFF275BCD),
                foregroundColor: Colors.white,
              ),
              onPressed: _refreshCameraView,
              child: const Text('Retry Connection'),
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
                    style: TextStyle(color: Colors.white, fontSize: 16),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  List<dynamic> _getFilteredFrames(FrameProvider frameProvider) {
    if (_selectedCategory == 'all') {
      return frameProvider.frames;
    }

    return frameProvider.frames.where((frame) {
      if (frame.mainCategory is Map<String, dynamic>) {
        final mainCat = frame.mainCategory as Map<String, dynamic>;
        final categoryName = mainCat['name']?.toString() ?? '';
        return categoryName == _selectedCategoryName;
      }
      final frameCategory = frame.mainCategory?.toString() ?? '';
      return frameCategory == _selectedCategory;
    }).toList();
  }

  void _selectCategory(String categoryId, String categoryName) {
    setState(() {
      _selectedCategory = categoryId;
      _selectedCategoryName = categoryName;
    });
  }

  @override
  Widget build(BuildContext context) {
    final frameProvider = Provider.of<FrameProvider>(context);
    final frames = _getFilteredFrames(frameProvider);

    // Force frame change if needed
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_isPageLoaded && _selectedFrame.isNotEmpty && !_processingStarted) {
        Future.delayed(const Duration(milliseconds: 1000), () {
          print('Build method forcing frame change...');
          _changeFrameOnWebView(_selectedFrame);
        });
      }
    });

    return Scaffold(
      backgroundColor: Colors.white,
      body: Column(
        children: [
          // Camera View Section
          Expanded(
            flex: 3,
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: Colors.black,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Stack(
                  children: [
                    _buildWebViewContent(),

                    // Size slider on right
                    Positioned(
                      right: 8,
                      top: MediaQuery.of(context).size.height * 0.25,
                      child: _buildModernSizeSlider(),
                    ),

                    // Camera controls at bottom
                    Positioned(
                      bottom: 16,
                      left: 0,
                      right: 0,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          _buildCameraControlButton(
                            icon: Icons.refresh,
                            label: 'Refresh',
                            onPressed: _refreshCameraView,
                            isActive: true,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Category Filter
          SizedBox(
            height: 50,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: _categories.length,
              itemBuilder: (context, index) {
                final category = _categories[index];
                final isSelected = _selectedCategory == category['_id'];

                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(category['name']),
                    selected: isSelected,
                    onSelected: (selected) {
                      _selectCategory(category['_id'], category['name']);
                    },
                    selectedColor: const Color(0xFF275BCD),
                    labelStyle: TextStyle(
                      color: isSelected ? Colors.white : Colors.black,
                    ),
                  ),
                );
              },
            ),
          ),

          // Frame Selection Header with size info
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Frames (${frames.length})',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                  ),
                ),
                Text(
                  'Size: ${_getSizeKey().toUpperCase()}',
                  style: const TextStyle(
                    fontSize: 14,
                    color: Colors.grey,
                  ),
                ),
              ],
            ),
          ),

          // Frame Selection List
          SizedBox(
            height: 160,
            child: _buildFrameSelectionSection(frameProvider, frames),
          ),

          const SizedBox(height: 16),

          // Action Buttons
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      if (_selectedFrameData != null) {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => FrameDetailsScreen(
                              frameId: _selectedFrameData!['id'],
                              frame: Frame.fromJson({
                                '_id': _selectedFrameData!['id'],
                                'name': _selectedFrameData!['name'],
                                'brand': _selectedFrameData!['brand'],
                                'price': _selectedFrameData!['price'],
                                'imageUrls': _selectedFrameData!['imageUrls'],
                                'description': _selectedFrameData!['description'],
                                'type': _selectedFrameData!['type'],
                                'shape': _selectedFrameData!['shape'],
                                'size': _selectedFrameData!['size'],
                                'colors': _selectedFrameData!['colors'],
                                'quantity': _selectedFrameData!['quantity'],
                                'isActive': true,
                                'mainCategory': _selectedFrameData!['mainCategory'],
                                'filename': _selectedFrame,
                              }),
                            ),
                          ),
                        );
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Please select a frame first'),
                            backgroundColor: Colors.red,
                            duration: Duration(seconds: 2),
                          ),
                        );
                      }
                    },
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF275BCD),
                      side: const BorderSide(color: Color(0xFF275BCD)),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    icon: const Icon(Icons.remove_red_eye),
                    label: const Text(
                      'View Details',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () async {
                      if (_selectedFrameData != null) {
                        final authProvider = Provider.of<AuthProvider>(context, listen: false);
                        final cartProvider = Provider.of<CartProvider>(context, listen: false);
                        final token = authProvider.token;

                        if (token == null) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Please login to add items to cart'),
                              backgroundColor: Colors.red,
                              duration: Duration(seconds: 2),
                            ),
                          );
                          return;
                        }

                        final success = await cartProvider.addToCart(
                          token: token,
                          frameId: _selectedFrameData!['id'],
                          quantity: 1,
                        );

                        if (success) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Added ${_selectedFrameData!['name']} to cart'),
                              backgroundColor: Colors.green,
                              duration: const Duration(seconds: 2),
                            ),
                          );
                        } else {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(cartProvider.errorMessage ?? 'Failed to add to cart'),
                              backgroundColor: Colors.red,
                              duration: const Duration(seconds: 2),
                            ),
                          );
                        }
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Please select a frame first'),
                            backgroundColor: Colors.red,
                            duration: Duration(seconds: 2),
                          ),
                        );
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF275BCD),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 0,
                    ),
                    icon: const Icon(Icons.add_shopping_cart),
                    label: const Text(
                      'Add to Cart',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildModernSizeSlider() {
    return Container(
        width: 60,
        height: 160,
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.7),
          borderRadius: BorderRadius.circular(12),
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
            Expanded(
              child: RotatedBox(
                quarterTurns: 3,
                child: Slider(
                  value: _sizeValue,
                  min: 0.8,
                  max: 1.2,
                  divisions: 4,
                  onChanged: _changeSize,
                  onChangeEnd: _changeSize,
                  activeColor: const Color(0xFF275BCD),
                  inactiveColor: Colors.grey.shade600,
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
        )
    );
  }

  Widget _buildCameraControlButton({
    required IconData icon,
    required String label,
    required VoidCallback onPressed,
    required bool isActive,
  }) {
    return Column(
      children: [
        Container(
          width: 50,
          height: 50,
          decoration: BoxDecoration(
            color: isActive ? const Color(0xFF275BCD) : Colors.grey,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.2),
                blurRadius: 6,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: IconButton(
            onPressed: onPressed,
            icon: Icon(icon, color: Colors.white),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            color: Colors.white,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildFrameSelectionSection(FrameProvider frameProvider, List<dynamic> frames) {
    if (frames.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.visibility_off, size: 48, color: Colors.grey),
            const SizedBox(height: 8),
            Text(
              _selectedCategory == 'all'
                  ? 'No frames available'
                  : 'No frames in $_selectedCategoryName category',
              style: const TextStyle(color: Colors.grey, fontSize: 16),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: frames.length,
      itemBuilder: (context, index) {
        final frame = frames[index];
        return _buildFrameCard(frame, frameProvider);
      },
    );
  }

  Widget _buildFrameCard(dynamic frame, FrameProvider frameProvider) {
    return Container(
      width: 140,
      margin: const EdgeInsets.only(right: 12),
      child: GestureDetector(
        onTap: () => _changeFrame(frame.filename, frameProvider),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: _selectedFrame == frame.filename
                  ? const Color(0xFF275BCD)
                  : Colors.grey[200]!,
              width: 2,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Frame Image
              Container(
                height: 100,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(10),
                    topRight: Radius.circular(10),
                  ),
                ),
                child: Center(
                  child: frame.imageUrls.isNotEmpty
                      ? Image.network(
                    frame.imageUrls.first,
                    fit: BoxFit.contain,
                    width: 80,
                    height: 60,
                  )
                      : const Icon(Icons.image, color: Colors.grey, size: 40),
                ),
              ),

              // Frame Info
              Padding(
                padding: const EdgeInsets.all(8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      frame.name,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Colors.black,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_framesLoaded) {
      _loadFramesAndCategories();
    }
  }

  @override
  void dispose() {
    _webViewController.clearCache();
    super.dispose();
  }
}