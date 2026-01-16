// lib/screens/admin/admin_users_screen.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:smart_parking_app/core/database/database_service.dart';
import 'package:smart_parking_app/models/user.dart';
import 'package:smart_parking_app/widgets/common/loading_indicator.dart';

class AdminUsersScreen extends StatefulWidget {
  @override
  _AdminUsersScreenState createState() => _AdminUsersScreenState();
}

class _AdminUsersScreenState extends State<AdminUsersScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Manage Users'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                labelText: 'Search Users',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _searchQuery = '');
                        },
                      )
                    : null,
              ),
              onChanged: (value) => setState(() => _searchQuery = value.toLowerCase()),
            ),
          ),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: DatabaseService.collection('users').snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) return Center(child: Text('Error: ${snapshot.error}'));
                if (!snapshot.hasData) return Center(child: LoadingIndicator());

                final users = snapshot.data!.docs.map((doc) => User.fromFirestore(doc)).where((user) {
                  return user.email.toLowerCase().contains(_searchQuery) ||
                         user.displayName.toLowerCase().contains(_searchQuery);
                }).toList();

                if (users.isEmpty) return Center(child: Text('No users found'));

                return ListView.builder(
                  itemCount: users.length,
                  itemBuilder: (context, index) {
                    final user = users[index];
                    return ListTile(
                      leading: CircleAvatar(
                        child: Text(user.displayName.isNotEmpty ? user.displayName[0].toUpperCase() : 'U'),
                      ),
                      title: Text(user.displayName),
                      subtitle: Text('${user.email}\n${user.role.name}'),
                      isThreeLine: true,
                      trailing: PopupMenuButton<String>(
                        onSelected: (value) async {
                          if (value == 'edit') {
                            // Toggle role between user and parkingOperator
                            final newRole = user.role == UserRole.user 
                                ? UserRole.parkingOperator 
                                : UserRole.user;
                            
                            // Note: This would typically require a Cloud Function or Admin SDK
                            // For this demo, we'll try updating directly if rules allow
                            try {
                              await DatabaseService.collection('users').doc(user.id).update({
                                'role': newRole.name,
                              });
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('Updated role to ${newRole.name}')),
                              );
                            } catch (e) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('Failed to update role: $e')),
                              );
                            }
                          }
                        },
                        itemBuilder: (context) => [
                          PopupMenuItem(
                            value: 'edit', 
                            child: Text(user.role == UserRole.user 
                                ? 'Promote to Operator' 
                                : 'Demote to User'),
                          ),
                          PopupMenuItem(value: 'delete', child: Text('Delete User')),
                        ],
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
