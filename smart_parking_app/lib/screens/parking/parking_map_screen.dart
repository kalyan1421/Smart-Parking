// lib/screens/parking/parking_map_screen.dart
// Production-grade map with custom markers, real-time updates, and efficient rendering

import 'dart:async';
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
import 'package:smart_parking_app/widgets/custom_marker_generator.dart';

class ParkingMapScreen extends StatefulWidget {
  const ParkingMapScreen({super.key});

  @override
  _ParkingMapScreenState createState() => _ParkingMapScreenState();
}

class _ParkingMapScreenState extends State<ParkingMapScreen> 
    with AutomaticKeepAliveClientMixin {
  
  GoogleMapController? _mapController;
  Set<Marker> _markers = {};
  
  // Marker cache for efficient updates
  final Map<String, ParkingMarkerData> _markerDataCache = {};
  
  // Stream subscription for real-time updates
  StreamSubscription? _spotStreamSubscription;
  
  // Debouncing for marker updates
  Timer? _markerUpdateDebounce;
  
  // Search controller
  final TextEditingController _searchController = TextEditingController();
  
  // Track if initial load is complete
  bool _initialLoadComplete = false;
  
  @override
  bool get wantKeepAlive => true;
  
  @override
  void initState() {
    super.initState();
    
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeMap();
    });
  }
  
  Future<void> _initializeMap() async {
    final trafficProvider = Provider.of<TrafficProvider>(context, listen: false);
    trafficProvider.initializeTrafficOverlay();
    
    await _loadParkingSpots();
  }
  
  Future<void> _loadParkingSpots() async {
    final locationProvider = Provider.of<LocationProvider>(context, listen: false);
    final parkingProvider = Provider.of<ParkingProvider>(context, listen: false);
    
    // Wait for location
    if (!locationProvider.hasLocation) {
      await locationProvider.getCurrentLocation();
    }
    
    if (locationProvider.hasLocation) {
      final lat = locationProvider.currentLocation!.latitude;
      final lng = locationProvider.currentLocation!.longitude;
      
      // Start streaming for real-time updates
      parkingProvider.startStreamingNearby(lat, lng);
      
      // Move map to user location
      if (_mapController != null) {
        _mapController!.animateCamera(CameraUpdate.newLatLngZoom(
          LatLng(lat, lng), 14.0
        ));
      }
    } else {
      // Fallback: load all spots
      await parkingProvider.loadAllParkingSpots();
    }
    
    _initialLoadComplete = true;
  }
  
  /// Update markers efficiently - only update changed markers
  Future<void> _updateMarkers(List<ParkingSpot> spots) async {
    _markerUpdateDebounce?.cancel();
    _markerUpdateDebounce = Timer(const Duration(milliseconds: 100), () async {
      await _doUpdateMarkers(spots);
    });
  }
  
  Future<void> _doUpdateMarkers(List<ParkingSpot> spots) async {
    if (!mounted) return;
    
    final Set<Marker> newMarkers = {};
    final Set<String> processedIds = {};
    
    // Process each parking spot
    for (final spot in spots) {
      processedIds.add(spot.id);
      
      final newData = ParkingMarkerData(
        id: spot.id,
        name: spot.name,
        position: LatLng(spot.latitude, spot.longitude),
        availableSpots: spot.availableSpots,
        totalSpots: spot.totalSpots,
        pricePerHour: spot.pricePerHour,
      );
      
      final existingData = _markerDataCache[spot.id];
      
      // Check if we need to regenerate the icon
      BitmapDescriptor icon;
      if (existingData == null || existingData.needsIconUpdate(newData)) {
        // Generate new custom marker
        icon = await CustomMarkerGenerator.generateSlotMarker(
          availableSpots: spot.availableSpots,
          totalSpots: spot.totalSpots,
          size: 52,
        );
        newData.cachedIcon = icon;
      } else {
        // Reuse cached icon
        icon = existingData.cachedIcon ?? await CustomMarkerGenerator.generateSlotMarker(
          availableSpots: spot.availableSpots,
          totalSpots: spot.totalSpots,
          size: 52,
        );
        newData.cachedIcon = icon;
      }
      
      // Create marker with custom icon
      newMarkers.add(Marker(
        markerId: MarkerId(spot.id),
        position: LatLng(spot.latitude, spot.longitude),
        icon: icon,
        infoWindow: InfoWindow(
          title: '${spot.name} (${spot.availableSpots}/${spot.totalSpots})',
          snippet: '₹${spot.pricePerHour.toStringAsFixed(0)}/hr • ${_getAvailabilityText(spot)}',
        ),
        onTap: () => _onMarkerTapped(spot),
        anchor: const Offset(0.5, 1.0),
      ));
      
      // Update cache
      _markerDataCache[spot.id] = newData;
    }
    
    // Remove stale entries from cache
    _markerDataCache.removeWhere((key, _) => !processedIds.contains(key));
    
    // Add user location marker
    final locationProvider = Provider.of<LocationProvider>(context, listen: false);
    if (locationProvider.hasLocation) {
      newMarkers.add(Marker(
        markerId: const MarkerId('user_location'),
        position: LatLng(
          locationProvider.currentLocation!.latitude,
          locationProvider.currentLocation!.longitude
        ),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
        infoWindow: const InfoWindow(title: 'Your Location'),
        zIndex: 1000,
      ));
    }
    
    if (mounted) {
      setState(() {
        _markers = newMarkers;
      });
    }
  }
  
  String _getAvailabilityText(ParkingSpot spot) {
    if (spot.availableSpots == 0) return 'FULL';
    if (spot.availableSpots <= 2) return 'Few left';
    if (spot.availableSpots <= 5) return 'Available';
    return 'Many spots';
  }
  
  void _onMarkerTapped(ParkingSpot spot) {
    final parkingProvider = Provider.of<ParkingProvider>(context, listen: false);
    parkingProvider.selectParkingSpot(spot);
    
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) =>  ParkingSpotBottomSheet(),
    );
  }
  
  Future<void> _showAddParkingSpotDialog() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    
    if (authProvider.currentUser == null || !authProvider.currentUser!.isPartnerApproved) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Only approved QuickPark partners can add parking spots.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final result = await showDialog(
      context: context,
      builder: (context) => const AddParkingSpotDialog(),
    );

    if (result == true) {
      _loadParkingSpots();
    }
  }
  
  void _onSearch(String query) {
    final parkingProvider = Provider.of<ParkingProvider>(context, listen: false);
    parkingProvider.searchParkingSpots(query);
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    
    final locationProvider = Provider.of<LocationProvider>(context);
    final trafficProvider = Provider.of<TrafficProvider>(context);
    final authProvider = Provider.of<AuthProvider>(context);
    
    if (!trafficProvider.isOverlaySetup) {
      trafficProvider.setupTrafficOverlay();
    }
    
    Set<TileOverlay> tileOverlays = {};
    if (trafficProvider.isOverlaySetup && 
        trafficProvider.trafficOverlay != null &&
        trafficProvider.showTrafficLayer) {
      tileOverlays = {trafficProvider.trafficOverlay!};
    }
    
    final initialCameraPosition = CameraPosition(
      target: LatLng(
        locationProvider.currentLocation?.latitude ?? 0,
        locationProvider.currentLocation?.longitude ?? 0
      ),
      zoom: 13.0,
    );
    
    final isPartner = authProvider.currentUser?.isPartnerApproved ?? false;
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Find Parking'),
        elevation: 0,
        actions: [
          if (isPartner)
            IconButton(
              icon: const Icon(Icons.add_location),
              onPressed: _showAddParkingSpotDialog,
              tooltip: 'Add Parking Spot',
            ),
          IconButton(
            icon: Icon(
              trafficProvider.showTrafficLayer ? Icons.traffic : Icons.traffic_outlined,
              color: trafficProvider.showTrafficLayer ? Colors.amber : null,
            ),
            tooltip: 'Toggle traffic',
            onPressed: () => trafficProvider.toggleTrafficLayer(),
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadParkingSpots,
            tooltip: 'Refresh',
          ),
          IconButton(
            icon: const Icon(Icons.my_location),
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
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
            decoration: BoxDecoration(
              color: Theme.of(context).scaffoldBackgroundColor,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search parking by name or area...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          _onSearch('');
                        },
                      )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(30),
                  borderSide: BorderSide.none,
                ),
                filled: true,
                fillColor: Colors.grey.shade100,
                contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              ),
              onChanged: (value) {
                setState(() {});
              },
              onSubmitted: _onSearch,
            ),
          ),
          
          // Filters
           ParkingFilterBar(),
          
          // Map
          Expanded(
            child: Consumer<ParkingProvider>(
              builder: (context, parkingProvider, child) {
                // Update markers when spots change
                if (_initialLoadComplete && !parkingProvider.isLoading) {
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    _updateMarkers(parkingProvider.nearbyParkingSpots);
                  });
                }
                
                return Stack(
                  children: [
                    // Google Map
                    GoogleMap(
                      initialCameraPosition: initialCameraPosition,
                      myLocationEnabled: true,
                      myLocationButtonEnabled: false,
                      zoomControlsEnabled: false,
                      mapToolbarEnabled: false,
                      markers: _markers,
                      tileOverlays: tileOverlays,
                      onMapCreated: (controller) {
                        _mapController = controller;
                        
                        if (locationProvider.hasLocation) {
                          controller.animateCamera(CameraUpdate.newLatLngZoom(
                            LatLng(
                              locationProvider.currentLocation!.latitude,
                              locationProvider.currentLocation!.longitude
                            ),
                            14.0,
                          ));
                        }
                        
                        if (!_initialLoadComplete) {
                          _loadParkingSpots();
                        }
                      },
                      onCameraIdle: () {
                        // Could implement viewport-based loading here
                      },
                    ),
                    
                    // Loading overlay
                    if (parkingProvider.isLoading)
                      Positioned.fill(
                        child: Container(
                          color: Colors.black.withOpacity(0.2),
                          child: const Center(
                            child: LoadingIndicator(),
                          ),
                        ),
                      ),
                    
                    // Error message
                    if (parkingProvider.error != null)
                      Positioned(
                        bottom: 100,
                        left: 16,
                        right: 16,
                        child: Material(
                          elevation: 4,
                          borderRadius: BorderRadius.circular(12),
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.red.shade50,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.red.shade200),
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.error_outline, color: Colors.red.shade700),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    parkingProvider.error!,
                                    style: TextStyle(color: Colors.red.shade700),
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.close, size: 20),
                                  onPressed: () => parkingProvider.clearError(),
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    
                    // Stats bar
                    Positioned(
                      top: 12,
                      left: 12,
                      right: 12,
                      child: _buildStatsBar(parkingProvider),
                    ),
                    
                    // Legend
                    Positioned(
                      left: 12,
                      bottom: 100,
                      child: _buildLegend(),
                    ),
                    
                    // Traffic legend
                    if (trafficProvider.showTrafficLayer)
                      Positioned(
                        left: 12,
                        bottom: 260,
                        child: _buildTrafficLegend(),
                      ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _loadParkingSpots,
        icon: const Icon(Icons.search),
        label: const Text('Search Here'),
        backgroundColor: Theme.of(context).primaryColor,
      ),
    );
  }
  
  Widget _buildStatsBar(ParkingProvider provider) {
    final spotCount = provider.nearbyParkingSpots.length;
    final availableCount = provider.availableSpotsCount;
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.local_parking, color: Theme.of(context).primaryColor, size: 20),
          const SizedBox(width: 8),
          Text(
            '$spotCount parking lots',
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
          ),
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 12),
            width: 1,
            height: 16,
            color: Colors.grey.shade300,
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: Colors.green.shade50,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: Colors.green,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  '$availableCount available',
                  style: TextStyle(
                    color: Colors.green.shade700,
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildLegend() {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Availability',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
            ),
            const SizedBox(height: 8),
            _legendItem(const Color(0xFF4CAF50), 'Many spots'),
            _legendItem(const Color(0xFFFFC107), 'Some spots'),
            _legendItem(const Color(0xFFFF9800), 'Few spots'),
            _legendItem(const Color(0xFFE53935), 'Full'),
          ],
        ),
      ),
    );
  }
  
  Widget _buildTrafficLegend() {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Traffic',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
            ),
            const SizedBox(height: 8),
            _legendItem(Colors.green, 'Low'),
            _legendItem(Colors.orange, 'Medium'),
            _legendItem(Colors.red, 'High'),
            _legendItem(Colors.purple, 'Severe'),
          ],
        ),
      ),
    );
  }
  
  Widget _legendItem(Color color, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 14,
            height: 14,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 1.5),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 2,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(text, style: const TextStyle(fontSize: 11)),
        ],
      ),
    );
  }
  
  @override
  void dispose() {
    _mapController?.dispose();
    _spotStreamSubscription?.cancel();
    _markerUpdateDebounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }
}
