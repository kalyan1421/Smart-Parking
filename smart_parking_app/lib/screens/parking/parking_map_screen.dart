// lib/screens/parking/parking_map_screen.dart
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:provider/provider.dart';
import 'package:smart_parking_app/config/app_config.dart';
import 'package:smart_parking_app/providers/location_provider.dart';
import 'package:smart_parking_app/providers/parking_provider.dart';
import 'package:smart_parking_app/providers/traffic_provider.dart';
import 'package:smart_parking_app/models/parking_spot.dart';
import 'package:smart_parking_app/screens/parking/parking_spot_bottom_sheet.dart';
import 'package:smart_parking_app/widgets/common/loading_indicator.dart';
import 'package:smart_parking_app/screens/parking/filter_bar.dart';
import 'package:smart_parking_app/screens/parking/add_parking_spot_dialog.dart';
import 'package:smart_parking_app/providers/auth_provider.dart';
import 'package:smart_parking_app/services/partner_request_service.dart';

class ParkingMapScreen extends StatefulWidget {
  const ParkingMapScreen({super.key});

  @override
  _ParkingMapScreenState createState() => _ParkingMapScreenState();
}

class _ParkingMapScreenState extends State<ParkingMapScreen> {
  GoogleMapController? _mapController;
  Set<Marker> _markers = {};
  
