import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:netrafit/providers/auth_provider.dart';
import 'package:netrafit/models/order_model.dart';
import 'package:netrafit/services/order_service.dart';

class UserOrdersScreen extends StatefulWidget {
  const UserOrdersScreen({super.key});

  @override
  State<UserOrdersScreen> createState() => _UserOrdersScreenState();
}

class _UserOrdersScreenState extends State<UserOrdersScreen> {
  final OrderService _orderService = OrderService();
  List<Order> _orders = [];
  bool _isLoading = true;
  String _errorMessage = '';
  String _selectedFilter = 'all';

  @override
  void initState() {
    super.initState();
    _loadOrders();
  }

  Future<void> _loadOrders() async {
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    final authProvider = context.read<AuthProvider>();
    final token = authProvider.token;

    if (token == null) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Please login to view orders';
      });
      return;
    }

    final response = await _orderService.getAllOrders(token: token);

    setState(() {
      _isLoading = false;
    });

    if (response.success) {
      // The response.data?['orders'] should already be List<Order>
      final ordersData = response.data?['orders'];

      if (ordersData is List<Order>) {
        setState(() {
          _orders = ordersData;
        });
      } else if (ordersData is List<dynamic>) {
        // Fallback: Convert dynamic list to Order list
        final orders = ordersData.whereType<Map<String, dynamic>>()
            .map((json) => Order.fromJson(json))
            .toList();
        setState(() {
          _orders = orders;
        });
      } else {
        setState(() {
          _errorMessage = 'Invalid orders data format';
          _orders = [];
        });
      }
    } else {
      setState(() {
        _errorMessage = response.error ?? 'Failed to load orders';
        _orders = [];
      });
    }
  }

  Future<void> _cancelOrder(String orderId) async {
    final authProvider = context.read<AuthProvider>();
    final token = authProvider.token;

    if (token == null) return;

    final confirmed = await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cancel Order'),
        content: const Text('Are you sure you want to cancel this order?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('No'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Yes, Cancel'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    final response = await _orderService.cancelOrder(orderId, token);

    if (response.success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Order cancelled successfully'),
          backgroundColor: Colors.green,
        ),
      );
      _loadOrders(); // Refresh orders
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(response.error ?? 'Failed to cancel order'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _updateOrderStatus(String orderId, String newStatus) async {
    final authProvider = context.read<AuthProvider>();
    final token = authProvider.token;

    if (token == null) return;

    final response = await _orderService.updateOrderStatus(
      orderId: orderId,
      orderStatus: newStatus,
      token: token,
    );

    if (response.success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Order status updated to $newStatus'),
          backgroundColor: Colors.green,
        ),
      );
      _loadOrders(); // Refresh orders
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(response.error ?? 'Failed to update order status'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _viewOrderDetails(Order order) {
    final totalItems = order.items.fold(0, (sum, item) => sum + item.quantity);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Order #${order.orderNumber ?? order.id?.substring(0, 8) ?? 'N/A'}'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildDetailItem('Status', order.getStatusDisplay()),
              _buildDetailItem('Payment', order.getPaymentStatusDisplay()),
              _buildDetailItem('Total', 'रु ${order.totalAmount}'),
              _buildDetailItem('Date', '${order.createdAt.day}/${order.createdAt.month}/${order.createdAt.year}'),
              _buildDetailItem('Items', '$totalItems item${totalItems != 1 ? 's' : ''}'),

              const SizedBox(height: 16),
              const Text('Items:', style: TextStyle(fontWeight: FontWeight.bold)),
              ...order.items.map((item) => Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        item.frameDetails?.name ?? 'Frame ${item.frame.substring(0, 8)}...',
                        style: const TextStyle(fontSize: 14),
                      ),
                    ),
                    Text(
                      '${item.quantity} × रु ${item.price}',
                      style: const TextStyle(fontSize: 14),
                    ),
                  ],
                ),
              )).toList(),

              const SizedBox(height: 16),
              const Text('Shipping Address:', style: TextStyle(fontWeight: FontWeight.bold)),
              Text(order.shippingAddress.fullName),
              Text(order.shippingAddress.phone),
              Text(order.shippingAddress.address),

              if (order.notes?.isNotEmpty ?? false) ...[
                const SizedBox(height: 16),
                const Text('Notes:', style: TextStyle(fontWeight: FontWeight.bold)),
                Text(order.notes!),
              ],

              if (order.trackingNumber?.isNotEmpty ?? false) ...[
                const SizedBox(height: 16),
                _buildDetailItem('Tracking Number', order.trackingNumber!),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailItem(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Text('$label: ', style: const TextStyle(fontWeight: FontWeight.bold)),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }

  List<Order> _getFilteredOrders() {
    if (_selectedFilter == 'all') return _orders;
    return _orders.where((order) =>
    order.orderStatus.toLowerCase() == _selectedFilter
    ).toList();
  }

  Widget _buildOrderCard(Order order) {
    final totalItems = order.items.fold(0, (sum, item) => sum + item.quantity);

    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Order header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Order #${order.orderNumber ?? order.id?.substring(0, 8) ?? 'N/A'}',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      '${order.createdAt.day}/${order.createdAt.month}/${order.createdAt.year}',
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.grey,
                      ),
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: order.getStatusColor().withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: order.getStatusColor()),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(order.getStatusIcon(), size: 14, color: order.getStatusColor()),
                      const SizedBox(width: 4),
                      Text(
                        order.getStatusDisplay(),
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: order.getStatusColor(),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),

            // Order summary
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${totalItems} item${totalItems != 1 ? 's' : ''}',
                  style: const TextStyle(
                    fontSize: 14,
                    color: Colors.grey,
                  ),
                ),
                const SizedBox(height: 4),
                if (order.items.isNotEmpty && order.items[0].frameDetails?.name != null)
                  Text(
                    order.items[0].frameDetails!.name,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                if (order.items.length > 1)
                  Text(
                    '+ ${order.items.length - 1} more item${order.items.length - 1 != 1 ? 's' : ''}',
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
              ],
            ),

            const SizedBox(height: 12),

            // Total amount
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Total:',
                  style: TextStyle(fontSize: 14, color: Colors.grey),
                ),
                Text(
                  'रु ${order.totalAmount}',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF275BCD),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),
            const Divider(height: 1),

            // Action buttons
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextButton.icon(
                    onPressed: () => _viewOrderDetails(order),
                    style: TextButton.styleFrom(
                      foregroundColor: const Color(0xFF275BCD),
                    ),
                    icon: const Icon(Icons.visibility, size: 16),
                    label: const Text('Details'),
                  ),
                ),

                if (order.orderStatus.toLowerCase() == 'pending' ||
                    order.orderStatus.toLowerCase() == 'processing')
                  Expanded(
                    child: TextButton.icon(
                      onPressed: () => _cancelOrder(order.id!),
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.red,
                      ),
                      icon: const Icon(Icons.cancel, size: 16),
                      label: const Text('Cancel'),
                    ),
                  ),

              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterChips() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _buildFilterChip('All', 'all'),
          _buildFilterChip('Pending', 'pending'),
          _buildFilterChip('Processing', 'processing'),
          _buildFilterChip('Shipped', 'shipped'),
          _buildFilterChip('Delivered', 'delivered'),
          _buildFilterChip('Cancelled', 'cancelled'),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: FilterChip(
        label: Text(label),
        selected: _selectedFilter == value,
        onSelected: (selected) {
          setState(() {
            _selectedFilter = value;
          });
        },
        selectedColor: const Color(0xFF275BCD),
        checkmarkColor: Colors.white,
        labelStyle: TextStyle(
          color: _selectedFilter == value ? Colors.white : Colors.black,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final filteredOrders = _getFilteredOrders();

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text(
          'My Orders',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.black,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.black),
            onPressed: _loadOrders,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF275BCD)),
        ),
      )
          : _errorMessage.isNotEmpty
          ? Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 60, color: Colors.red),
            const SizedBox(height: 16),
            Text(
              _errorMessage,
              style: const TextStyle(color: Colors.red),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadOrders,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF275BCD),
              ),
              child: const Text('Retry'),
            ),
          ],
        ),
      )
          : Column(
        children: [
          // Filter chips
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: _buildFilterChips(),
          ),

          // Orders count
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Text(
                  '${filteredOrders.length} order${filteredOrders.length != 1 ? 's' : ''} found',
                  style: const TextStyle(
                    fontSize: 14,
                    color: Colors.grey,
                  ),
                ),
              ],
            ),
          ),

          // Orders list
          Expanded(
            child: filteredOrders.isEmpty
                ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.receipt_long,
                    size: 80,
                    color: Colors.grey,
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'No orders found',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _selectedFilter == 'all'
                        ? 'You haven\'t placed any orders yet'
                        : 'No $_selectedFilter orders',
                    style: const TextStyle(
                      fontSize: 14,
                      color: Colors.grey,
                    ),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () {
                      Navigator.pop(context); // Go back to shop
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF275BCD),
                    ),
                    child: const Text('Continue Shopping'),
                  ),
                ],
              ),
            )
                : RefreshIndicator(
              onRefresh: _loadOrders,
              color: const Color(0xFF275BCD),
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                itemCount: filteredOrders.length,
                itemBuilder: (context, index) {
                  return _buildOrderCard(filteredOrders[index]);
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}