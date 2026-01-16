// lib/screens/admin/manage_parking_spots_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:smart_parking_app/config/routes.dart';
import 'package:smart_parking_app/providers/auth_provider.dart';
import 'package:smart_parking_app/providers/parking_provider.dart';
import 'package:smart_parking_app/models/parking_spot.dart';
import 'package:smart_parking_app/widgets/common/loading_indicator.dart';
import 'package:smart_parking_app/models/user.dart';

class ManageParkingSpotsScreen extends StatefulWidget {
  @override
  _ManageParkingSpotsScreenState createState() => _ManageParkingSpotsScreenState();
}

class _ManageParkingSpotsScreenState extends State<ManageParkingSpotsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadSpots();
    });
  }

  Future<void> _loadSpots() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final parkingProvider = Provider.of<ParkingProvider>(context, listen: false);
    final user = authProvider.currentUser;

    if (user != null) {
      if (user.hasRole(UserRole.admin)) {
        await parkingProvider.loadAllParkingSpots();
      } else {
        await parkingProvider.loadUserOwnedSpots(user.id);
      }
    }
  }

  void _confirmDelete(ParkingSpot spot) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Delete Parking Spot?'),
        content: Text('Are you sure you want to delete "${spot.name}"? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              final success = await Provider.of<ParkingProvider>(context, listen: false)
                  .deleteParkingSpot(spot.id);
              if (success && mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Parking spot deleted')),
                );
              }
            },
            child: Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final parkingProvider = Provider.of<ParkingProvider>(context);
    final spots = parkingProvider.allParkingSpots;

    return Scaffold(
      appBar: AppBar(
        title: Text('Manage Parking Spots'),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh),
            onPressed: _loadSpots,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.pushNamed(context, AppRoutes.adminAddEditSpot);
        },
        child: Icon(Icons.add),
        tooltip: 'Add Parking Spot',
      ),
      body: parkingProvider.isLoading
          ? Center(child: LoadingIndicator())
          : spots.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.local_parking, size: 64, color: Colors.grey),
                      SizedBox(height: 16),
                      Text(
                        'No parking spots found',
                        style: TextStyle(fontSize: 18, color: Colors.grey[600]),
                      ),
                      SizedBox(height: 8),
                      Text('Tap + to add your first spot'),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: EdgeInsets.all(16),
                  itemCount: spots.length,
                  itemBuilder: (context, index) {
                    final spot = spots[index];
                    return Card(
                      margin: EdgeInsets.only(bottom: 16),
                      elevation: 2,
                      child: ListTile(
                        title: Text(spot.name, style: TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(spot.address),
                            SizedBox(height: 4),
                            Text('Status: ${spot.status.name.toUpperCase()} • Slots: ${spot.availableSpots}/${spot.totalSpots}'),
                          ],
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: Icon(Icons.edit, color: Colors.blue),
                              onPressed: () {
                                Navigator.pushNamed(
                                  context, 
                                  AppRoutes.adminAddEditSpot,
                                  arguments: spot,
                                );
                              },
                            ),
                            IconButton(
                              icon: Icon(Icons.delete, color: Colors.red),
                              onPressed: () => _confirmDelete(spot),
                            ),
                          ],
                        ),
                        isThreeLine: true,
                      ),
                    );
                  },
                ),
    );
  }
}