  @override
  void initState() {
    super.initState();
    
    // Initialize traffic overlay safely
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final trafficProvider = Provider.of<TrafficProvider>(context, listen: false);
      trafficProvider.initializeTrafficOverlay();
      _loadParkingSpots();
    });
  }
  
  Future<void> _loadParkingSpots() async {
    final locationProvider = Provider.of<LocationProvider>(context, listen: false);
    final parkingProvider = Provider.of<ParkingProvider>(context, listen: false);
    
    // Wait for location
    if (!locationProvider.hasLocation) {
      await locationProvider.getCurrentLocation();
    }
    
    // Get user location - using the separate latitude and longitude properties
    final userLatitude = locationProvider.currentLocation?.latitude ?? 0;
    final userLongitude = locationProvider.currentLocation?.longitude ?? 0;
    
    // Find parking spots - passing separate latitude and longitude
    await parkingProvider.findNearbyParkingSpots(
      userLatitude, 
      userLongitude,
      radius: AppConfig.defaultSearchRadius
    );
    
    // Update markers after loading spots
    if (mounted) {
      _updateMarkers();
      
      // Move map to user location
      if (_mapController != null) {
        _mapController!.animateCamera(CameraUpdate.newLatLngZoom(
          LatLng(userLatitude, userLongitude), 14.0
        ));
      }
    }
  }
  
  void _updateMarkers() {
    if (!mounted) return;
    
    final parkingProvider = Provider.of<ParkingProvider>(context, listen: false);
    final spots = parkingProvider.nearbyParkingSpots;
    
    print('🧩 Updating markers: ${spots.length} parking spots found');
    
    Set<Marker> markers = {};
    
    // Create marker for each parking spot with enhanced info
    for (final spot in spots) {
      // Determine marker color based on availability
      double hue;
      if (spot.availableSpots == 0) {
        hue = BitmapDescriptor.hueRed; // Red for no spots
      } else if (spot.availableSpots <= 2) {
        hue = BitmapDescriptor.hueOrange; // Orange for low availability
      } else if (spot.availableSpots <= 5) {
        hue = BitmapDescriptor.hueYellow; // Yellow for medium availability
      } else {
        hue = BitmapDescriptor.hueGreen; // Green for high availability
      }
      
      markers.add(Marker(
        markerId: MarkerId(spot.id),
        position: LatLng(spot.latitude, spot.longitude),
        infoWindow: InfoWindow(
          title: '${spot.name} - ${spot.availableSpots} Available',
          snippet: '${spot.availableSpots} of ${spot.totalSpots} spots free • ${AppConfig.currencySymbol}${spot.pricePerHour.toStringAsFixed(2)}/hr',
        ),
        icon: BitmapDescriptor.defaultMarkerWithHue(hue),
        onTap: () => _onMarkerTapped(spot),
      ));
      
      print('🧩 Added marker for: ${spot.name} at (${spot.latitude}, ${spot.longitude})');
    }
    
    // Create marker for user location
    final locationProvider = Provider.of<LocationProvider>(context, listen: false);
    if (locationProvider.hasLocation) {
      markers.add(Marker(
        markerId: MarkerId('user_location'),
        position: LatLng(
          locationProvider.currentLocation!.latitude,
          locationProvider.currentLocation!.longitude
        ),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
        infoWindow: InfoWindow(
          title: 'Your Location',
        ),
      ));
    }
    
    if (mounted) {
      setState(() {
        _markers = markers;
      });
      print('🧩 Markers updated: ${_markers.length} total markers');
    }
  }
  
  void _onMarkerTapped(ParkingSpot spot) {
    final parkingProvider = Provider.of<ParkingProvider>(context, listen: false);
    parkingProvider.selectParkingSpot(spot);
    
    // Show bottom sheet with details
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => ParkingSpotBottomSheet(),
    );
  }
  
  // Parking spot addition is handled by approved QuickPark partners only
  
  Future<void> _showAddParkingSpotDialog() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    
    // Check if user is an approved partner
    if (authProvider.currentUser == null || !authProvider.currentUser!.isPartnerApproved) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Only approved QuickPark partners can add parking spots.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final result = await showDialog(
      context: context,
      builder: (context) => AddParkingSpotDialog(),
    );

    if (result == true) {
      // Refresh parking spots after adding
      _loadParkingSpots();
    }
  }

  @override
  Widget build(BuildContext context) {
    final locationProvider = Provider.of<LocationProvider>(context);
    final parkingProvider = Provider.of<ParkingProvider>(context);
    final trafficProvider = Provider.of<TrafficProvider>(context);
    final authProvider = Provider.of<AuthProvider>(context);
    
    // Ensure traffic overlay is set up (without notifying)
    if (!trafficProvider.isOverlaySetup) {
      trafficProvider.setupTrafficOverlay();
    }
    
    // Prepare tile overlays
    Set<TileOverlay> tileOverlays = {};
    if (trafficProvider.isOverlaySetup && 
        trafficProvider.trafficOverlay != null &&
        trafficProvider.showTrafficLayer) {
      tileOverlays = {trafficProvider.trafficOverlay!};
    }
    
    // Default camera position (will be updated with user's location)
    final initialCameraPosition = CameraPosition(
      target: LatLng(
        locationProvider.currentLocation?.latitude ?? 0,
        locationProvider.currentLocation?.longitude ?? 0
      ),
      zoom: 13.0,
    );
    
    // Check if user is an approved partner
    final isPartner = authProvider.currentUser?.isPartnerApproved ?? false;
    
    return Scaffold(
      appBar: AppBar(
        title: Text('Find Parking'),
        actions: [
          // Add Parking Spot button (only for approved partners)
          if (isPartner)
            IconButton(
              icon: Icon(Icons.add_location),
              onPressed: _showAddParkingSpotDialog,
              tooltip: 'Add Parking Spot',
            ),
          // Traffic toggle button
          IconButton(
            icon: Icon(
              trafficProvider.showTrafficLayer ? Icons.traffic : Icons.traffic_outlined,
              color: trafficProvider.showTrafficLayer ? Colors.amber : null,
            ),
            tooltip: 'Toggle traffic',
            onPressed: () {
              trafficProvider.toggleTrafficLayer();
            },
          ),
          IconButton(
            icon: Icon(Icons.refresh),
            onPressed: _loadParkingSpots,
            tooltip: 'Refresh',
          ),
          IconButton(
            icon: Icon(Icons.my_location),
            onPressed: () {
              if (locationProvider.hasLocation && _mapController != null) {
                _mapController!.animateCamera(CameraUpdate.newLatLngZoom(
                  LatLng(
                    locationProvider.currentLocation!.latitude,
                    locationProvider.currentLocation!.longitude
                  ), 
                  15.0
                ));
              }
            },
            tooltip: 'My Location',
          ),
        ],
      ),
      body: Column(
        children: [
          // Search Bar
          Container(
            padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Search location, area, or landmark',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(30),
                ),
                contentPadding: EdgeInsets.symmetric(horizontal: 20),
                filled: true,
                fillColor: Colors.white,
              ),
              onSubmitted: (query) async {
                final parkingProvider = Provider.of<ParkingProvider>(context, listen: false);
                await parkingProvider.searchParkingSpots(query);
              },
            ),
          ),
          
          // Filters
          ParkingFilterBar(),
          
          Expanded(
            child: Consumer<ParkingProvider>(
              builder: (context, parkingProvider, child) {
                // Update markers when parking spots change
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (mounted && !parkingProvider.isLoading) {
                    _updateMarkers();
                  }
                });
                
                return Stack(
                  children: [
                    // Map
                    GoogleMap(
                      initialCameraPosition: initialCameraPosition,
                      myLocationEnabled: true,
                      myLocationButtonEnabled: false,
                      zoomControlsEnabled: false,
                      markers: _markers,
                      tileOverlays: tileOverlays,
                      onMapCreated: (controller) {
                        setState(() {
                          _mapController = controller;
                        });
                        
                        // Initial load if we have location
                        if (locationProvider.hasLocation) {
                          _loadParkingSpots();
                        } else {
                          // Wait for location then load
                          locationProvider.getCurrentLocation().then((_) {
                            if (mounted) {
                              _loadParkingSpots();
                            }
                          });
                        }
                      },
                    ),
                
                // Loading indicator
                if (parkingProvider.isLoading)
                  Positioned.fill(
                    child: Container(
                      color: Colors.black.withValues(alpha: 0.3),
                      child: Center(
                        child: LoadingIndicator(),
                      ),
                    ),
                  ),
                  
                // Error message
                if (parkingProvider.error != null)
                  Positioned(
                    bottom: 16,
                    left: 16,
                    right: 16,
                    child: Container(
                      padding: EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.red,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.error_outline, color: Colors.white),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              parkingProvider.error!,
                              style: TextStyle(color: Colors.white),
                            ),
                          ),
                          IconButton(
                            icon: Icon(Icons.close, color: Colors.white),
                            onPressed: () => parkingProvider.clearError(),
                            padding: EdgeInsets.zero,
                            constraints: BoxConstraints(),
                          ),
                        ],
                      ),
                    ),
                  ),
                
                // Parking spots found indicator
                Positioned(
                  top: 16,
                  left: 16,
                  right: 16,
                  child: Container(
                    padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.1),
                          blurRadius: 8,
                          offset: Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Text(
                      '${parkingProvider.nearbyParkingSpots.length} parking spots found',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                
                // Parking spot addition is handled by approved QuickPark partners only
                
                // Parking availability legend
                Positioned(
                  left: 16,
                  bottom: 80,
                  child: Card(
                    elevation: 4,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text('Parking:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                          SizedBox(height: 4),
                          _legendItem(Colors.green, 'Many Spots (6+)'),
                          _legendItem(Colors.yellow, 'Some Spots (3-5)'),
                          _legendItem(Colors.orange, 'Few Spots (1-2)'),
                          _legendItem(Colors.red, 'Full (0)'),
                        ],
                      ),
                    ),
                  ),
                ),
                
                // Traffic legend
                if (trafficProvider.showTrafficLayer)
                  Positioned(
                    left: 16,
                    bottom: 230,
                    child: Card(
                      elevation: 4,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text('Traffic:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                            SizedBox(height: 4),
                            _legendItem(Colors.green, 'Low'),
                            _legendItem(Colors.orange, 'Medium'),
                            _legendItem(Colors.red, 'High'),
                            _legendItem(Colors.purple, 'Severe'),
                          ],
                        ),
                      ),
                    ),
                  ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _loadParkingSpots,
        child: Icon(Icons.search),
        tooltip: 'Search Parking',
      ),
    );
  }
  
  // Create legend item widget
  Widget _legendItem(Color color, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Container(
            width: 16,
            height: 16,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
            ),
          ),
          SizedBox(width: 8),
          Text(text),
        ],
      ),
    );
  }
  
  @override
  void dispose() {
    _mapController?.dispose();
    super.dispose();
  }
}