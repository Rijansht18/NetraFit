import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../core/config/api_config.dart';
import '../../providers/auth_provider.dart';
import '../../routes.dart';
import 'user_management_screen.dart';
import 'add_user_screen.dart';
import 'main_category_management_screen.dart';
import '../../services/admin_service.dart';
import '../../models/api_response.dart';
import '../../models/user_model.dart';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({Key? key}) : super(key: key);

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  final AdminService _adminService = AdminService();
  List<UserModel> _users = [];
  bool _isLoading = true;

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
  }

  Future<void> _loadDashboardData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final ApiResponse response = await _adminService.getAllUsers();
      if (response.success == true) {
        setState(() {
          _users = (response.data?['users'] as List? ?? [])
              .map((userData) => UserModel.fromJson(userData))
              .toList();
        });
      } else {
        _showErrorDialog(response.error ?? 'Failed to load dashboard data');
      }
    } catch (e) {
      _showErrorDialog('Network error: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
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
      // Check Backend API
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

  // Calculate real statistics from user data
  int get _totalUsers => _users.length;
  int get _totalAdmins => _users.where((user) => user.isAdmin).length;
  int get _totalCustomers => _users.where((user) => user.isCustomer).length;
  int get _activeUsers => _users.where((user) => user.isActive).length;
  int get _suspendedUsers => _users.where((user) => user.isSuspended).length;

  // For demo purposes - you can replace with real data later
  int get _totalProducts => 567;
  int get _totalOrders => 89;
  double get _revenue => 12456.0;
  int get _pendingOrders => 23;
  int get _lowStockProducts => 12;

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
            onPressed: () {
              _loadDashboardData();
              _checkSystemStatus();
            },
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
          : SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Welcome Section
              Card(
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
                              'Welcome, Admin!',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.grey[700],
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              authProvider.user?.username ?? 'Admin',
                              style: TextStyle(
                                fontSize: 16,
                                color: Colors.grey[600],
                              ),
                            ),
                            Text(
                              authProvider.user?.email ?? '',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey[500],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 20),

              // Quick Stats Grid
              const Text(
                'Dashboard Overview',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),

              // Stats Grid
              GridView.count(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisCount: 2,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
                children: [
                  _buildStatCard(
                    'Total Users',
                    _totalUsers.toString(),
                    Icons.people,
                    Colors.blue,
                    '+12% from last month',
                  ),
                  _buildStatCard(
                    'Total Products',
                    _totalProducts.toString(),
                    Icons.inventory,
                    Colors.green,
                    '+8% from last month',
                  ),
                  _buildStatCard(
                    'Total Orders',
                    _totalOrders.toString(),
                    Icons.shopping_cart,
                    Colors.orange,
                    '+23% from last month',
                  ),
                  _buildStatCard(
                    'Revenue',
                    '\$${_revenue.toStringAsFixed(0)}',
                    Icons.attach_money,
                    Colors.purple,
                    '+15% from last month',
                  ),
                  _buildStatCard(
                    'Pending Orders',
                    _pendingOrders.toString(),
                    Icons.pending_actions,
                    Colors.amber,
                    'Need attention',
                  ),
                  _buildStatCard(
                    'Low Stock',
                    _lowStockProducts.toString(),
                    Icons.warning,
                    Colors.red,
                    'Products need restock',
                  ),
                ],
              ),

              const SizedBox(height: 24),

              // Recent Activity Section
              const Text(
                'Recent Activity',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              _buildRecentActivity(),

              const SizedBox(height: 24),

              // Quick Actions Section
              const Text(
                'Quick Actions',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              _buildQuickActions(),

              const SizedBox(height: 24),

              // Admin Features Grid
              const Text(
                'Admin Features',
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
                    'User Management',
                    Icons.people,
                    Colors.blue,
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
                    'Add New User',
                    Icons.person_add,
                    Colors.green,
                        () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const AddUserScreen(),
                        ),
                      ).then((_) {
                        _loadDashboardData();
                      });
                    },
                  ),
                  _buildAdminCard(
                    'Category Management',
                    Icons.category,
                    Colors.teal,
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
                    'Product Catalog',
                    Icons.inventory,
                    Colors.orange,
                        () {
                      _showComingSoonDialog('Product Catalog');
                    },
                  ),
                  _buildAdminCard(
                    'Order Management',
                    Icons.shopping_cart,
                    Colors.purple,
                        () {
                      _showComingSoonDialog('Order Management');
                    },
                  ),
                  _buildAdminCard(
                    'Analytics',
                    Icons.analytics,
                    Colors.red,
                        () {
                      _showComingSoonDialog('Analytics');
                    },
                  ),
                ],
              ),

              const SizedBox(height: 24),

              // System Status Section
              const Text(
                'System Status',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              _buildSystemStatus(),

              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
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
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('OK'),
            ),
          ],
        );
      },
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
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 20,
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

  Widget _buildRecentActivity() {
    // Get recent user registrations (last 5)
    final recentUsers = _users.take(5).toList();

    final List<Map<String, dynamic>> activities = [
      if (recentUsers.isNotEmpty)
        for (final user in recentUsers)
          {
            'icon': Icons.person_add,
            'text': 'New user: ${user.username}',
            'time': _getTimeAgo(user.createdAt),
            'color': Colors.green,
          },
      // Fallback activities if no users
      if (recentUsers.isEmpty) ...[
        {
          'icon': Icons.person_add,
          'text': 'New user registered: john_doe',
          'time': '2 min ago',
          'color': Colors.green
        },
        {
          'icon': Icons.shopping_cart,
          'text': 'New order #12345 placed',
          'time': '5 min ago',
          'color': Colors.blue
        },
        {
          'icon': Icons.inventory,
          'text': 'Product "Classic Glasses" low stock',
          'time': '10 min ago',
          'color': Colors.orange
        },
        {
          'icon': Icons.payment,
          'text': 'Payment received for order #12344',
          'time': '15 min ago',
          'color': Colors.green
        },
        {
          'icon': Icons.warning,
          'text': 'System backup completed',
          'time': '1 hour ago',
          'color': Colors.purple
        },
      ]
    ];

    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            for (int i = 0; i < activities.length; i++)
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
                    trailing: Text(
                      activities[i]['time'] as String,
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                    contentPadding: EdgeInsets.zero,
                  ),
                  if (i < activities.length - 1) const Divider(height: 1),
                ],
              ),
          ],
        ),
      ),
    );
  }

  String _getTimeAgo(DateTime? date) {
    if (date == null) return 'Recently';

    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inMinutes < 1) return 'Just now';
    if (difference.inMinutes < 60) return '${difference.inMinutes}m ago';
    if (difference.inHours < 24) return '${difference.inHours}h ago';
    if (difference.inDays < 30) return '${difference.inDays}d ago';

    final months = (difference.inDays / 30).floor();
    return '$months month${months > 1 ? 's' : ''} ago';
  }

  Widget _buildQuickActions() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _buildQuickActionCard('Add User', Icons.person_add, Colors.blue),
          const SizedBox(width: 12),
          _buildQuickActionCard('Add Category', Icons.category, Colors.green),
          const SizedBox(width: 12),
          _buildQuickActionCard('View Reports', Icons.analytics, Colors.orange),
          const SizedBox(width: 12),
          _buildQuickActionCard('Send Email', Icons.email, Colors.purple),
          const SizedBox(width: 12),
          _buildQuickActionCard('Backup', Icons.backup, Colors.red),
        ],
      ),
    );
  }

  Widget _buildQuickActionCard(String title, IconData icon, Color color) {
    return Card(
      elevation: 3,
      child: Container(
        width: 120,
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(height: 8),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSystemStatus() {
    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            _buildStatusItem(
                'Server Status',
                _systemStatus['server']!,
                Icons.cloud,
                _getStatusColor(_systemStatus['server']!)
            ),
            const Divider(),
            _buildStatusItem(
                'Database',
                _systemStatus['database']!,
                Icons.storage,
                _getStatusColor(_systemStatus['database']!)
            ),
            const Divider(),
            _buildStatusItem(
                'API Services',
                _systemStatus['api']!,
                Icons.api,
                _getStatusColor(_systemStatus['api']!)
            ),
            const Divider(),
            _buildStatusItem(
                'Security',
                _systemStatus['security']!,
                Icons.security,
                _getStatusColor(_systemStatus['security']!)
            ),
          ],
        ),
      ),
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

  Widget _buildAdminCard(String title, IconData icon, Color color, VoidCallback onTap) {
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
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
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
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}