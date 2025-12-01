// screens/admin/admin_dashboard_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../core/config/api_config.dart';
import '../../providers/auth_provider.dart';
import '../../routes.dart';
import '../../services/order_service.dart';
import '../../models/order_model.dart' hide Frame;
import 'analytics_screen.dart';
import 'order_management_screen.dart';
import 'user_management_screen.dart';
import 'main_category_management_screen.dart';
import 'frame_management_screen.dart';
import '../../services/admin_service.dart';
import '../../services/frame_service.dart';
import '../../models/api_response.dart';
import '../../models/user_model.dart';
import '../../models/frame_model.dart';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({Key? key}) : super(key: key);

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  final AdminService _adminService = AdminService();
  final FrameService _frameService = FrameService();
  final OrderService _orderService = OrderService();

  List<UserModel> _users = [];
  List<Frame> _frames = [];
  List<Order> _orders = [];
  bool _isLoading = true;

  // Dashboard statistics
  int _totalProducts = 0;
  int _totalOrders = 0;
  double _totalRevenue = 0.0;
  double _inventoryValue = 0.0;
  int _pendingOrders = 0;
  int _processingOrders = 0;
  int _shippedOrders = 0;
  int _deliveredOrders = 0;
  int _cancelledOrders = 0;
  int _lowStockProducts = 0;
  int _outOfStockProducts = 0;
  int _totalUsers = 0;
  int _totalAdmins = 0;
  int _totalCustomers = 0;
  int _activeUsers = 0;
  int _suspendedUsers = 0;

  // Additional statistics
  double _averageOrderValue = 0.0;
  int _todayOrders = 0;
  int _thisWeekOrders = 0;
  int _thisMonthOrders = 0;
  double _todayRevenue = 0.0;
  double _thisWeekRevenue = 0.0;
  double _thisMonthRevenue = 0.0;
  Map<String, int> _ordersByPaymentMethod = {};
  Map<String, double> _revenueByMonth = {};

  Map<String, String> _systemStatus = {
    'server': 'Checking...',
    'database': 'Checking...',
    'api': 'Checking...',
    'security': 'Checking...',
  };

  @override
  void initState() {
    super.initState();
    _loadDashboardData();
    _checkSystemStatus();

    // Auto-refresh every 30 seconds
    Future.delayed(const Duration(seconds: 30), () {
      if (mounted) {
        _loadDashboardData();
        _checkSystemStatus();
      }
    });
  }

  Future<void> _loadDashboardData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final authProvider = context.read<AuthProvider>();
      final token = authProvider.token!;

      // Load all data
      await Future.wait([
        _loadUsers(token),
        _loadFrames(token),
        _loadOrders(token),
      ]);

      // Calculate all statistics
      _calculateAllStatistics();

    } catch (e) {
      print('Error loading dashboard data: $e');
      _showErrorDialog('Network error: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _loadUsers(String token) async {
    try {
      final response = await _adminService.getAllUsers();
      if (response.success == true) {
        setState(() {
          _users = (response.data?['users'] as List? ?? [])
              .map((userData) => UserModel.fromJson(userData))
              .toList();
        });
      }
    } catch (e) {
      print('Error loading users: $e');
    }
  }

  Future<void> _loadFrames(String token) async {
    try {
      final response = await _frameService.getAllFrames();
      if (response.success == true) {
        setState(() {
          _frames = (response.data?['data'] as List? ?? [])
              .map((frameData) => Frame.fromJson(frameData))
              .toList();
        });
      }
    } catch (e) {
      print('Error loading frames: $e');
    }
  }

  Future<void> _loadOrders(String token) async {
    try {
      final response = await _orderService.getAllOrders(token: token);
      if (response.success == true) {
        print('Dashboard - Orders response type: ${response.data?['orders'].runtimeType}');
        print('Dashboard - First item type: ${response.data?['orders'][0].runtimeType}');

        // Check if the data is already Order objects
        final ordersData = response.data?['orders'] as List? ?? [];

        if (ordersData.isNotEmpty) {
          // Check the type of first element
          if (ordersData[0] is Order) {
            // Data is already Order objects
            setState(() {
              _orders = ordersData.cast<Order>();
            });
            print('Dashboard - Loaded ${_orders.length} Order objects directly');
          } else if (ordersData[0] is Map) {
            // Data is JSON maps, need to parse
            setState(() {
              _orders = ordersData
                  .where((order) => order != null)
                  .map((orderData) => Order.fromJson(orderData as Map<String, dynamic>))
                  .toList();
            });
            print('Dashboard - Parsed ${_orders.length} orders from JSON');
          } else {
            print('Dashboard - Unknown data type: ${ordersData[0].runtimeType}');
          }
        } else {
          setState(() {
            _orders = [];
          });
        }
      } else {
        print('Dashboard - API error: ${response.error}');
      }
    } catch (e) {
      print('Error loading orders in dashboard: $e');
    }
  }

  void _calculateAllStatistics() {
    print('Calculating statistics with:');
    print('- Users: ${_users.length}');
    print('- Frames: ${_frames.length}');
    print('- Orders: ${_orders.length}');

    // Check if orders have data
    if (_orders.isNotEmpty) {
      print('First order sample:');
      print('  Order #: ${_orders.first.orderNumber}');
      print('  Status: ${_orders.first.orderStatus}');
      print('  Amount: ${_orders.first.totalAmount}');
      print('  Created: ${_orders.first.createdAt}');
    }

    _calculateUserStatistics();
    _calculateFrameStatistics();
    _calculateOrderStatistics();
    _calculateAdditionalStatistics();
  }

  void _calculateUserStatistics() {
    _totalUsers = _users.length;
    _totalAdmins = _users.where((user) => user.isAdmin).length;
    _totalCustomers = _users.where((user) => user.isCustomer).length;
    _activeUsers = _users.where((user) => user.isActive).length;
    _suspendedUsers = _users.where((user) => user.isSuspended).length;
  }

  void _calculateFrameStatistics() {
    _totalProducts = _frames.length;
    _lowStockProducts = _frames.where((frame) => frame.quantity < 10 && frame.quantity > 0).length;
    _outOfStockProducts = _frames.where((frame) => frame.quantity == 0).length;

    // Calculate Inventory Value: sum of (price * quantity) for all frames
    _inventoryValue = _frames.fold(0.0, (sum, frame) {
      return sum + (frame.price * frame.quantity);
    });
  }

  void _calculateOrderStatistics() {
    _totalOrders = _orders.length;

    // Calculate order counts by status
    _pendingOrders = _orders.where((order) => order.orderStatus.toLowerCase() == 'pending').length;
    _processingOrders = _orders.where((order) => order.orderStatus.toLowerCase() == 'processing').length;
    _shippedOrders = _orders.where((order) => order.orderStatus.toLowerCase() == 'shipped').length;
    _deliveredOrders = _orders.where((order) => order.orderStatus.toLowerCase() == 'delivered').length;
    _cancelledOrders = _orders.where((order) => order.orderStatus.toLowerCase() == 'cancelled').length;

    // Calculate Total Revenue from delivered orders only
    _totalRevenue = _orders.fold(0.0, (sum, order) {
      if (order.orderStatus.toLowerCase() == 'delivered') {
        return sum + order.totalAmount;
      }
      return sum;
    });
  }

  void _calculateAdditionalStatistics() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final weekAgo = today.subtract(const Duration(days: 7));
    final monthAgo = DateTime(now.year, now.month - 1, now.day);

    // Calculate time-based statistics
    _todayOrders = _orders.where((order) => order.createdAt.isAfter(today)).length;
    _thisWeekOrders = _orders.where((order) => order.createdAt.isAfter(weekAgo)).length;
    _thisMonthOrders = _orders.where((order) => order.createdAt.isAfter(monthAgo)).length;

    _todayRevenue = _orders.fold(0.0, (sum, order) {
      if (order.orderStatus.toLowerCase() == 'delivered' && order.createdAt.isAfter(today)) {
        return sum + order.totalAmount;
      }
      return sum;
    });

    _thisWeekRevenue = _orders.fold(0.0, (sum, order) {
      if (order.orderStatus.toLowerCase() == 'delivered' && order.createdAt.isAfter(weekAgo)) {
        return sum + order.totalAmount;
      }
      return sum;
    });

    _thisMonthRevenue = _orders.fold(0.0, (sum, order) {
      if (order.orderStatus.toLowerCase() == 'delivered' && order.createdAt.isAfter(monthAgo)) {
        return sum + order.totalAmount;
      }
      return sum;
    });

    // Calculate average order value
    _averageOrderValue = _orders.isNotEmpty ? _totalRevenue / _deliveredOrders : 0.0;

    // Calculate orders by payment method
    _ordersByPaymentMethod = {};
    for (var order in _orders) {
      final method = order.paymentMethod;
      _ordersByPaymentMethod[method] = (_ordersByPaymentMethod[method] ?? 0) + 1;
    }

    // Calculate revenue by month (for last 6 months)
    _revenueByMonth = {};
    for (int i = 0; i < 6; i++) {
      final month = DateTime(now.year, now.month - i, 1);
      final monthKey = '${month.year}-${month.month.toString().padLeft(2, '0')}';
      final monthRevenue = _orders.fold(0.0, (sum, order) {
        if (order.orderStatus.toLowerCase() == 'delivered' &&
            order.createdAt.year == month.year &&
            order.createdAt.month == month.month) {
          return sum + order.totalAmount;
        }
        return sum;
      });
      _revenueByMonth[monthKey] = monthRevenue;
    }
  }

  Future<void> _checkSystemStatus() async {
    await _checkServerStatus();
    await _checkDatabaseStatus();
    await _checkApiStatus();
    await _checkSecurityStatus();
  }

  Future<void> _checkServerStatus() async {
    try {
      final response = await http.get(
        Uri.parse('${ApiUrl.baseBackendUrl}/users/allUsers'),
      ).timeout(const Duration(seconds: 5));

      setState(() {
        _systemStatus['server'] = response.statusCode == 200 ? 'Online' : 'Issues';
      });
    } catch (e) {
      setState(() {
        _systemStatus['server'] = 'Offline';
      });
    }
  }

  Future<void> _checkDatabaseStatus() async {
    try {
      final response = await http.get(
        Uri.parse('${ApiUrl.baseBackendUrl}/users/allUsers'),
      ).timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        setState(() {
          _systemStatus['database'] = data['users'] != null ? 'Connected' : 'Error';
        });
      } else {
        setState(() {
          _systemStatus['database'] = 'Error';
        });
      }
    } catch (e) {
      setState(() {
        _systemStatus['database'] = 'Disconnected';
      });
    }
  }

  Future<void> _checkApiStatus() async {
    try {
      final backendResponse = await http.get(
        Uri.parse('${ApiUrl.baseBackendUrl}/users/allUsers'),
      ).timeout(const Duration(seconds: 5));

      setState(() {
        _systemStatus['api'] = backendResponse.statusCode == 200 ? 'Running' : 'Down';
      });
    } catch (e) {
      setState(() {
        _systemStatus['api'] = 'Down';
      });
    }
  }

  Future<void> _checkSecurityStatus() async {
    try {
      final response = await http.get(
        Uri.parse('${ApiUrl.baseBackendUrl}/users/allUsers'),
      ).timeout(const Duration(seconds: 5));

      setState(() {
        _systemStatus['security'] = response.statusCode == 200 ? 'Active' : 'Inactive';
      });
    } catch (e) {
      setState(() {
        _systemStatus['security'] = 'Inactive';
      });
    }
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.error_outline, color: Colors.red, size: 24),
              SizedBox(width: 8),
              Text('Error'),
            ],
          ),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('OK'),
            ),
          ],
        );
      },
    );
  }

  // Format currency in Nepali Rupees
  String _formatCurrency(double amount) {
    if (amount >= 100000) {
      final lakhs = (amount / 100000).toStringAsFixed(1);
      return 'रु ${lakhs} लाख';
    } else if (amount >= 1000) {
      final thousands = (amount / 1000).toStringAsFixed(1);
      return 'रु ${thousands} हजार';
    }
    return 'रु ${amount.toStringAsFixed(0)}';
  }

  // Format compact number
  String _formatNumber(double number) {
    return number.toStringAsFixed(0).replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
          (Match m) => '${m[1]},',
    );
  }

  // Calculate growth percentage
  double _calculateGrowth(int current, int previous) {
    if (previous == 0) return 0.0;
    return ((current - previous) / previous * 100);
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'Online':
      case 'Connected':
      case 'Running':
      case 'Active':
        return Colors.green;
      case 'Checking...':
        return Colors.orange;
      case 'Partial':
      case 'Issues':
        return Colors.amber;
      default:
        return Colors.red;
    }
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin Dashboard'),
        backgroundColor: const Color(0xFF275BCD),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadDashboardData,
            tooltip: 'Refresh Data',
          ),
          IconButton(
            icon: const Icon(Icons.analytics),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => AnalyticsScreen(
                    users: _users,
                    frames: _frames,
                    orders: _orders,
                    statistics: _getAnalyticsData(),
                  ),
                ),
              );
            },
            tooltip: 'View Analytics',
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () {
              authProvider.logout();
              Navigator.pushReplacementNamed(context, AppRoute.onboardingroute);
            },
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
        onRefresh: _loadDashboardData,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Welcome Section
              _buildWelcomeSection(authProvider),
              const SizedBox(height: 20),

              // Performance Overview
              _buildPerformanceSection(),
              const SizedBox(height: 24),

              // Admin Features Grid
              _buildAdminFeaturesSection(),
              const SizedBox(height: 24),

              // Quick Stats Grid
              _buildStatsGrid(),
              const SizedBox(height: 24),

              // Order Analytics Section
              _buildOrderAnalyticsSection(),
              const SizedBox(height: 24),

              // Recent Activity Section
              _buildRecentActivitySection(),
              const SizedBox(height: 24),

              // System Status Section
              _buildSystemStatusSection(),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildWelcomeSection(AuthProvider authProvider) {
    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: const Color(0xFF275BCD),
              radius: 30,
              child: Text(
                authProvider.user?.username[0].toUpperCase() ?? 'A',
                style: const TextStyle(
                  fontSize: 20,
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Welcome, ${authProvider.user?.username ?? 'Admin'}!',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey[700],
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Dashboard last updated: ${_getTimeAgo(DateTime.now())}',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[600],
                    ),
                  ),
                  Text(
                    'Total System Users: $_totalUsers',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[500],
                    ),
                  ),
                ],
              ),
            ),
            Column(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.green.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.green),
                  ),
                  child: Text(
                    'रु ${_formatNumber(_totalRevenue)}',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Colors.green,
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Total Revenue',
                  style: TextStyle(
                    fontSize: 10,
                    color: Colors.grey,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPerformanceSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Performance Overview',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 16),
        GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 2,
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
          children: [
            _buildPerformanceCard(
              'Today',
              '${_todayOrders} Orders',
              _formatCurrency(_todayRevenue),
              Icons.today,
              Colors.blue,
            ),
            _buildPerformanceCard(
              'This Week',
              '${_thisWeekOrders} Orders',
              _formatCurrency(_thisWeekRevenue),
              Icons.calendar_view_week,
              Colors.green,
            ),
            _buildPerformanceCard(
              'This Month',
              '${_thisMonthOrders} Orders',
              _formatCurrency(_thisMonthRevenue),
              Icons.calendar_month,
              Colors.orange,
            ),
            _buildPerformanceCard(
              'Avg Order',
              '${_deliveredOrders} Delivered',
              'रु ${_averageOrderValue.toStringAsFixed(0)}',
              Icons.attach_money,
              Colors.purple,
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildPerformanceCard(String title, String subtitle, String value, IconData icon, Color color) {
    return Card(
      elevation: 3,
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, color: color, size: 20),
                ),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              title,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Colors.grey,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              subtitle,
              style: const TextStyle(
                fontSize: 12,
                color: Colors.grey,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatsGrid() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Business Overview',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 16),
        GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 2,
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
          children: [
            _buildStatCard(
              'Total Orders',
              _totalOrders.toString(),
              Icons.shopping_cart,
              Colors.blue,
              '${_pendingOrders} pending • ${_processingOrders} processing',
            ),
            _buildStatCard(
              'Total Revenue',
              _formatCurrency(_totalRevenue),
              Icons.attach_money,
              Colors.green,
              '${_deliveredOrders} delivered orders',
            ),
            _buildStatCard(
              'Total Frames',
              _totalProducts.toString(),
              Icons.inventory,
              Colors.orange,
              '${_lowStockProducts} low • ${_outOfStockProducts} out',
            ),
            _buildStatCard(
              'Inventory Value',
              _formatCurrency(_inventoryValue),
              Icons.warehouse,
              Colors.teal,
              'रु ${_formatNumber(_inventoryValue)} total value',
            ),
            _buildStatCard(
              'Total Users',
              _totalUsers.toString(),
              Icons.people,
              Colors.purple,
              '${_totalAdmins} admins • ${_totalCustomers} customers',
            ),
            _buildStatCard(
              'Active Users',
              _activeUsers.toString(),
              Icons.person,
              Colors.pink,
              '${_suspendedUsers} suspended users',
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color, String subtitle) {
    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, color: color, size: 24),
                ),
                Flexible(
                  child: Text(
                    value,
                    style: TextStyle(
                      fontSize: value.length > 10 ? 14 : 18,
                      fontWeight: FontWeight.bold,
                      color: color,
                    ),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 2,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              title,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Colors.grey,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: const TextStyle(
                fontSize: 12,
                color: Colors.grey,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOrderAnalyticsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Order Analytics',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 16),
        Card(
          elevation: 4,
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                // Order Status Breakdown
                const Text(
                  'Order Status Distribution',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 12),
                _buildOrderStatusChart(),
                const SizedBox(height: 16),
                const Divider(),
                const SizedBox(height: 16),
                // Payment Methods
                const Text(
                  'Payment Methods',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 12),
                _buildPaymentMethodsChart(),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildOrderStatusChart() {
    final total = _totalOrders;
    if (total == 0) {
      return const Center(
        child: Text(
          'No orders yet',
          style: TextStyle(color: Colors.grey),
        ),
      );
    }

    final statuses = [
      {'status': 'Pending', 'count': _pendingOrders, 'color': Colors.orange},
      {'status': 'Processing', 'count': _processingOrders, 'color': Colors.blue},
      {'status': 'Shipped', 'count': _shippedOrders, 'color': Colors.purple},
      {'status': 'Delivered', 'count': _deliveredOrders, 'color': Colors.green},
      {'status': 'Cancelled', 'count': _cancelledOrders, 'color': Colors.red},
    ];

    return Column(
      children: statuses.map((status) {
        final count = status['count'] as int;
        final percentage = total > 0 ? (count / total * 100) : 0;
        final color = status['color'] as Color;

        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 4.0),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 12,
                        height: 12,
                        decoration: BoxDecoration(
                          color: color,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        status['status'] as String,
                        style: const TextStyle(fontSize: 14),
                      ),
                    ],
                  ),
                  Text(
                    '$count (${percentage.toStringAsFixed(1)}%)',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: color,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              LinearProgressIndicator(
                value: total > 0 ? count / total : 0,
                backgroundColor: color.withOpacity(0.1),
                valueColor: AlwaysStoppedAnimation<Color>(color),
                minHeight: 6,
              ),
              const SizedBox(height: 8),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildPaymentMethodsChart() {
    if (_ordersByPaymentMethod.isEmpty) {
      return const Center(
        child: Text(
          'No payment data',
          style: TextStyle(color: Colors.grey),
        ),
      );
    }

    final entries = _ordersByPaymentMethod.entries.toList();
    return Column(
      children: entries.map((entry) {
        final method = entry.key;
        final count = entry.value;
        final percentage = _totalOrders > 0 ? (count / _totalOrders * 100) : 0;

        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 4.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                method.replaceAll('-', ' ').toUpperCase(),
                style: const TextStyle(fontSize: 14),
              ),
              Text(
                '$count (${percentage.toStringAsFixed(1)}%)',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.blue,
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildRecentActivitySection() {
    final activities = _getRecentActivities();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Recent Activity',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            TextButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => AnalyticsScreen(
                      users: _users,
                      frames: _frames,
                      orders: _orders,
                      statistics: _getAnalyticsData(),
                    ),
                  ),
                );
              },
              child: const Text('View All Analytics'),
            ),
          ],
        ),
        const SizedBox(height: 16),
        activities.isNotEmpty
            ? Card(
          elevation: 4,
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                for (int i = 0; i < activities.length && i < 5; i++)
                  Column(
                    children: [
                      ListTile(
                        leading: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: (activities[i]['color'] as Color).withOpacity(0.1),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            activities[i]['icon'] as IconData,
                            color: activities[i]['color'] as Color,
                            size: 20,
                          ),
                        ),
                        title: Text(
                          activities[i]['text'] as String,
                          style: const TextStyle(fontSize: 14),
                        ),
                        subtitle: Text(
                          activities[i]['details'] as String? ?? '',
                          style: const TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                        trailing: Text(
                          activities[i]['time'] as String,
                          style: const TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                        contentPadding: EdgeInsets.zero,
                      ),
                      if (i < activities.length - 1 && i < 4) const Divider(height: 1),
                    ],
                  ),
              ],
            ),
          ),
        )
            : Card(
          elevation: 4,
          child: Padding(
            padding: const EdgeInsets.all(32.0),
            child: Column(
              children: [
                Icon(
                  Icons.history,
                  size: 48,
                  color: Colors.grey[300],
                ),
                const SizedBox(height: 16),
                const Text(
                  'No recent activity',
                  style: TextStyle(
                    color: Colors.grey,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  List<Map<String, dynamic>> _getRecentActivities() {
    final activities = <Map<String, dynamic>>[];

    // Recent orders (last 10) - FIXED
    List<Order> recentOrders = List<Order>.from(_orders);
    recentOrders.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    recentOrders = recentOrders.take(10).toList();

    for (final order in recentOrders) {
      activities.add({
        'icon': Icons.shopping_cart,
        'text': 'Order #${order.orderNumber}',
        'details': '${order.getStatusDisplay()} • रु ${order.totalAmount.toStringAsFixed(0)}',
        'time': _getTimeAgo(order.createdAt),
        'color': order.getStatusColor(),
      });
    }

    // Recent user registrations (last 5) - FIXED
    List<UserModel> recentUsers = _users
        .where((user) => user.createdAt != null)
        .toList();
    recentUsers.sort((a, b) => b.createdAt!.compareTo(a.createdAt!));
    recentUsers = recentUsers.take(5).toList();

    for (final user in recentUsers) {
      activities.add({
        'icon': Icons.person_add,
        'text': 'New user: ${user.username}',
        'details': user.email ?? 'No email',
        'time': _getTimeAgo(user.createdAt!),
        'color': Colors.green,
      });
    }

    // Sort all activities by time (most recent first)
    activities.sort((a, b) {
      // Simple comparison based on time string
      final aTime = a['time'] as String;
      final bTime = b['time'] as String;
      return _compareTimeStrings(bTime, aTime);
    });

    return activities.take(10).toList();
  }

// Add this helper method to compare time strings
  int _compareTimeStrings(String a, String b) {
    // Extract numeric values from time strings
    final aMatch = RegExp(r'(\d+)').firstMatch(a);
    final bMatch = RegExp(r'(\d+)').firstMatch(b);

    if (aMatch == null || bMatch == null) return 0;

    final aValue = int.tryParse(aMatch.group(1)!) ?? 0;
    final bValue = int.tryParse(bMatch.group(1)!) ?? 0;

    // Assign weights based on time unit
    int getWeight(String time) {
      if (time.contains('month')) return 4;
      if (time.contains('d')) return 3;
      if (time.contains('h')) return 2;
      if (time.contains('m')) return 1;
      return 0;
    }

    final aWeight = getWeight(a);
    final bWeight = getWeight(b);

    if (aWeight != bWeight) {
      return bWeight.compareTo(aWeight); // Higher weight = more recent
    }

    return bValue.compareTo(aValue); // Higher value = more recent for same unit
  }

  Map<String, dynamic> _getAnalyticsData() {
    return {
      'totalOrders': _totalOrders,
      'totalRevenue': _totalRevenue,
      'inventoryValue': _inventoryValue,
      'totalUsers': _totalUsers,
      'totalProducts': _totalProducts,
      'pendingOrders': _pendingOrders,
      'processingOrders': _processingOrders,
      'shippedOrders': _shippedOrders,
      'deliveredOrders': _deliveredOrders,
      'cancelledOrders': _cancelledOrders,
      'todayOrders': _todayOrders,
      'todayRevenue': _todayRevenue,
      'thisWeekOrders': _thisWeekOrders,
      'thisWeekRevenue': _thisWeekRevenue,
      'thisMonthOrders': _thisMonthOrders,
      'thisMonthRevenue': _thisMonthRevenue,
      'averageOrderValue': _averageOrderValue,
      'ordersByPaymentMethod': _ordersByPaymentMethod,
      'revenueByMonth': _revenueByMonth,
      'lowStockProducts': _lowStockProducts,
      'outOfStockProducts': _outOfStockProducts,
    };
  }

  Widget _buildAdminFeaturesSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Management Tools',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 16),
        GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 2,
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
          children: [
            _buildAdminCard(
              'Order Management',
              Icons.shopping_cart,
              Colors.blue,
              '$_totalOrders orders',
                  () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const OrderManagementScreen(),
                  ),
                );
              },
            ),
            _buildAdminCard(
              'User Management',
              Icons.people,
              Colors.green,
              '$_totalUsers users',
                  () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const UserManagementScreen(),
                  ),
                );
              },
            ),
            _buildAdminCard(
              'Frame Management',
              Icons.inventory,
              Colors.orange,
              '$_totalProducts frames',
                  () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const FrameManagementScreen(),
                  ),
                );
              },
            ),
            _buildAdminCard(
              'Analytics & Reports',
              Icons.analytics,
              Colors.purple,
              'View insights',
                  () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => AnalyticsScreen(
                      users: _users,
                      frames: _frames,
                      orders: _orders,
                      statistics: _getAnalyticsData(),
                    ),
                  ),
                );
              },
            ),
            _buildAdminCard(
              'Categories',
              Icons.category,
              Colors.teal,
              'Manage categories',
                  () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const MainCategoryManagementScreen(),
                  ),
                );
              },
            ),
            _buildAdminCard(
              'System Settings',
              Icons.settings,
              Colors.grey,
              'Configure system',
                  () {
                _showComingSoonDialog('System Settings');
              },
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildAdminCard(String title, IconData icon, Color color, String subtitle, VoidCallback onTap) {
    return Card(
      elevation: 4,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [color.withOpacity(0.1), color.withOpacity(0.3)],
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, size: 32, color: color),
                ),
                const SizedBox(height: 12),
                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey[800],
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSystemStatusSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'System Status',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 16),
        Card(
          elevation: 4,
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                _buildStatusItem(
                  'Server Status',
                  _systemStatus['server']!,
                  Icons.cloud,
                  _getStatusColor(_systemStatus['server']!),
                ),
                const Divider(),
                _buildStatusItem(
                  'Database',
                  _systemStatus['database']!,
                  Icons.storage,
                  _getStatusColor(_systemStatus['database']!),
                ),
                const Divider(),
                _buildStatusItem(
                  'API Services',
                  _systemStatus['api']!,
                  Icons.api,
                  _getStatusColor(_systemStatus['api']!),
                ),
                const Divider(),
                _buildStatusItem(
                  'Security',
                  _systemStatus['security']!,
                  Icons.security,
                  _getStatusColor(_systemStatus['security']!),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStatusItem(String title, String status, IconData icon, Color color) {
    return ListTile(
      leading: Icon(icon, color: color),
      title: Text(title),
      trailing: Chip(
        label: Text(
          status,
          style: const TextStyle(color: Colors.white, fontSize: 12),
        ),
        backgroundColor: color,
      ),
      contentPadding: EdgeInsets.zero,
    );
  }

  void _showComingSoonDialog(String feature) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.build, color: Colors.blue),
              SizedBox(width: 8),
              Text('Coming Soon'),
            ],
          ),
          content: Text('$feature feature is coming soon!'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('OK'),
            ),
          ],
        );
      },
    );
  }

  String _getTimeAgo(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inMinutes < 1) return 'Just now';
    if (difference.inMinutes < 60) return '${difference.inMinutes}m ago';
    if (difference.inHours < 24) return '${difference.inHours}h ago';
    if (difference.inDays < 30) return '${difference.inDays}d ago';

    final months = (difference.inDays / 30).floor();
    return '$months month${months > 1 ? 's' : ''} ago';
  }
}

// Extension for list sorting
extension ListSorting<T> on List<T> {
  List<T> sorted(int Function(T, T) compare) {
    final newList = List<T>.from(this);
    newList.sort(compare);
    return newList;
  }
}