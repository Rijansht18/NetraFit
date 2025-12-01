// screens/admin/order_detail_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/order_model.dart';
import '../../services/order_service.dart';
import '../../providers/auth_provider.dart';
import '../../core/config/api_config.dart';

class OrderDetailScreen extends StatefulWidget {
  final Order order;

  const OrderDetailScreen({Key? key, required this.order}) : super(key: key);

  @override
  State<OrderDetailScreen> createState() => _OrderDetailScreenState();
}

class _OrderDetailScreenState extends State<OrderDetailScreen> {
  final OrderService _orderService = OrderService();
  late Order _order;
  final TextEditingController _trackingController = TextEditingController();
  bool _isUpdating = false;

  @override
  void initState() {
    super.initState();
    _order = widget.order;
    _trackingController.text = _order.trackingNumber ?? '';
  }

  @override
  void dispose() {
    _trackingController.dispose();
    super.dispose();
  }

  Future<void> _refreshOrder() async {
    try {
      final authProvider = context.read<AuthProvider>();
      final token = authProvider.token;

      final response = await _orderService.getOrderById(_order.id!, token!);

      if (response.success == true) {
        final updatedOrder = response.data?['order'] as Order?;
        if (updatedOrder != null) {
          setState(() {
            _order = updatedOrder;
            _trackingController.text = _order.trackingNumber ?? '';
          });
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(response.error ?? 'Failed to refresh order'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    } catch (e) {
      print('Error refreshing order: $e');
    }
  }

  Future<void> _updateOrderStatus(String newStatus) async {
    if (_isUpdating) return;

    setState(() {
      _isUpdating = true;
    });

    try {
      final authProvider = context.read<AuthProvider>();
      final token = authProvider.token;

      // For shipped status, include tracking number if provided
      final trackingNumber = newStatus.toLowerCase() == 'shipped'
          ? _trackingController.text.trim()
          : null;

      final response = await _orderService.updateOrderStatus(
        orderId: _order.id!,
        orderStatus: newStatus,
        trackingNumber: trackingNumber,
        token: token!,
      );

      if (response.success == true) {
        final updatedOrder = response.data?['order'] as Order?;
        if (updatedOrder != null) {
          // Update the local state immediately
          setState(() {
            _order = updatedOrder;
            _trackingController.text = _order.trackingNumber ?? '';
          });

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Order status updated to ${_order.getStatusDisplay()}'),
              backgroundColor: Colors.green,
            ),
          );
        } else {
          // If order is null in response, refresh from server
          await _refreshOrder();
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(response.error ?? 'Failed to update status'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() {
        _isUpdating = false;
      });
    }
  }

  Future<void> _updatePaymentStatus(String newStatus) async {
    if (_isUpdating) return;

    setState(() {
      _isUpdating = true;
    });

    try {
      final authProvider = context.read<AuthProvider>();
      final token = authProvider.token;

      final response = await _orderService.updatePaymentStatus(
        orderId: _order.id!,
        paymentStatus: newStatus,
        token: token!,
      );

      if (response.success == true) {
        final updatedOrder = response.data?['order'] as Order?;
        if (updatedOrder != null) {
          setState(() {
            _order = updatedOrder;
          });

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Payment status updated to ${_order.getPaymentStatusDisplay()}'),
              backgroundColor: Colors.green,
            ),
          );
        } else {
          await _refreshOrder();
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(response.error ?? 'Failed to update payment'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() {
        _isUpdating = false;
      });
    }
  }

  Future<void> _showUpdateStatusDialog(String newStatus) {
    final trackingController = TextEditingController(text: _trackingController.text);

    return showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Update to ${_getStatusText(newStatus)}?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Order #${_order.orderNumber}'),
            const SizedBox(height: 12),
            if (newStatus.toLowerCase() == 'shipped')
              Column(
                children: [
                  const Text(
                    'Tracking Information (Optional)',
                    style: TextStyle(
                      fontWeight: FontWeight.w500,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: trackingController,
                    decoration: const InputDecoration(
                      labelText: 'Tracking Number',
                      hintText: 'Enter tracking number',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ],
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
              // Update the tracking controller with new value
              if (trackingController.text.isNotEmpty) {
                _trackingController.text = trackingController.text;
              }
              _updateOrderStatus(newStatus);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: _getStatusColor(newStatus),
            ),
            child: Text('Update to ${_getStatusText(newStatus)}'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(
          title: Text('Order #${_order.orderNumber}'),
          backgroundColor: const Color(0xFF275BCD),
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: _isUpdating ? null : _refreshOrder,
            ),
          ],
        ),
        body: _isUpdating
            ? const Center(child: CircularProgressIndicator())
            : RefreshIndicator(
          onRefresh: _refreshOrder,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Order Status Card
                Card(
                  elevation: 3,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Order Status',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.grey[700],
                              ),
                            ),
                            Chip(
                              label: Text(
                                _order.getStatusDisplay(),
                                style: const TextStyle(color: Colors.white),
                              ),
                              backgroundColor: _order.getStatusColor(),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        // Status Timeline
                        _buildStatusTimeline(),
                        const SizedBox(height: 16),
                        // Next Status Actions
                        if (_order.getNextStatuses().isNotEmpty)
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: _order.getNextStatuses().map((nextStatus) {
                              return ElevatedButton.icon(
                                onPressed: _isUpdating ? null : () => _showUpdateStatusDialog(nextStatus),
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
                                ),
                              );
                            }).toList(),
                          ),
                        // Tracking Number if shipped
                        if (_order.orderStatus.toLowerCase() == 'shipped' && _order.trackingNumber != null)
                          Column(
                            children: [
                              const SizedBox(height: 16),
                              Row(
                                children: [
                                  const Icon(Icons.local_shipping, size: 20, color: Colors.purple),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        const Text(
                                          'Tracking Number:',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: Colors.grey,
                                          ),
                                        ),
                                        Text(
                                          _order.trackingNumber!,
                                          style: const TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.purple,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                // Order Details Card
                Card(
                  elevation: 3,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Order Details',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 12),
                        _buildDetailRow('Order Number', _order.orderNumber ?? 'N/A'),
                        _buildDetailRow('Order Date', _formatDate(_order.createdAt)),
                        _buildDetailRow('Total Amount', '\$${_order.totalAmount.toStringAsFixed(2)}'),
                        _buildDetailRow('Payment Method', _order.paymentMethod.replaceAll('-', ' ').toUpperCase()),
                        _buildDetailRow('Notes', _order.notes ?? 'No notes'),
                        if (_order.trackingNumber != null)
                          _buildDetailRow('Tracking Number', _order.trackingNumber!),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                // Payment Status Card
                Card(
                  elevation: 3,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Payment Status',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Chip(
                              label: Text(
                                _order.getPaymentStatusDisplay(),
                                style: const TextStyle(color: Colors.white),
                              ),
                              backgroundColor: _order.getPaymentStatusColor(),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        if (_order.paymentStatus.toLowerCase() != 'paid')
                          Wrap(
                            spacing: 8,
                            children: [
                              ElevatedButton(
                                onPressed: _isUpdating ? null : () => _updatePaymentStatus('paid'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.green,
                                ),
                                child: const Text('Mark as Paid'),
                              ),
                              if (_order.paymentStatus.toLowerCase() != 'failed')
                                OutlinedButton(
                                  onPressed: _isUpdating ? null : () => _updatePaymentStatus('failed'),
                                  style: OutlinedButton.styleFrom(
                                    side: const BorderSide(color: Colors.red),
                                  ),
                                  child: const Text(
                                    'Mark as Failed',
                                    style: TextStyle(color: Colors.red),
                                  ),
                                ),
                            ],
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                // Customer Information
                Card(
                  elevation: 3,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Customer Information',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 12),
                        if (_order.user != null) ...[
                          _buildDetailRow('Name', _order.user!.fullname ?? 'Unknown'),
                          _buildDetailRow('Email', _order.user!.email ?? 'Unknown'),
                          if (_order.user!.mobile != null)
                            _buildDetailRow('Phone', _order.user!.mobile!),
                        ],
                        const SizedBox(height: 12),
                        const Text(
                          'Shipping Address',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(_order.shippingAddress.fullName),
                        Text(_order.shippingAddress.phone),
                        Text(_order.shippingAddress.address),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                // Order Items
                Card(
                  elevation: 3,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Order Items',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 12),
                        ..._order.items.map((item) => _buildOrderItem(item)).toList(),
                        const SizedBox(height: 12),
                        Divider(color: Colors.grey[300]),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Total Amount',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              '\$${_order.totalAmount.toStringAsFixed(2)}',
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.green,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ));
    }

  Widget _buildStatusTimeline() {
    final statusOrder = ['pending', 'processing', 'shipped', 'delivered'];
    final currentStatusIndex = statusOrder.indexOf(_order.orderStatus.toLowerCase());

    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: statusOrder.map((status) {
            final index = statusOrder.indexOf(status);
            final isCompleted = index <= currentStatusIndex;
            final isCurrent = index == currentStatusIndex;

            return Column(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: isCompleted ? _getStatusColor(status) : Colors.grey[300],
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: isCompleted
                        ? Icon(
                      _getStatusIcon(status),
                      size: 16,
                      color: Colors.white,
                    )
                        : Text(
                      (index + 1).toString(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _getStatusDisplay(status),
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
                    color: isCurrent ? _getStatusColor(status) : Colors.grey,
                  ),
                ),
              ],
            );
          }).toList(),
        ),
        const SizedBox(height: 8),
        Container(
          height: 2,
          margin: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              Expanded(
                child: Container(
                  color: currentStatusIndex >= 0 ? _getStatusColor('pending') : Colors.grey[300],
                ),
              ),
              Expanded(
                child: Container(
                  color: currentStatusIndex >= 1 ? _getStatusColor('processing') : Colors.grey[300],
                ),
              ),
              Expanded(
                child: Container(
                  color: currentStatusIndex >= 2 ? _getStatusColor('shipped') : Colors.grey[300],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
        padding: const EdgeInsets.symmetric(vertical: 4.0),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 120,
              child: Text(
                '$label:',
                style: TextStyle(
                  fontWeight: FontWeight.w500,
                  color: Colors.grey[700],
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                value,
                style: const TextStyle(
                  fontWeight: FontWeight.w400,
                ),
              ),
            ),
          ],
        )
    );
  }

  Widget _buildOrderItem(OrderItem item) {
    String? imageUrl;

    // Check if frameDetails exists
    if (item.frameDetails != null && item.frameDetails!.id != null) {
      // Get the first image (index 0) for the frame
      // URL format: /frames/images/{frameId}/0
      imageUrl = '${ApiUrl.baseBackendUrl}/frames/images/${item.frameDetails!.id}/0';

      // Try to get image index from other properties if available
      if (item.frameDetails!.otherProperties != null) {
        final props = item.frameDetails!.otherProperties!;
        if (props['images'] is List && (props['images'] as List).isNotEmpty) {
          final images = props['images'] as List;
          // Check if images have indexes
          if (images.isNotEmpty) {
            // You can use different indices if needed: 0, 1, 2, etc.
            // For now, use the first image (index 0)
          }
        }
      }
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        children: [
          // Frame Image/Icon
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: Colors.grey[200],
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: imageUrl != null
                ? ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.network(
                imageUrl,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  print('Image load error for $imageUrl: $error');
                  return const Center(
                    child: Icon(Icons.photo, size: 24, color: Colors.grey),
                  );
                },
                loadingBuilder: (context, child, loadingProgress) {
                  if (loadingProgress == null) return child;
                  return Center(
                    child: CircularProgressIndicator(
                      value: loadingProgress.expectedTotalBytes != null
                          ? loadingProgress.cumulativeBytesLoaded /
                          loadingProgress.expectedTotalBytes!
                          : null,
                    ),
                  );
                },
              ),
            )
                : const Center(
              child: Icon(Icons.photo, size: 24, color: Colors.grey),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.frameDetails?.name ?? 'Unknown Frame',
                  style: const TextStyle(
                    fontWeight: FontWeight.w500,
                  ),
                ),
                if (item.frameDetails?.brand != null)
                  Text(
                    item.frameDetails!.brand!,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                    ),
                  ),
                const SizedBox(height: 4),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Quantity: ${item.quantity}',
                      style: const TextStyle(fontSize: 12),
                    ),
                    Text(
                      '\$${item.subtotal.toStringAsFixed(2)}',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                Text(
                  'Price: \$${item.price.toStringAsFixed(2)} each',
                  style: const TextStyle(
                    fontSize: 11,
                    color: Colors.grey,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year} ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
  }

  String _getStatusDisplay(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return 'Pending';
      case 'processing':
        return 'Processing';
      case 'shipped':
        return 'Shipped';
      case 'delivered':
        return 'Delivered';
      default:
        return status;
    }
  }

  IconData _getStatusIcon(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return Icons.pending;
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
        return 'Mark as Processing';
      case 'shipped':
        return 'Mark as Shipped';
      case 'delivered':
        return 'Mark as Delivered';
      case 'cancelled':
        return 'Cancel Order';
      default:
        return status;
    }
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return Colors.orange;
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