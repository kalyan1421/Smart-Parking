// lib/screens/profile/vehicles/vehicle_list_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../models/vehicle.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/vehicle_provider.dart';
import '../../../widgets/common/loading_indicator.dart';
import 'add_vehicle_screen.dart';

class VehicleListScreen extends StatefulWidget {
  @override
  _VehicleListScreenState createState() => _VehicleListScreenState();
}

class _VehicleListScreenState extends State<VehicleListScreen> {
  @override
  void initState() {
    super.initState();
    _loadVehicles();
  }

  void _loadVehicles() {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    if (authProvider.currentUser != null) {
      Provider.of<VehicleProvider>(context, listen: false)
          .loadUserVehicles(authProvider.currentUser!.id);
    }
  }

  @override
  Widget build(BuildContext context) {
    final vehicleProvider = Provider.of<VehicleProvider>(context);

    return Scaffold(
      appBar: AppBar(
        title: Text('My Vehicles'),
        actions: [
          IconButton(
            icon: Icon(Icons.add),
            onPressed: () => _navigateToAddVehicle(context),
          ),
        ],
      ),
      body: vehicleProvider.isLoading
          ? Center(child: LoadingIndicator())
          : vehicleProvider.vehicles.isEmpty
              ? _buildEmptyState()
              : ListView.builder(
                  padding: EdgeInsets.all(16),
                  itemCount: vehicleProvider.vehicles.length,
                  itemBuilder: (context, index) {
                    final vehicle = vehicleProvider.vehicles[index];
                    return _buildVehicleCard(vehicle);
                  },
                ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.directions_car, size: 80, color: Colors.grey[400]),
          SizedBox(height: 16),
          Text(
            'No vehicles added yet',
            style: TextStyle(fontSize: 18, color: Colors.grey[600]),
          ),
          SizedBox(height: 24),
          ElevatedButton(
            onPressed: () => _navigateToAddVehicle(context),
            child: Text('Add Your First Vehicle'),
          ),
        ],
      ),
    );
  }

  Widget _buildVehicleCard(Vehicle vehicle) {
    return Card(
      margin: EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 2,
      child: ListTile(
        contentPadding: EdgeInsets.all(16),
        leading: CircleAvatar(
          backgroundColor: Colors.blue[100],
          child: Icon(
            vehicle.type == VehicleType.motorcycle ? Icons.motorcycle : Icons.directions_car,
            color: Colors.blue[700],
          ),
        ),
        title: Text(
          vehicle.shortDisplayName,
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${vehicle.color} ${vehicle.typeDisplayName}'),
            if (vehicle.isDefault)
              Container(
                margin: EdgeInsets.only(top: 4),
                padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.green[100],
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  'DEFAULT',
                  style: TextStyle(color: Colors.green[800], fontSize: 10, fontWeight: FontWeight.bold),
                ),
              ),
          ],
        ),
        trailing: IconButton(
          icon: Icon(Icons.delete_outline, color: Colors.red),
          onPressed: () => _confirmDelete(vehicle),
        ),
        onTap: () => _navigateToEditVehicle(vehicle),
      ),
    );
  }

  void _navigateToAddVehicle(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => AddVehicleScreen()),
    );
  }

  void _navigateToEditVehicle(Vehicle vehicle) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => AddVehicleScreen(vehicle: vehicle)),
    );
  }

  void _confirmDelete(Vehicle vehicle) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Delete Vehicle'),
        content: Text('Are you sure you want to delete ${vehicle.licensePlate}?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text('Cancel')),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await Provider.of<VehicleProvider>(context, listen: false).deleteVehicle(vehicle.id);
            },
            child: Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}
