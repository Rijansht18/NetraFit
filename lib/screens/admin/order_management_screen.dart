// screens/admin/order_management_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/order_model.dart';
import '../../services/order_service.dart';
import '../../providers/auth_provider.dart';
import 'order_detail_screen.dart'; // We'll create this next

class OrderManagementScreen extends StatefulWidget {
  const OrderManagementScreen({Key? key}) : super(key: key);

  @override
  State<OrderManagementScreen> createState() => _OrderManagementScreenState();
}

class _OrderManagementScreenState extends State<OrderManagementScreen> {
  final OrderService _orderService = OrderService();
  List<Order> _orders = [];
  List<Order> _filteredOrders = [];
  bool _isLoading = true;
  String _selectedFilter = 'all';
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadOrders();
  }

  Future<void> _loadOrders() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final authProvider = context.read<AuthProvider>();
      final token = authProvider.token;

      final response = await _orderService.getAllOrders(token: token);

      if (response.success == true) {
        setState(() {
          _orders = (response.data?['orders'] as List<Order>?) ?? [];
          _filteredOrders = _orders;
        });
      } else {
        _showErrorSnackbar(response.error ?? 'Failed to load orders');
      }
    } catch (e) {
      _showErrorSnackbar('Error: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _filterOrders() {
    final searchTerm = _searchController.text.toLowerCase();

    setState(() {
      _filteredOrders = _orders.where((order) {
        final matchesSearch = searchTerm.isEmpty ||
            order.orderNumber?.toLowerCase().contains(searchTerm) == true ||
            order.user?.fullname?.toLowerCase().contains(searchTerm) == true ||
            order.user?.email?.toLowerCase().contains(searchTerm) == true;

        final matchesFilter = _selectedFilter == 'all' ||
            order.orderStatus.toLowerCase() == _selectedFilter.toLowerCase();

        return matchesSearch && matchesFilter;
      }).toList();
    });
  }

  void _showErrorSnackbar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }

  void _showSuccessSnackbar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
      ),
    );
  }

  // In order_management_screen.dart, update the _updateOrderStatus method:
  Future<void> _updateOrderStatus(Order order, String newStatus) async {
    if (_isLoading) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final authProvider = context.read<AuthProvider>();
      final token = authProvider.token;

      final response = await _orderService.updateOrderStatus(
        orderId: order.id!,
        orderStatus: newStatus,
        token: token!,
      );

      if (response.success == true) {
        _showSuccessSnackbar('Order status updated to $newStatus');
        await _loadOrders(); // Refresh the list
      } else {
        _showErrorSnackbar(response.error ?? 'Failed to update status');
      }
    } catch (e) {
      _showErrorSnackbar('Error: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Order Management'),
        backgroundColor: const Color(0xFF275BCD),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadOrders,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
        children: [
          // Search and Filter Bar
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                // Search Bar
                TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Search by order number, name, email...',
                    prefixIcon: const Icon(Icons.search),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    suffixIcon: _searchController.text.isNotEmpty
                        ? IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () {
                        _searchController.clear();
                        _filterOrders();
                      },
                    )
                        : null,
                  ),
                  onChanged: (_) => _filterOrders(),
                ),
                const SizedBox(height: 12),
                // Filter Chips
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      FilterChip(
                        label: const Text('All'),
                        selected: _selectedFilter == 'all',
                        onSelected: (_) {
                          setState(() {
                            _selectedFilter = 'all';
                            _filterOrders();
                          });
                        },
                      ),
                      const SizedBox(width: 8),
                      FilterChip(
                        label: const Text('Pending'),
                        selected: _selectedFilter == 'pending',
                        backgroundColor: Colors.orange.withOpacity(0.1),
                        selectedColor: Colors.orange,
                        labelStyle: TextStyle(
                          color: _selectedFilter == 'pending' ? Colors.white : Colors.orange,
                        ),
                        onSelected: (_) {
                          setState(() {
                            _selectedFilter = 'pending';
                            _filterOrders();
                          });
                        },
                      ),
                      const SizedBox(width: 8),
                      FilterChip(
                        label: const Text('Processing'),
                        selected: _selectedFilter == 'processing',
                        backgroundColor: Colors.blue.withOpacity(0.1),
                        selectedColor: Colors.blue,
                        labelStyle: TextStyle(
                          color: _selectedFilter == 'processing' ? Colors.white : Colors.blue,
                        ),
                        onSelected: (_) {
                          setState(() {
                            _selectedFilter = 'processing';
                            _filterOrders();
                          });
                        },
                      ),
                      const SizedBox(width: 8),
                      FilterChip(
                        label: const Text('Shipped'),
                        selected: _selectedFilter == 'shipped',
                        backgroundColor: Colors.purple.withOpacity(0.1),
                        selectedColor: Colors.purple,
                        labelStyle: TextStyle(
                          color: _selectedFilter == 'shipped' ? Colors.white : Colors.purple,
                        ),
                        onSelected: (_) {
                          setState(() {
                            _selectedFilter = 'shipped';
                            _filterOrders();
                          });
                        },
                      ),
                      const SizedBox(width: 8),
                      FilterChip(
                        label: const Text('Delivered'),
                        selected: _selectedFilter == 'delivered',
                        backgroundColor: Colors.green.withOpacity(0.1),
                        selectedColor: Colors.green,
                        labelStyle: TextStyle(
                          color: _selectedFilter == 'delivered' ? Colors.white : Colors.green,
                        ),
                        onSelected: (_) {
                          setState(() {
                            _selectedFilter = 'delivered';
                            _filterOrders();
                          });
                        },
                      ),
                      const SizedBox(width: 8),
                      FilterChip(
                        label: const Text('Cancelled'),
                        selected: _selectedFilter == 'cancelled',
                        backgroundColor: Colors.red.withOpacity(0.1),
                        selectedColor: Colors.red,
                        labelStyle: TextStyle(
                          color: _selectedFilter == 'cancelled' ? Colors.white : Colors.red,
                        ),
                        onSelected: (_) {
                          setState(() {
                            _selectedFilter = 'cancelled';
                            _filterOrders();
                          });
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          // Orders Count
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Total Orders: ${_filteredOrders.length}',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.grey,
                  ),
                ),
                if (_selectedFilter != 'all')
                  Text(
                    'Filter: ${_selectedFilter.toUpperCase()}',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: _filteredOrders.isNotEmpty ? _filteredOrders.first.getStatusColor() : Colors.grey,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          // Orders List
          Expanded(
            child: _filteredOrders.isEmpty
                ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.shopping_cart_outlined,
                    size: 64,
                    color: Colors.grey[300],
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'No orders found',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey,
                    ),
                  ),
                  if (_selectedFilter != 'all')
                    TextButton(
                      onPressed: () {
                        setState(() {
                          _selectedFilter = 'all';
                          _filterOrders();
                        });
                      },
                      child: const Text('Clear filter'),
                    ),
                ],
              ),
            )
                : RefreshIndicator(
              onRefresh: _loadOrders,
              child: ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: _filteredOrders.length,
                separatorBuilder: (context, index) => const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  final order = _filteredOrders[index];
                  return _buildOrderCard(order);
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOrderCard(Order order) {
    final nextStatuses = order.getNextStatuses();
    final showCancelButton = !['cancelled', 'delivered'].contains(order.orderStatus.toLowerCase());

    return Card(
      elevation: 3,
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => OrderDetailScreen(order: order),
            ),
          ).then((_) => _loadOrders()); // Refresh when returning
        },
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Order Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Order #${order.orderNumber ?? 'N/A'}',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        order.user?.fullname ?? 'Unknown User',
                        style: const TextStyle(
                          fontSize: 14,
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  ),
                  Chip(
                    label: Text(
                      order.getStatusDisplay(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                      ),
                    ),
                    backgroundColor: order.getStatusColor(),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              // Order Details
              Row(
                children: [
                  Icon(Icons.calendar_today, size: 16, color: Colors.grey[600]),
                  const SizedBox(width: 8),
                  Text(
                    _formatDate(order.createdAt),
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                    ),
                  ),
                  const SizedBox(width: 16),
                  Icon(Icons.attach_money, size: 16, color: Colors.grey[600]),
                  const SizedBox(width: 8),
                  Text(
                    '\$${order.totalAmount.toStringAsFixed(2)}',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              // Payment Status
              Row(
                children: [
                  Icon(Icons.payment, size: 16, color: Colors.grey[600]),
                  const SizedBox(width: 8),
                  Text(
                    'Payment: ${order.getPaymentStatusDisplay()}',
                    style: TextStyle(
                      fontSize: 12,
                      color: order.getPaymentStatusColor(),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              // Items Summary
              if (order.items.isNotEmpty)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Items (${order.items.length}):',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Wrap(
                      spacing: 8,
                      children: order.items.take(3).map((item) {
                        return Chip(
                          label: Text(
                            '${item.frameDetails?.name ?? 'Item'} x${item.quantity}',
                            style: const TextStyle(fontSize: 11),
                          ),
                          backgroundColor: Colors.grey[100],
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                        );
                      }).toList(),
                    ),
                    if (order.items.length > 3)
                      Padding(
                        padding: const EdgeInsets.only(top: 4.0),
                        child: Text(
                          '+ ${order.items.length - 3} more items',
                          style: const TextStyle(
                            fontSize: 11,
                            color: Colors.grey,
                          ),
                        ),
                      ),
                  ],
                ),
              const SizedBox(height: 12),
              // Quick Actions - Only show if not cancelled/delivered
              if (order.orderStatus.toLowerCase() != 'cancelled' &&
                  order.orderStatus.toLowerCase() != 'delivered')
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Show next status options
                    if (nextStatuses.isNotEmpty)
                      Wrap(
                        spacing: 8,
                        children: nextStatuses.map((nextStatus) {
                          // Skip "cancelled" here - we'll show cancel button separately
                          if (nextStatus == 'cancelled') return const SizedBox.shrink();

                          return ElevatedButton.icon(
                            onPressed: () {
                              _showUpdateStatusDialog(order, nextStatus);
                            },
                            icon: Icon(
                              _getStatusIcon(nextStatus),
                              size: 16,
                            ),
                            label: Text(
                              _getStatusText(nextStatus),
                              style: const TextStyle(fontSize: 12),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _getStatusColor(nextStatus),
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            ),
                          );
                        }).toList(),
                      ),
                    // Single Cancel button
                    if (showCancelButton)
                      OutlinedButton(
                        onPressed: () {
                          _showCancelOrderDialog(order);
                        },
                        style: OutlinedButton.styleFrom(
                          side: BorderSide(color: Colors.red.shade300),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        ),
                        child: const Text(
                          'Cancel',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.red,
                          ),
                        ),
                      ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }

  void _showUpdateStatusDialog(Order order, String nextStatus) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Update to ${_getStatusText(nextStatus)}?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Order #${order.orderNumber}'),
            const SizedBox(height: 8),
            if (nextStatus == 'shipped')
              TextField(
                decoration: const InputDecoration(
                  labelText: 'Tracking Number (Optional)',
                  hintText: 'Enter tracking number',
                  border: OutlineInputBorder(),
                ),
                onChanged: (value) {
                  // You can store this value and pass it to the API
                },
              ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _updateOrderStatus(order, nextStatus);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: _getStatusColor(nextStatus),
            ),
            child: Text('Update to ${_getStatusText(nextStatus)}'),
          ),
        ],
      ),
    );
  }

  void _showCancelOrderDialog(Order order) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cancel Order?'),
        content: Text('Are you sure you want to cancel order #${order.orderNumber}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('No'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              try {
                final authProvider = context.read<AuthProvider>();
                final token = authProvider.token;

                final response = await _orderService.cancelOrder(order.id!, token!);

                if (response.success == true) {
                  _showSuccessSnackbar('Order cancelled successfully');
                  await _loadOrders();
                } else {
                  _showErrorSnackbar(response.error ?? 'Failed to cancel order');
                }
              } catch (e) {
                _showErrorSnackbar('Error: $e');
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
            ),
            child: const Text('Yes, Cancel'),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }

  IconData _getStatusIcon(String status) {
    switch (status.toLowerCase()) {
      case 'processing':
        return Icons.settings;
      case 'shipped':
        return Icons.local_shipping;
      case 'delivered':
        return Icons.check_circle;
      case 'cancelled':
        return Icons.cancel;
      default:
        return Icons.question_mark;
    }
  }

  String _getStatusText(String status) {
    switch (status.toLowerCase()) {
      case 'processing':
        return 'Process';
      case 'shipped':
        return 'Ship';
      case 'delivered':
        return 'Deliver';
      case 'cancelled':
        return 'Cancel';
      default:
        return status;
    }
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'processing':
        return Colors.blue;
      case 'shipped':
        return Colors.purple;
      case 'delivered':
        return Colors.green;
      case 'cancelled':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }
}