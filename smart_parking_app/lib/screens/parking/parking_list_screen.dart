// lib/screens/parking/parking_list_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:smart_parking_app/providers/parking_provider.dart';
import 'package:smart_parking_app/providers/location_provider.dart';
import 'package:smart_parking_app/models/parking_spot.dart';
import 'package:smart_parking_app/widgets/common/loading_indicator.dart';
import 'package:smart_parking_app/screens/parking/parking_spot_bottom_sheet.dart';
class ParkingListScreen extends StatefulWidget {
  const ParkingListScreen({super.key});

  @override
  _ParkingListScreenState createState() => _ParkingListScreenState();
}

class _ParkingListScreenState extends State<ParkingListScreen> {
  final TextEditingController _searchController = TextEditingController();
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadAllParkingSpots();
  }

  Future<void> _loadAllParkingSpots() async {
    final locationProvider = Provider.of<LocationProvider>(context, listen: false);
    final parkingProvider = Provider.of<ParkingProvider>(context, listen: false);
    
    setState(() {
      _isLoading = true;
    });

    try {
      // Get user location first
      if (!locationProvider.hasLocation) {
        await locationProvider.getCurrentLocation();
      }

      // Initialize location in parking provider
      await parkingProvider.initializeLocation();

      // Load all parking spots from Firebase
      await parkingProvider.loadAllParkingSpots();
    } catch (e) {
      debugPrint('Error loading parking spots: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading parking spots: $e')),
        );
      }
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _searchParkingSpots(String query) async {
    if (query.isEmpty) {
      await _loadAllParkingSpots();
      return;
    }

    final parkingProvider = Provider.of<ParkingProvider>(context, listen: false);
    await parkingProvider.searchParkingSpots(query);
  }

  void _showParkingSpotDetails(ParkingSpot spot) {
    final parkingProvider = Provider.of<ParkingProvider>(context, listen: false);
    parkingProvider.selectParkingSpot(spot);
    
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => ParkingSpotBottomSheet(),
    );
  }

  String _getDistanceText(ParkingSpot spot) {
    final parkingProvider = Provider.of<ParkingProvider>(context, listen: false);
    final distance = parkingProvider.getDistanceToSpot(spot);
    
    if (distance == null) return '';
    
    if (distance < 1000) {
      return '${distance.toInt()}m away';
    } else {
      return '${(distance / 1000).toStringAsFixed(1)}km away';
    }
  }

  Color _getStatusColor(ParkingSpotStatus status) {
    switch (status) {
      case ParkingSpotStatus.available:
        return Colors.green;
      case ParkingSpotStatus.occupied:
        return Colors.red;
      case ParkingSpotStatus.maintenance:
        return Colors.orange;
      case ParkingSpotStatus.reserved:
        return Colors.blue;
    }
  }

  String _getStatusText(ParkingSpotStatus status) {
    switch (status) {
      case ParkingSpotStatus.available:
        return 'Available';
      case ParkingSpotStatus.occupied:
        return 'Occupied';
      case ParkingSpotStatus.maintenance:
        return 'Maintenance';
      case ParkingSpotStatus.reserved:
        return 'Reserved';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Parking Spots'),
        backgroundColor: Colors.blue[600],
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: Icon(Icons.refresh),
            onPressed: _loadAllParkingSpots,
          ),
        ],
      ),
      body: Column(
        children: [
          // Search Bar
          Container(
            padding: EdgeInsets.all(16),
            color: Colors.blue[600],
            child: TextField(
              controller: _searchController,
              style: TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Search parking spots...',
                hintStyle: TextStyle(color: Colors.white70),
                prefixIcon: Icon(Icons.search, color: Colors.white),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: Icon(Icons.clear, color: Colors.white),
                        onPressed: () {
                          _searchController.clear();
                          _loadAllParkingSpots();
                        },
                      )
                    : null,
                filled: true,
                fillColor: Colors.white.withValues(alpha: 0.2),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(25),
                  borderSide: BorderSide.none,
                ),
                contentPadding: EdgeInsets.symmetric(horizontal: 20, vertical: 15),
              ),
              onSubmitted: _searchParkingSpots,
            ),
          ),
          
          // Filter options can be added here in the future
          // For now, we'll use the search functionality above
          
          // Parking Spots List
          Expanded(
            child: _isLoading
                ? Center(child: LoadingIndicator())
                : Consumer<ParkingProvider>(
                    builder: (context, parkingProvider, child) {
                      if (parkingProvider.error != null) {
                        return Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.error_outline,
                                size: 64,
                                color: Colors.red,
                              ),
                              SizedBox(height: 16),
                              Text(
                                'Error loading parking spots',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              SizedBox(height: 8),
                              Text(
                                parkingProvider.error!,
                                textAlign: TextAlign.center,
                                style: TextStyle(color: Colors.grey[600]),
                              ),
                              SizedBox(height: 16),
                              ElevatedButton(
                                onPressed: _loadAllParkingSpots,
                                child: Text('Retry'),
                              ),
                            ],
                          ),
                        );
                      }

                      final parkingSpots = parkingProvider.parkingSpots;

                      if (parkingSpots.isEmpty) {
                        return Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.local_parking,
                                size: 64,
                                color: Colors.grey,
                              ),
                              SizedBox(height: 16),
                              Text(
                                'No parking spots found',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              SizedBox(height: 8),
                              Text(
                                'Try adjusting your filters or search terms',
                                style: TextStyle(color: Colors.grey[600]),
                              ),
                            ],
                          ),
                        );
                      }

                      return RefreshIndicator(
                        onRefresh: _loadAllParkingSpots,
                        child: ListView.builder(
                          padding: EdgeInsets.all(16),
                          itemCount: parkingSpots.length,
                          itemBuilder: (context, index) {
                            final spot = parkingSpots[index];
                            return _buildParkingSpotCard(spot);
                          },
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildParkingSpotCard(ParkingSpot spot) {
    return Card(
      margin: EdgeInsets.only(bottom: 16),
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        onTap: () => _showParkingSpotDetails(spot),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header with name and status
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          spot.name,
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        if (spot.address.isNotEmpty) ...[
                          SizedBox(height: 4),
                          Text(
                            spot.address,
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: _getStatusColor(spot.status),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      _getStatusText(spot.status),
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              
              SizedBox(height: 12),
              
              // Description
              if (spot.description.isNotEmpty) ...[
                Text(
                  spot.description,
                  style: TextStyle(
                    color: Colors.grey[700],
                    fontSize: 14,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                SizedBox(height: 12),
              ],
              
              // Availability and Price
              Row(
                children: [
                  Icon(Icons.local_parking, color: Colors.blue, size: 20),
                  SizedBox(width: 8),
                  Text(
                    '${spot.availableSpots}/${spot.totalSpots} available',
                    style: TextStyle(
                      fontWeight: FontWeight.w500,
                      color: spot.availableSpots > 0 ? Colors.green : Colors.red,
                    ),
                  ),
                  Spacer(),
                  if (spot.pricePerHour > 0) ...[
                    Icon(Icons.currency_rupee, color: Colors.green, size: 20),
                    SizedBox(width: 4),
                    Text(
                      '₹${spot.pricePerHour.toStringAsFixed(0)}/hr',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.green,
                        fontSize: 16,
                      ),
                    ),
                  ] else ...[
                    Text(
                      'FREE',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.green,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ],
              ),
              
              SizedBox(height: 12),
              
              // Additional info
              Row(
                children: [
                  // Distance
                  if (_getDistanceText(spot).isNotEmpty) ...[
                    Icon(Icons.location_on, color: Colors.grey, size: 16),
                    SizedBox(width: 4),
                    Text(
                      _getDistanceText(spot),
                      style: TextStyle(color: Colors.grey[600], fontSize: 12),
                    ),
                    SizedBox(width: 16),
                  ],
                  
                  // Rating
                  if (spot.rating > 0) ...[
                    Icon(Icons.star, color: Colors.amber, size: 16),
                    SizedBox(width: 4),
                    Text(
                      '${spot.rating.toStringAsFixed(1)} (${spot.reviewCount})',
                      style: TextStyle(color: Colors.grey[600], fontSize: 12),
                    ),
                    SizedBox(width: 16),
                  ],
                  
                  // Verified badge
                  if (spot.isVerified) ...[
                    Icon(Icons.verified, color: Colors.blue, size: 16),
                    SizedBox(width: 4),
                    Text(
                      'Verified',
                      style: TextStyle(color: Colors.blue, fontSize: 12),
                    ),
                  ],
                ],
              ),
              
              // Vehicle types
              if (spot.vehicleTypes.isNotEmpty) ...[
                SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: spot.vehicleTypes.map((type) {
                    return Container(
                      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.grey[200],
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        type.toUpperCase(),
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey[700],
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }
}
