// lib/screens/users/user_management_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:responsive_framework/responsive_framework.dart';
import 'package:intl/intl.dart';

import '../../providers/admin_provider.dart';
import '../../providers/auth_provider.dart';
import '../../models/user.dart';
import '../../config/theme.dart';
import '../../widgets/admin_drawer.dart';

class UserManagementScreen extends StatefulWidget {
  const UserManagementScreen({super.key});

  @override
  State<UserManagementScreen> createState() => _UserManagementScreenState();
}

class _UserManagementScreenState extends State<UserManagementScreen> {
  UserRole? _roleFilter;
  final _searchController = TextEditingController();
  List<User> _searchResults = [];
  bool _isSearching = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AdminProvider>().loadUsers(refresh: true);
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = ResponsiveBreakpoints.of(context).largerThan(TABLET);
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('User Management'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              context.read<AdminProvider>().loadUsers(refresh: true);
            },
          ),
          IconButton(
            icon: const Icon(Icons.person_add),
            onPressed: () => _showCreateAdminDialog(),
          ),
        ],
      ),
      drawer: isDesktop ? null : const AdminDrawer(),
      body: Row(
        children: [
          if (isDesktop) const AdminDrawer(),
          Expanded(
            child: Column(
              children: [
                // Search and Filters
                Container(
                  padding: const EdgeInsets.all(16),
                  child: Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          Expanded(
                            flex: 2,
                            child: TextField(
                              controller: _searchController,
                              decoration: const InputDecoration(
                                hintText: 'Search by name or email...',
                                prefixIcon: Icon(Icons.search),
                              ),
                              onChanged: (value) => _performSearch(value),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: DropdownButton<UserRole?>(
                              isExpanded: true,
                              value: _roleFilter,
                              hint: const Text('Filter by Role'),
                              items: [
                                const DropdownMenuItem(
                                  value: null,
                                  child: Text('All Roles'),
                                ),
                                ...UserRole.values.map(
                                  (role) => DropdownMenuItem(
                                    value: role,
                                    child: Text(role.name.toUpperCase()),
                                  ),
                                ),
                              ],
                              onChanged: (value) {
                                setState(() {
                                  _roleFilter = value;
                                });
                                context.read<AdminProvider>().loadUsers(
                                  refresh: true,
                                  roleFilter: value,
                                );
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                
                // Users List
                Expanded(
                  child: Consumer<AdminProvider>(
                    builder: (context, adminProvider, child) {
                      final users = _isSearching ? _searchResults : adminProvider.users;
                      
                      if (adminProvider.usersLoading && users.isEmpty) {
                        return const Center(child: CircularProgressIndicator());
                      }

                      if (users.isEmpty) {
                        return Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.people,
                                size: 64,
                                color: Colors.grey[400],
                              ),
                              const SizedBox(height: 16),
                              Text(
                                _isSearching ? 'No users found' : 'No users registered yet',
                                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                                  color: Colors.grey[600],
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                _isSearching 
                                    ? 'Try adjusting your search terms'
                                    : 'Users will appear here as they register',
                                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                  color: Colors.grey[500],
                                ),
                              ),
                            ],
                          ),
                        );
                      }

                      return ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: users.length + 
                                  (!_isSearching && adminProvider.hasMoreUsers ? 1 : 0),
                        itemBuilder: (context, index) {
                          if (!_isSearching && index == users.length) {
                            // Load more button
                            return Padding(
                              padding: const EdgeInsets.all(16),
                              child: Center(
                                child: adminProvider.usersLoading
                                    ? const CircularProgressIndicator()
                                    : ElevatedButton(
                                        onPressed: () {
                                          adminProvider.loadUsers(
                                            roleFilter: _roleFilter,
                                          );
                                        },
                                        child: const Text('Load More'),
                                      ),
                              ),
                            );
                          }

                          final user = users[index];
                          return _buildUserCard(user);
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUserCard(User user) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 30,
                  backgroundImage: user.photoURL != null
                      ? NetworkImage(user.photoURL!)
                      : null,
                  backgroundColor: AppTheme.primaryColor.withOpacity(0.1),
                  child: user.photoURL == null
                      ? Text(
                          user.displayName.isNotEmpty
                              ? user.displayName[0].toUpperCase()
                              : 'U',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.primaryColor,
                          ),
                        )
                      : null,
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              user.displayName.isNotEmpty ? user.displayName : 'No Name',
                              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: AppTheme.getUserRoleColor(user.role.name)
                                  .withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: AppTheme.getUserRoleColor(user.role.name),
                              ),
                            ),
                            child: Text(
                              user.role.name.toUpperCase(),
                              style: TextStyle(
                                color: AppTheme.getUserRoleColor(user.role.name),
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        user.email,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Colors.grey[600],
                        ),
                      ),
                      if (user.phoneNumber != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          user.phoneNumber!,
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Colors.grey[500],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            
            // User Stats
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: _buildStatColumn(
                      'Vehicles',
                      user.vehicleIds.length.toString(),
                      Icons.directions_car,
                    ),
                  ),
                  Container(
                    width: 1,
                    height: 40,
                    color: Colors.grey[300],
                  ),
                  Expanded(
                    child: _buildStatColumn(
                      'Bookings',
                      user.bookingIds.length.toString(),
                      Icons.book_online,
                    ),
                  ),
                  Container(
                    width: 1,
                    height: 40,
                    color: Colors.grey[300],
                  ),
                  Expanded(
                    child: _buildStatColumn(
                      'Joined',
                      DateFormat('MMM yyyy').format(user.createdAt),
                      Icons.calendar_today,
                    ),
                  ),
                  Container(
                    width: 1,
                    height: 40,
                    color: Colors.grey[300],
                  ),
                  Expanded(
                    child: _buildStatColumn(
                      'Status',
                      user.isEmailVerified ? 'Verified' : 'Unverified',
                      user.isEmailVerified ? Icons.verified : Icons.warning,
                    ),
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 16),
            
            // Actions
            Row(
              children: [
                OutlinedButton.icon(
                  onPressed: () => _showUserDetails(user),
                  icon: const Icon(Icons.info),
                  label: const Text('Details'),
                ),
                const SizedBox(width: 8),
                Consumer<AuthProvider>(
                  builder: (context, authProvider, child) {
                    // Only admin can change roles
                    if (authProvider.isAdmin && user.id != authProvider.currentUser?.id) {
                      return OutlinedButton.icon(
                        onPressed: () => _showChangeRoleDialog(user),
                        icon: const Icon(Icons.admin_panel_settings),
                        label: const Text('Change Role'),
                      );
                    }
                    return const SizedBox.shrink();
                  },
                ),
                const Spacer(),
                PopupMenuButton<String>(
                  onSelected: (value) => _handleUserMenuAction(value, user),
                  itemBuilder: (context) => [
                    const PopupMenuItem(
                      value: 'view_bookings',
                      child: ListTile(
                        leading: Icon(Icons.book_online),
                        title: Text('View Bookings'),
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'view_vehicles',
                      child: ListTile(
                        leading: Icon(Icons.directions_car),
                        title: Text('View Vehicles'),
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                    const PopupMenuDivider(),
                    const PopupMenuItem(
                      value: 'send_notification',
                      child: ListTile(
                        leading: Icon(Icons.notifications),
                        title: Text('Send Notification'),
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatColumn(String label, String value, IconData icon) {
    return Column(
      children: [
        Icon(icon, size: 20, color: Colors.grey[600]),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey[600],
          ),
        ),
      ],
    );
  }

  Future<void> _performSearch(String query) async {
    if (query.isEmpty) {
      setState(() {
        _isSearching = false;
        _searchResults.clear();
      });
      return;
    }

    setState(() {
      _isSearching = true;
    });

    try {
      final results = await context.read<AdminProvider>().searchUsers(query);
      setState(() {
        _searchResults = results;
      });
    } catch (e) {
      // Handle error
      debugPrint('Search error: $e');
    }
  }

  void _showUserDetails(User user) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('User Details'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildDetailRow('User ID', user.id),
              _buildDetailRow('Display Name', user.displayName),
              _buildDetailRow('Email', user.email),
              if (user.phoneNumber != null) _buildDetailRow('Phone', user.phoneNumber!),
              _buildDetailRow('Role', user.role.name.toUpperCase()),
              _buildDetailRow('Email Verified', user.isEmailVerified ? 'Yes' : 'No'),
              _buildDetailRow('Phone Verified', user.isPhoneVerified ? 'Yes' : 'No'),
              _buildDetailRow('Vehicles', user.vehicleIds.length.toString()),
              _buildDetailRow('Bookings', user.bookingIds.length.toString()),
              _buildDetailRow('Created At', DateFormat('MMM dd, yyyy HH:mm').format(user.createdAt)),
              _buildDetailRow('Updated At', DateFormat('MMM dd, yyyy HH:mm').format(user.updatedAt)),
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

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              '$label:',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }

  void _showChangeRoleDialog(User user) {
    UserRole selectedRole = user.role;
    
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Text('Change User Role'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Change role for ${user.displayName} (${user.email})'),
              const SizedBox(height: 16),
              ...UserRole.values.map(
                (role) => RadioListTile<UserRole>(
                  title: Text(role.name.toUpperCase()),
                  value: role,
                  groupValue: selectedRole,
                  onChanged: (value) {
                    setState(() {
                      selectedRole = value!;
                    });
                  },
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: selectedRole != user.role
                  ? () {
                      Navigator.pop(context);
                      context.read<AuthProvider>().updateUserRole(user.id, selectedRole);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('User role updated to ${selectedRole.name}'),
                          backgroundColor: Colors.green,
                        ),
                      );
                      // Refresh users list
                      context.read<AdminProvider>().loadUsers(refresh: true);
                    }
                  : null,
              child: const Text('Update Role'),
            ),
          ],
        ),
      ),
    );
  }

  void _showCreateAdminDialog() {
    final formKey = GlobalKey<FormState>();
    final emailController = TextEditingController();
    final passwordController = TextEditingController();
    final nameController = TextEditingController();
    UserRole selectedRole = UserRole.admin;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Create Admin Account'),
          content: SingleChildScrollView(
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: nameController,
                    decoration: const InputDecoration(labelText: 'Display Name'),
                    validator: (value) => value?.isEmpty ?? true ? 'Required' : null,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: emailController,
                    decoration: const InputDecoration(labelText: 'Email'),
                    keyboardType: TextInputType.emailAddress,
                    validator: (value) {
                      if (value?.isEmpty ?? true) return 'Required';
                      if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value!)) {
                        return 'Invalid email';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: passwordController,
                    decoration: const InputDecoration(labelText: 'Password'),
                    obscureText: true,
                    validator: (value) => (value?.length ?? 0) < 6 ? 'Min 6 characters' : null,
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<UserRole>(
                    value: selectedRole,
                    decoration: const InputDecoration(labelText: 'Role'),
                    items: [UserRole.admin, UserRole.parkingOperator].map(
                      (role) => DropdownMenuItem(
                        value: role,
                        child: Text(role.name.toUpperCase()),
                      ),
                    ).toList(),
                    onChanged: (value) {
                      setState(() {
                        selectedRole = value!;
                      });
                    },
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            Consumer<AuthProvider>(
              builder: (context, authProvider, child) {
                return ElevatedButton(
                  onPressed: authProvider.isLoading
                      ? null
                      : () async {
                          if (formKey.currentState!.validate()) {
                            try {
                              await authProvider.createAdminAccount(
                                email: emailController.text.trim(),
                                password: passwordController.text,
                                displayName: nameController.text.trim(),
                                role: selectedRole,
                              );
                              if (context.mounted) {
                                Navigator.pop(context);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Admin account created successfully!'),
                                    backgroundColor: Colors.green,
                                  ),
                                );
                                // Refresh users list
                                context.read<AdminProvider>().loadUsers(refresh: true);
                              }
                            } catch (e) {
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('Error: $e'),
                                    backgroundColor: Colors.red,
                                  ),
                                );
                              }
                            }
                          }
                        },
                  child: authProvider.isLoading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Create Account'),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  void _handleUserMenuAction(String action, User user) {
    switch (action) {
      case 'view_bookings':
        // Navigate to bookings filtered by this user
        break;
      case 'view_vehicles':
        // Navigate to vehicles for this user
        break;
      case 'send_notification':
        _showSendNotificationDialog(user);
        break;
    }
  }

  void _showSendNotificationDialog(User user) {
    final titleController = TextEditingController();
    final messageController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Send Notification to ${user.displayName}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: titleController,
              decoration: const InputDecoration(labelText: 'Title'),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: messageController,
              decoration: const InputDecoration(labelText: 'Message'),
              maxLines: 3,
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
              // Implement notification sending
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Notification sent!'),
                  backgroundColor: Colors.green,
                ),
              );
            },
            child: const Text('Send'),
          ),
        ],
      ),
    );
  }
}
