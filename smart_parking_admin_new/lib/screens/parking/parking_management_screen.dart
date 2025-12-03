// lib/screens/parking/parking_management_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:responsive_framework/responsive_framework.dart';

import '../../providers/admin_provider.dart';
import '../../models/parking_spot.dart';
import '../../config/theme.dart';
import '../../widgets/admin_drawer.dart';
import 'add_parking_spot_screen.dart';
import 'edit_parking_spot_dialog.dart';

class ParkingManagementScreen extends StatefulWidget {
  const ParkingManagementScreen({super.key});

  @override
  State<ParkingManagementScreen> createState() => _ParkingManagementScreenState();
}

class _ParkingManagementScreenState extends State<ParkingManagementScreen> {
  ParkingSpotStatus? _statusFilter;
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AdminProvider>().loadParkingSpots(refresh: true);
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
        title: const Text('Parking Management'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              context.read<AdminProvider>().loadParkingSpots(refresh: true);
            },
          ),
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => _showAddParkingSpotDialog(),
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
                // Filters
                Container(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _searchController,
                          decoration: const InputDecoration(
                            hintText: 'Search parking spots...',
                            prefixIcon: Icon(Icons.search),
                          ),
                          onChanged: (value) {
                            // Implement search functionality
                          },
                        ),
                      ),
                      const SizedBox(width: 16),
                      DropdownButton<ParkingSpotStatus?>(
                        value: _statusFilter,
                        hint: const Text('Filter by Status'),
                        items: [
                          const DropdownMenuItem(
                            value: null,
                            child: Text('All Statuses'),
                          ),
                          ...ParkingSpotStatus.values.map(
                            (status) => DropdownMenuItem(
                              value: status,
                              child: Text(status.name.toUpperCase()),
                            ),
                          ),
                        ],
                        onChanged: (value) {
                          setState(() {
                            _statusFilter = value;
                          });
                          context.read<AdminProvider>().loadParkingSpots(
                            refresh: true,
                            statusFilter: value,
                          );
                        },
                      ),
                    ],
                  ),
                ),
                
                // Parking Spots List
                Expanded(
                  child: Consumer<AdminProvider>(
                    builder: (context, adminProvider, child) {
                      if (adminProvider.parkingSpotsLoading && adminProvider.parkingSpots.isEmpty) {
                        return const Center(child: CircularProgressIndicator());
                      }

                      if (adminProvider.parkingSpots.isEmpty) {
                        return Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.local_parking,
                                size: 64,
                                color: Colors.grey[400],
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'No parking spots found',
                                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                                  color: Colors.grey[600],
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Add your first parking spot to get started',
                                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                  color: Colors.grey[500],
                                ),
                              ),
                              const SizedBox(height: 24),
                              ElevatedButton.icon(
                                onPressed: () => _showAddParkingSpotDialog(),
                                icon: const Icon(Icons.add),
                                label: const Text('Add Parking Spot'),
                              ),
                            ],
                          ),
                        );
                      }

                      return ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: adminProvider.parkingSpots.length + 
                                  (adminProvider.hasMoreParkingSpots ? 1 : 0),
                        itemBuilder: (context, index) {
                          if (index == adminProvider.parkingSpots.length) {
                            // Load more button
                            return Padding(
                              padding: const EdgeInsets.all(16),
                              child: Center(
                                child: adminProvider.parkingSpotsLoading
                                    ? const CircularProgressIndicator()
                                    : ElevatedButton(
                                        onPressed: () {
                                          adminProvider.loadParkingSpots(
                                            statusFilter: _statusFilter,
                                          );
                                        },
                                        child: const Text('Load More'),
                                      ),
                              ),
                            );
                          }

                          final parkingSpot = adminProvider.parkingSpots[index];
                          return _buildParkingSpotCard(parkingSpot);
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

  Widget _buildParkingSpotCard(ParkingSpot parkingSpot) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              parkingSpot.name,
                              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: AppTheme.getParkingSpotStatusColor(parkingSpot.status.name)
                                  .withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: AppTheme.getParkingSpotStatusColor(parkingSpot.status.name),
                              ),
                            ),
                            child: Text(
                              parkingSpot.status.name.toUpperCase(),
                              style: TextStyle(
                                color: AppTheme.getParkingSpotStatusColor(parkingSpot.status.name),
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          if (parkingSpot.isVerified)
                            Container(
                              margin: const EdgeInsets.only(left: 8),
                              padding: const EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                color: AppTheme.successColor.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Icon(
                                Icons.verified,
                                color: AppTheme.successColor,
                                size: 16,
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        parkingSpot.address,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Colors.grey[600],
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        parkingSpot.description,
                        style: Theme.of(context).textTheme.bodyMedium,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            
            // Stats Row
            Row(
              children: [
                _buildStatChip(
                  Icons.local_parking,
                  '${parkingSpot.availableSpots}/${parkingSpot.totalSpots}',
                  'Available',
                ),
                const SizedBox(width: 12),
                _buildStatChip(
                  Icons.attach_money,
                  '\$${parkingSpot.pricePerHour.toStringAsFixed(2)}/hr',
                  'Price',
                ),
                const SizedBox(width: 12),
                _buildStatChip(
                  Icons.star,
                  parkingSpot.rating.toStringAsFixed(1),
                  'Rating',
                ),
              ],
            ),
            
            const SizedBox(height: 16),
            
            // Actions
            Row(
              children: [
                OutlinedButton.icon(
                  onPressed: () => _showEditParkingSpotDialog(parkingSpot),
                  icon: const Icon(Icons.edit),
                  label: const Text('Edit'),
                ),
                const SizedBox(width: 8),
                OutlinedButton.icon(
                  onPressed: () => _toggleVerification(parkingSpot),
                  icon: Icon(parkingSpot.isVerified ? Icons.verified : Icons.verified_outlined),
                  label: Text(parkingSpot.isVerified ? 'Verified' : 'Verify'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: parkingSpot.isVerified 
                        ? AppTheme.successColor 
                        : AppTheme.warningColor,
                    side: BorderSide(
                      color: parkingSpot.isVerified 
                          ? AppTheme.successColor 
                          : AppTheme.warningColor,
                    ),
                  ),
                ),
                const Spacer(),
                PopupMenuButton<String>(
                  onSelected: (value) => _handleMenuAction(value, parkingSpot),
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
                      value: 'view_revenue',
                      child: ListTile(
                        leading: Icon(Icons.analytics),
                        title: Text('View Revenue'),
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                    const PopupMenuDivider(),
                    const PopupMenuItem(
                      value: 'delete',
                      child: ListTile(
                        leading: Icon(Icons.delete, color: Colors.red),
                        title: Text('Delete', style: TextStyle(color: Colors.red)),
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

  Widget _buildStatChip(IconData icon, String value, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: Colors.grey[600]),
          const SizedBox(width: 4),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                value,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                label,
                style: TextStyle(
                  fontSize: 10,
                  color: Colors.grey[600],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showAddParkingSpotDialog() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const AddParkingSpotScreen(),
      ),
    );
    
    if (result == true && mounted) {
      // Refresh the list after adding
      context.read<AdminProvider>().loadParkingSpots(refresh: true);
    }
  }

  void _showEditParkingSpotDialog(ParkingSpot parkingSpot) {
    showDialog(
      context: context,
      builder: (context) => EditParkingSpotDialog(parkingSpot: parkingSpot),
    );
  }

  void _toggleVerification(ParkingSpot parkingSpot) {
    context.read<AdminProvider>().verifyParkingSpot(
      parkingSpot.id,
      !parkingSpot.isVerified,
    );
  }

  void _handleMenuAction(String action, ParkingSpot parkingSpot) {
    switch (action) {
      case 'view_bookings':
        // Navigate to bookings filtered by this parking spot
        break;
      case 'view_revenue':
        // Navigate to revenue analytics for this parking spot
        break;
      case 'delete':
        _showDeleteConfirmation(parkingSpot);
        break;
    }
  }

  void _showDeleteConfirmation(ParkingSpot parkingSpot) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Parking Spot'),
        content: Text(
          'Are you sure you want to delete "${parkingSpot.name}"? This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              context.read<AdminProvider>().deleteParkingSpot(parkingSpot.id);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}
