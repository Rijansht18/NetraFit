// screens/admin/analytics_screen.dart
import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_charts/charts.dart';
import '../../models/user_model.dart';
import '../../models/frame_model.dart';
import '../../models/order_model.dart' hide Frame;

class AnalyticsScreen extends StatefulWidget {
  final List<UserModel> users;
  final List<Frame> frames;
  final List<Order> orders;
  final Map<String, dynamic> statistics;

  const AnalyticsScreen({
    Key? key,
    required this.users,
    required this.frames,
    required this.orders,
    required this.statistics,
  }) : super(key: key);

  @override
  State<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends State<AnalyticsScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Analytics & Reports'),
        backgroundColor: const Color(0xFF275BCD),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Overview'),
            Tab(text: 'Orders'),
            Tab(text: 'Users'),
            Tab(text: 'Products'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildOverviewTab(),
          _buildOrdersTab(),
          _buildUsersTab(),
          _buildProductsTab(),
        ],
      ),
    );
  }

  Widget _buildOverviewTab() {
    final stats = widget.statistics;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Key Metrics
          const Text(
            'Key Metrics',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 2,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
            children: [
              _buildMetricCard('Total Revenue', 'रु ${stats['totalRevenue']?.toStringAsFixed(0) ?? "0"}', Icons.attach_money, Colors.green),
              _buildMetricCard('Total Orders', '${stats['totalOrders'] ?? 0}', Icons.shopping_cart, Colors.blue),
              _buildMetricCard('Total Users', '${stats['totalUsers'] ?? 0}', Icons.people, Colors.purple),
              _buildMetricCard('Total Products', '${stats['totalProducts'] ?? 0}', Icons.inventory, Colors.orange),
              _buildMetricCard('Inventory Value', 'रु ${stats['inventoryValue']?.toStringAsFixed(0) ?? "0"}', Icons.warehouse, Colors.teal),
              _buildMetricCard('Avg Order Value', 'रु ${stats['averageOrderValue']?.toStringAsFixed(0) ?? "0"}', Icons.analytics, Colors.pink),
            ],
          ),
          const SizedBox(height: 24),

          // Revenue Trend
          const Text(
            'Revenue Trend (Last 6 Months)',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          _buildRevenueChart(),
          const SizedBox(height: 24),

          // Order Status Distribution
          const Text(
            'Order Status Distribution',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          _buildOrderStatusChart(),
        ],
      ),
    );
  }

  Widget _buildOrdersTab() {
    final stats = widget.statistics;
    final orders = widget.orders;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Order Statistics
          const Text(
            'Order Statistics',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 2,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
            children: [
              _buildMetricCard('Today Orders', '${stats['todayOrders'] ?? 0}', Icons.today, Colors.blue),
              _buildMetricCard('Week Orders', '${stats['thisWeekOrders'] ?? 0}', Icons.calendar_view_week, Colors.green),
              _buildMetricCard('Month Orders', '${stats['thisMonthOrders'] ?? 0}', Icons.calendar_month, Colors.orange),
              _buildMetricCard('Delivered', '${stats['deliveredOrders'] ?? 0}', Icons.check_circle, Colors.green),
              _buildMetricCard('Pending', '${stats['pendingOrders'] ?? 0}', Icons.pending, Colors.orange),
              _buildMetricCard('Cancelled', '${stats['cancelledOrders'] ?? 0}', Icons.cancel, Colors.red),
            ],
          ),
          const SizedBox(height: 24),

          // Payment Methods
          const Text(
            'Payment Methods',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          _buildPaymentMethodsChart(),
          const SizedBox(height: 24),

          // Recent Orders - FIXED
          const Text(
            'Recent Orders',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          _buildRecentOrdersList(),
        ],
      ),
    );
  }

  Widget _buildUsersTab() {
    final users = widget.users;
    final stats = widget.statistics;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // User Statistics
          const Text(
            'User Statistics',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 2,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
            children: [
              _buildMetricCard('Total Users', '${stats['totalUsers'] ?? 0}', Icons.people, Colors.blue),
              _buildMetricCard('Admins', '${_countAdmins(users)}', Icons.admin_panel_settings, Colors.purple),
              _buildMetricCard('Customers', '${_countCustomers(users)}', Icons.person, Colors.green),
              _buildMetricCard('Active', '${_countActiveUsers(users)}', Icons.check_circle, Colors.green),
              _buildMetricCard('Suspended', '${_countSuspendedUsers(users)}', Icons.block, Colors.red),
              _buildMetricCard('New Today', '${_countNewUsersToday(users)}', Icons.new_releases, Colors.orange),
            ],
          ),
          const SizedBox(height: 24),

          // User Growth Chart
          const Text(
            'User Registration Trend',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          _buildUserGrowthChart(),
          const SizedBox(height: 24),

          // Recent Users - FIXED
          const Text(
            'Recent Users',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          _buildRecentUsersList(),
        ],
      ),
    );
  }

  Widget _buildProductsTab() {
    final frames = widget.frames;
    final stats = widget.statistics;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Product Statistics
          const Text(
            'Product Statistics',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 2,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
            children: [
              _buildMetricCard('Total Frames', '${stats['totalProducts'] ?? 0}', Icons.inventory, Colors.blue),
              _buildMetricCard('Low Stock', '${stats['lowStockProducts'] ?? 0}', Icons.warning, Colors.orange),
              _buildMetricCard('Out of Stock', '${stats['outOfStockProducts'] ?? 0}', Icons.error, Colors.red),
              _buildMetricCard('Inventory Value', 'रु ${stats['inventoryValue']?.toStringAsFixed(0) ?? "0"}', Icons.warehouse, Colors.teal),
              _buildMetricCard('Avg Price', 'रु ${_calculateAveragePrice(frames)}', Icons.attach_money, Colors.green),
              _buildMetricCard('Total Quantity', '${_calculateTotalQuantity(frames)}', Icons.layers, Colors.purple),
            ],
          ),
          const SizedBox(height: 24),

          // Stock Status
          const Text(
            'Stock Status',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          _buildStockStatusChart(),
          const SizedBox(height: 24),

          // Top Selling Products - FIXED
          const Text(
            'Top Products by Value',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          _buildTopProductsList(),
        ],
      ),
    );
  }

  Widget _buildMetricCard(String title, String value, IconData icon, Color color) {
    return Card(
      elevation: 3,
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(height: 8),
            Text(
              value,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              title,
              textAlign: TextAlign.center,
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

  Widget _buildRevenueChart() {
    final revenueData = widget.statistics['revenueByMonth'] as Map<String, double>? ?? {};
    final chartData = revenueData.entries.map((entry) {
      return ChartData(entry.key, entry.value);
    }).toList();

    return Container(
      height: 300,
      padding: const EdgeInsets.all(8),
      child: SfCartesianChart(
        primaryXAxis: CategoryAxis(),
        // FIXED: Use correct series type
        series: <CartesianSeries<ChartData, String>>[
          LineSeries<ChartData, String>(
            dataSource: chartData,
            xValueMapper: (ChartData data, _) => data.month,
            yValueMapper: (ChartData data, _) => data.revenue,
            name: 'Revenue',
            color: Colors.green,
            markerSettings: const MarkerSettings(isVisible: true),
          )
        ],
        tooltipBehavior: TooltipBehavior(enable: true),
      ),
    );
  }

  Widget _buildOrderStatusChart() {
    final stats = widget.statistics;
    final chartData = [
      ChartData('Pending', (stats['pendingOrders'] as int?)?.toDouble() ?? 0),
      ChartData('Processing', (stats['processingOrders'] as int?)?.toDouble() ?? 0),
      ChartData('Shipped', (stats['shippedOrders'] as int?)?.toDouble() ?? 0),
      ChartData('Delivered', (stats['deliveredOrders'] as int?)?.toDouble() ?? 0),
      ChartData('Cancelled', (stats['cancelledOrders'] as int?)?.toDouble() ?? 0),
    ];

    return Container(
      height: 300,
      child: SfCircularChart(
        legend: Legend(isVisible: true),
        // FIXED: Use correct series type
        series: <CircularSeries<ChartData, String>>[
          PieSeries<ChartData, String>(
            dataSource: chartData,
            xValueMapper: (ChartData data, _) => data.month,
            yValueMapper: (ChartData data, _) => data.revenue,
            dataLabelSettings: const DataLabelSettings(isVisible: true),
          )
        ],
      ),
    );
  }

  Widget _buildPaymentMethodsChart() {
    final paymentData = widget.statistics['ordersByPaymentMethod'] as Map<String, int>? ?? {};
    final chartData = paymentData.entries.map((entry) {
      return ChartData(entry.key.replaceAll('-', ' ').toUpperCase(), entry.value.toDouble());
    }).toList();

    return Container(
      height: 200,
      child: chartData.isNotEmpty
          ? SfCircularChart(
        legend: Legend(isVisible: true),
        // FIXED: Use correct series type
        series: <CircularSeries<ChartData, String>>[
          DoughnutSeries<ChartData, String>(
            dataSource: chartData,
            xValueMapper: (ChartData data, _) => data.month,
            yValueMapper: (ChartData data, _) => data.revenue,
            dataLabelSettings: const DataLabelSettings(isVisible: true),
          )
        ],
      )
          : const Center(
        child: Text('No payment data available'),
      ),
    );
  }

  Widget _buildRecentOrdersList() {
    // FIXED: Proper sorting without cascade
    List<Order> recentOrders = List<Order>.from(widget.orders);
    recentOrders.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    recentOrders = recentOrders.take(10).toList();

    return Card(
      elevation: 3,
      child: ListView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: recentOrders.length,
        itemBuilder: (context, index) {
          final order = recentOrders[index];
          return ListTile(
            leading: CircleAvatar(
              backgroundColor: order.getStatusColor().withOpacity(0.1),
              child: Icon(
                order.getStatusIcon(),
                color: order.getStatusColor(),
                size: 20,
              ),
            ),
            title: Text('Order #${order.orderNumber}'),
            subtitle: Text(
              'रु ${order.totalAmount.toStringAsFixed(0)} • ${order.getStatusDisplay()}',
              style: TextStyle(color: order.getStatusColor()),
            ),
            trailing: Text(_getTimeAgo(order.createdAt)),
          );
        },
      ),
    );
  }

  Widget _buildUserGrowthChart() {
    // This would require tracking user registration dates
    // For now, we'll show a placeholder
    return Container(
      height: 200,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        color: Colors.grey[100],
      ),
      child: const Center(
        child: Text('User growth chart would be here'),
      ),
    );
  }

  Widget _buildRecentUsersList() {
    // FIXED: Proper sorting without cascade
    List<UserModel> recentUsers = widget.users
        .where((user) => user.createdAt != null)
        .toList();
    recentUsers.sort((a, b) => b.createdAt!.compareTo(a.createdAt!));
    recentUsers = recentUsers.take(10).toList();

    return Card(
      elevation: 3,
      child: ListView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: recentUsers.length,
        itemBuilder: (context, index) {
          final user = recentUsers[index];
          return ListTile(
            leading: CircleAvatar(
              backgroundColor: Colors.blue.withOpacity(0.1),
              child: Text(user.username[0].toUpperCase()),
            ),
            title: Text(user.username),
            subtitle: Text(user.email ?? 'No email'),
            trailing: Text(_getTimeAgo(user.createdAt!)),
          );
        },
      ),
    );
  }

  Widget _buildStockStatusChart() {
    final frames = widget.frames;
    final inStock = frames.where((frame) => frame.quantity >= 10).length;
    final lowStock = frames.where((frame) => frame.quantity > 0 && frame.quantity < 10).length;
    final outOfStock = frames.where((frame) => frame.quantity == 0).length;

    final chartData = [
      ChartData('In Stock', inStock.toDouble()),
      ChartData('Low Stock', lowStock.toDouble()),
      ChartData('Out of Stock', outOfStock.toDouble()),
    ];

    return Container(
      height: 200,
      child: SfCircularChart(
        legend: Legend(isVisible: true),
        // FIXED: Use correct series type
        series: <CircularSeries<ChartData, String>>[
          PieSeries<ChartData, String>(
            dataSource: chartData,
            xValueMapper: (ChartData data, _) => data.month,
            yValueMapper: (ChartData data, _) => data.revenue,
            dataLabelSettings: const DataLabelSettings(isVisible: true),
          )
        ],
      ),
    );
  }

  Widget _buildTopProductsList() {
    // FIXED: Proper sorting without cascade
    List<Frame> frames = List<Frame>.from(widget.frames);
    frames.sort((a, b) => (b.price * b.quantity).compareTo(a.price * a.quantity));
    frames = frames.take(10).toList();

    return Card(
      elevation: 3,
      child: ListView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: frames.length,
        itemBuilder: (context, index) {
          final frame = frames[index];
          final value = frame.price * frame.quantity;
          return ListTile(
            leading: CircleAvatar(
              backgroundColor: Colors.orange.withOpacity(0.1),
              child: const Icon(Icons.inventory, color: Colors.orange),
            ),
            title: Text(frame.name),
            subtitle: Text('Quantity: ${frame.quantity} • Price: रु ${frame.price.toStringAsFixed(0)}'),
            trailing: Text(
              'रु ${value.toStringAsFixed(0)}',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          );
        },
      ),
    );
  }

  // Helper methods
  int _countAdmins(List<UserModel> users) => users.where((user) => user.isAdmin).length;
  int _countCustomers(List<UserModel> users) => users.where((user) => user.isCustomer).length;
  int _countActiveUsers(List<UserModel> users) => users.where((user) => user.isActive).length;
  int _countSuspendedUsers(List<UserModel> users) => users.where((user) => user.isSuspended).length;
  int _countNewUsersToday(List<UserModel> users) {
    final today = DateTime.now();
    final startOfDay = DateTime(today.year, today.month, today.day);
    return users.where((user) => user.createdAt != null && user.createdAt!.isAfter(startOfDay)).length;
  }

  String _calculateAveragePrice(List<Frame> frames) {
    if (frames.isEmpty) return '0';
    final total = frames.fold(0.0, (sum, frame) => sum + frame.price);
    return (total / frames.length).toStringAsFixed(0);
  }

  String _calculateTotalQuantity(List<Frame> frames) {
    final total = frames.fold(0, (sum, frame) => sum + frame.quantity);
    return total.toString();
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

// Chart data model
class ChartData {
  final String month;
  final double revenue;

  ChartData(this.month, this.revenue);
}