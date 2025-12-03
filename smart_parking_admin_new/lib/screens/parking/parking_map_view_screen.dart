// lib/screens/parking/parking_map_view_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'dart:async';

import '../../providers/admin_provider.dart';
import '../../models/parking_spot.dart';
import '../../config/app_config.dart';
import '../../widgets/admin_drawer.dart';
import 'add_parking_spot_screen.dart';
import 'edit_parking_spot_dialog.dart';

class ParkingMapViewScreen extends StatefulWidget {
  const ParkingMapViewScreen({super.key});

  @override
  State<ParkingMapViewScreen> createState() => _ParkingMapViewScreenState();
}

class _ParkingMapViewScreenState extends State<ParkingMapViewScreen> {
  GoogleMapController? _mapController;
  Set<Marker> _markers = {};
  ParkingSpot? _selectedParkingSpot;
  
  // Default location (San Francisco)
  static const LatLng _defaultLocation = LatLng(37.7749, -122.4194);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AdminProvider>().loadParkingSpots(refresh: true);
    });
  }

  void _onMapCreated(GoogleMapController controller) {
    _mapController = controller;
    _updateMarkers();
  }

  void _updateMarkers() {
    final adminProvider = context.read<AdminProvider>();
    final parkingSpots = adminProvider.parkingSpots;
    
    Set<Marker> markers = {};
    
    for (ParkingSpot spot in parkingSpots) {
      markers.add(
        Marker(
          markerId: MarkerId(spot.id),
          position: LatLng(spot.latitude, spot.longitude),
          icon: _getMarkerIcon(spot.status),
          infoWindow: InfoWindow(
            title: spot.name,
            snippet: '${spot.availableSpots}/${spot.totalSpots} spots • \$${spot.pricePerHour}/hr',
            onTap: () => _selectParkingSpot(spot),
          ),
          onTap: () => _selectParkingSpot(spot),
        ),
      );
    }
    
    setState(() {
      _markers = markers;
    });
  }

  BitmapDescriptor _getMarkerIcon(ParkingSpotStatus status) {
    switch (status) {
      case ParkingSpotStatus.available:
        return BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen);
      case ParkingSpotStatus.occupied:
        return BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed);
      case ParkingSpotStatus.full:
        return BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed);
      case ParkingSpotStatus.maintenance:
        return BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueOrange);
      case ParkingSpotStatus.closed:
        return BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueViolet);
      case ParkingSpotStatus.reserved:
        return BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue);
    }
  }

  void _selectParkingSpot(ParkingSpot spot) {
    setState(() {
      _selectedParkingSpot = spot;
    });
    _showParkingSpotBottomSheet(spot);
  }

  void _showParkingSpotBottomSheet(ParkingSpot spot) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.4,
        minChildSize: 0.2,
        maxChildSize: 0.8,
        expand: false,
        builder: (context, scrollController) => SingleChildScrollView(
          controller: scrollController,
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Handle bar
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                
                // Header
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            spot.name,
                            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            spot.address,
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: _getStatusColor(spot.status).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: _getStatusColor(spot.status)),
                      ),
                      child: Text(
                        spot.status.name.toUpperCase(),
                        style: TextStyle(
                          color: _getStatusColor(spot.status),
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                
                // Stats
                Row(
                  children: [
                    _buildStatChip(
                      icon: Icons.local_parking,
                      label: '${spot.availableSpots}/${spot.totalSpots}',
                      color: Colors.blue,
                    ),
                    const SizedBox(width: 12),
                    _buildStatChip(
                      icon: Icons.attach_money,
                      label: '\$${spot.pricePerHour}/hr',
                      color: Colors.green,
                    ),
                    const SizedBox(width: 12),
                    _buildStatChip(
                      icon: Icons.star,
                      label: spot.rating.toStringAsFixed(1),
                      color: Colors.orange,
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                
                // Description
                if (spot.description.isNotEmpty) ...[
                  Text(
                    'Description',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(spot.description),
                  const SizedBox(height: 16),
                ],
                
                // Amenities
                if (spot.amenities.isNotEmpty) ...[
                  Text(
                    'Amenities',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: spot.amenities.map((amenity) {
                      return Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: AppConfig.primaryColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          amenity,
                          style: TextStyle(
                            color: AppConfig.primaryColor,
                            fontSize: 12,
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 16),
                ],
                
                // Actions
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () {
                          Navigator.pop(context);
                          _showEditParkingSpotDialog(spot);
                        },
                        icon: const Icon(Icons.edit),
                        label: const Text('Edit'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppConfig.primaryColor,
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () {
                          Navigator.pop(context);
                          _deleteParkingSpot(spot);
                        },
                        icon: const Icon(Icons.delete),
                        label: const Text('Delete'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.red,
                          side: const BorderSide(color: Colors.red),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatChip({
    required IconData icon,
    required String label,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Color _getStatusColor(ParkingSpotStatus status) {
    switch (status) {
      case ParkingSpotStatus.available:
        return Colors.green;
      case ParkingSpotStatus.occupied:
        return Colors.red;
      case ParkingSpotStatus.full:
        return Colors.red;
      case ParkingSpotStatus.maintenance:
        return Colors.orange;
      case ParkingSpotStatus.closed:
        return Colors.grey;
      case ParkingSpotStatus.reserved:
        return Colors.blue;
    }
  }

  void _showAddParkingSpotDialog() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const AddParkingSpotScreen(),
      ),
    );
    
    if (result == true && mounted) {
      _updateMarkers();
    }
  }

  void _showEditParkingSpotDialog(ParkingSpot parkingSpot) {
    showDialog(
      context: context,
      builder: (context) => EditParkingSpotDialog(parkingSpot: parkingSpot),
    ).then((result) {
      if (result == true) {
        _updateMarkers();
      }
    });
  }

  void _deleteParkingSpot(ParkingSpot spot) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Parking Spot'),
        content: Text('Are you sure you want to delete "${spot.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              try {
                await context.read<AdminProvider>().deleteParkingSpot(spot.id);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Parking spot deleted successfully'),
                      backgroundColor: Colors.green,
                    ),
                  );
                  _updateMarkers();
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Error deleting parking spot: $e'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Parking Spots Map'),
        backgroundColor: AppConfig.primaryColor,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            onPressed: _showAddParkingSpotDialog,
            icon: const Icon(Icons.add_location),
            tooltip: 'Add Parking Spot',
          ),
          IconButton(
            onPressed: () {
              context.read<AdminProvider>().loadParkingSpots(refresh: true);
              _updateMarkers();
            },
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
          ),
        ],
      ),
      drawer: const AdminDrawer(),
      body: Consumer<AdminProvider>(
        builder: (context, adminProvider, child) {
          if (adminProvider.isLoading && adminProvider.parkingSpots.isEmpty) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }

          // Update markers when parking spots change
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _updateMarkers();
          });

          return Column(
            children: [
              // Legend
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child:                   Wrap(
                  alignment: WrapAlignment.spaceEvenly,
                  spacing: 16,
                  children: [
                    _buildLegendItem('Available', Colors.green),
                    _buildLegendItem('Occupied', Colors.red),
                    _buildLegendItem('Full', Colors.red),
                    _buildLegendItem('Maintenance', Colors.orange),
                    _buildLegendItem('Closed', Colors.grey),
                    _buildLegendItem('Reserved', Colors.blue),
                  ],
                ),
              ),
              
              // Map
              Expanded(
                child: GoogleMap(
                  onMapCreated: _onMapCreated,
                  initialCameraPosition: const CameraPosition(
                    target: _defaultLocation,
                    zoom: 12.0,
                  ),
                  markers: _markers,
                  myLocationEnabled: true,
                  myLocationButtonEnabled: true,
                  mapType: MapType.normal,
                  zoomControlsEnabled: true,
                  compassEnabled: true,
                  scrollGesturesEnabled: true,
                  zoomGesturesEnabled: true,
                  rotateGesturesEnabled: true,
                  tiltGesturesEnabled: false,
                ),
              ),
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddParkingSpotDialog,
        backgroundColor: AppConfig.primaryColor,
        child: const Icon(Icons.add_location, color: Colors.white),
      ),
    );
  }

  Widget _buildLegendItem(String label, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: const TextStyle(fontSize: 12),
        ),
      ],
    );
  }
}
