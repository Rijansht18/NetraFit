import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../models/user_model.dart';
import '../../../services/admin_service.dart';
import '../../../models/api_response.dart';
import 'add_user_screen.dart';

class UserManagementScreen extends StatefulWidget {
  const UserManagementScreen({Key? key}) : super(key: key);

  @override
  State<UserManagementScreen> createState() => _UserManagementScreenState();
}

class _UserManagementScreenState extends State<UserManagementScreen> {
  final AdminService _adminService = AdminService();
  List<UserModel> _users = [];
  bool _isLoading = true;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadUsers();
  }

  Future<void> _loadUsers() async {
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
        _showErrorDialog(response.error ?? 'Failed to load users');
      }
    } catch (e) {
      _showErrorDialog('Network error: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _deleteUser(String userId, String username) async {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Delete User'),
          content: Text('Are you sure you want to delete user "$username"? This action cannot be undone.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () async {
                Navigator.of(context).pop();
                await _confirmDeleteUser(userId);
              },
              child: const Text('Delete', style: TextStyle(color: Colors.red)),
            ),
          ],
        );
      },
    );
  }

  Future<void> _confirmDeleteUser(String userId) async {
    try {
      final ApiResponse response = await _adminService.deleteUser(userId);
      if (response.success == true) {
        _showSuccessDialog('User deleted successfully');
        _loadUsers(); // Refresh the list
      } else {
        _showErrorDialog(response.error ?? 'Failed to delete user');
      }
    } catch (e) {
      _showErrorDialog('Network error: $e');
    }
  }

  Future<void> _updateUserRole(String userId, String currentRole) async {
    final newRole = currentRole == 'ADMIN' ? 'CUSTOMER' : 'ADMIN';

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Change User Role'),
          content: Text('Change user role from $currentRole to $newRole?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () async {
                Navigator.of(context).pop();
                await _confirmUpdateRole(userId, newRole);
              },
              child: const Text('Confirm'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _confirmUpdateRole(String userId, String newRole) async {
    try {
      final ApiResponse response = await _adminService.updateUserRole(userId, newRole);
      if (response.success == true) {
        _showSuccessDialog('User role updated successfully');
        _loadUsers(); // Refresh the list
      } else {
        _showErrorDialog(response.error ?? 'Failed to update user role');
      }
    } catch (e) {
      _showErrorDialog('Network error: $e');
    }
  }

  Future<void> _updateUserStatus(String userId, String currentStatus) async {
    final newStatus = currentStatus == 'ACTIVE' ? 'SUSPENDED' : 'ACTIVE';

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Change User Status'),
          content: Text('Change user status from ${currentStatus ?? 'ACTIVE'} to $newStatus?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () async {
                Navigator.of(context).pop();
                await _confirmUpdateStatus(userId, newStatus);
              },
              child: const Text('Confirm'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _confirmUpdateStatus(String userId, String newStatus) async {
    try {
      final ApiResponse response = await _adminService.updateUserStatus(userId, newStatus);
      if (response.success == true) {
        _showSuccessDialog('User status updated successfully');
        _loadUsers(); // Refresh the list
      } else {
        _showErrorDialog(response.error ?? 'Failed to update user status');
      }
    } catch (e) {
      _showErrorDialog('Network error: $e');
    }
  }

  Future<void> _clearUserSuspension(String userId, String username) async {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Clear Account Suspension'),
          content: Text('Clear account suspension for user "$username"?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () async {
                Navigator.of(context).pop();
                await _confirmClearSuspension(userId);
              },
              child: const Text('Clear Suspension'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _confirmClearSuspension(String userId) async {
    try {
      final ApiResponse response = await _adminService.clearUserSuspension(userId);
      if (response.success == true) {
        _showSuccessDialog('Account suspension cleared successfully');
        _loadUsers(); // Refresh the list
      } else {
        _showErrorDialog(response.error ?? 'Failed to clear account suspension');
      }
    } catch (e) {
      _showErrorDialog('Network error: $e');
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

  void _showSuccessDialog(String message) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.check_circle, color: Colors.green, size: 24),
              SizedBox(width: 8),
              Text('Success'),
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

  List<UserModel> get _filteredUsers {
    if (_searchQuery.isEmpty) return _users;
    return _users.where((user) =>
    user.username.toLowerCase().contains(_searchQuery.toLowerCase()) ||
        user.email.toLowerCase().contains(_searchQuery.toLowerCase()) ||
        user.fullname.toLowerCase().contains(_searchQuery.toLowerCase()) ||
        user.mobile.contains(_searchQuery)
    ).toList();
  }

  void _navigateToAddUser() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => AddUserScreen()),
    ).then((_) {
      // Refresh users list when returning from add user screen
      _loadUsers();
    });
  }

  String _formatDate(DateTime? date) {
    if (date == null) return 'N/A';
    return '${date.day}/${date.month}/${date.year}';
  }

  @override
  Widget build(BuildContext context) {
    final totalUsers = _filteredUsers.length;
    final adminCount = _filteredUsers.where((user) => user.isAdmin).length;
    final customerCount = totalUsers - adminCount;
    final suspendedCount = _filteredUsers.where((user) => user.isSuspended).length;
    final activeCount = totalUsers - suspendedCount;

    return Scaffold(
      appBar: AppBar(
        title: const Text('User Management'),
        backgroundColor: Color(0xFF275BCD),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadUsers,
          ),
          IconButton(
            icon: const Icon(Icons.person_add),
            onPressed: _navigateToAddUser,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _navigateToAddUser,
        backgroundColor: Color(0xFF275BCD),
        child: const Icon(Icons.person_add, color: Colors.white),
      ),
      body: Column(
        children: [
          // Search Bar
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Search users by name, email, or phone...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onChanged: (value) {
                setState(() {
                  _searchQuery = value;
                });
              },
            ),
          ),

          // Statistics Cards
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Row(
                children: [
                  _buildStatCard('Total Users', totalUsers.toString(), Icons.people, Colors.blue),
                  const SizedBox(width: 12),
                  _buildStatCard('Admins', adminCount.toString(), Icons.admin_panel_settings, Colors.orange),
                  const SizedBox(width: 12),
                  _buildStatCard('Customers', customerCount.toString(), Icons.person, Colors.green),
                  const SizedBox(width: 12),
                  _buildStatCard('Active', activeCount.toString(), Icons.check_circle, Colors.green),
                  const SizedBox(width: 12),
                  _buildStatCard('Suspended', suspendedCount.toString(), Icons.block, Colors.red),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Users List
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _filteredUsers.isEmpty
                ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.people_outline, size: 64, color: Colors.grey),
                  const SizedBox(height: 16),
                  Text(
                    _searchQuery.isEmpty
                        ? 'No users found'
                        : 'No users matching "$_searchQuery"',
                    style: const TextStyle(fontSize: 16, color: Colors.grey),
                  ),
                ],
              ),
            )
                : ListView.builder(
              itemCount: _filteredUsers.length,
              itemBuilder: (context, index) {
                final user = _filteredUsers[index];
                return _buildUserCard(user);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color) {
    return Card(
      elevation: 2,
      child: Container(
        width: 120,
        padding: const EdgeInsets.all(12),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(height: 8),
            Text(
              value,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
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

  Widget _buildUserCard(UserModel user) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      elevation: 2,
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: user.isAdmin ? Colors.orange : Color(0xFF275BCD),
          child: Text(
            user.username[0].toUpperCase(),
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
        ),
        title: Text(
          user.username,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(user.email),
            Text(user.fullname),
            const SizedBox(height: 4),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                Chip(
                  label: Text(
                    user.role,
                    style: const TextStyle(fontSize: 12, color: Colors.white),
                  ),
                  backgroundColor: user.isAdmin ? Colors.orange : Color(0xFF275BCD),
                ),
                if (user.isSuspended)
                  Chip(
                    label: const Text(
                      'SUSPENDED',
                      style: TextStyle(fontSize: 12, color: Colors.white),
                    ),
                    backgroundColor: Colors.red,
                  ),
                if (user.isAccountSuspended)
                  Chip(
                    label: const Text(
                      'LOCKED',
                      style: TextStyle(fontSize: 12, color: Colors.white),
                    ),
                    backgroundColor: Colors.deepOrange,
                  ),
                if (user.mobile.isNotEmpty)
                  Chip(
                    label: Text(
                      user.mobile,
                      style: const TextStyle(fontSize: 12),
                    ),
                    backgroundColor: Colors.grey[200],
                  ),
              ],
            ),
          ],
        ),
        trailing: PopupMenuButton<String>(
          onSelected: (value) {
            _handleMenuSelection(value, user);
          },
          itemBuilder: (context) => [
            PopupMenuItem(
              value: 'role',
              child: Row(
                children: [
                  Icon(Icons.swap_horiz, color: Colors.blue),
                  SizedBox(width: 8),
                  Text('Change Role to ${user.isAdmin ? 'Customer' : 'Admin'}'),
                ],
              ),
            ),
            PopupMenuItem(
              value: 'status',
              child: Row(
                children: [
                  Icon(user.isSuspended ? Icons.check_circle : Icons.block,
                      color: user.isSuspended ? Colors.green : Colors.red),
                  SizedBox(width: 8),
                  Text(user.isSuspended ? 'Activate User' : 'Suspend User'),
                ],
              ),
            ),
            if (user.isAccountSuspended)
              PopupMenuItem(
                value: 'clear_suspension',
                child: Row(
                  children: [
                    Icon(Icons.lock_open, color: Colors.green),
                    SizedBox(width: 8),
                    Text('Clear Suspension'),
                  ],
                ),
              ),
            PopupMenuItem(
              value: 'delete',
              child: Row(
                children: [
                  Icon(Icons.delete, color: Colors.red),
                  SizedBox(width: 8),
                  Text('Delete User'),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _handleMenuSelection(String value, UserModel user) {
    switch (value) {
      case 'role':
        _updateUserRole(user.id!, user.role);
        break;
      case 'status':
        _updateUserStatus(user.id!, user.status ?? 'ACTIVE');
        break;
      case 'clear_suspension':
        _clearUserSuspension(user.id!, user.username);
        break;
      case 'delete':
        _deleteUser(user.id!, user.username);
        break;
    }
  }
}