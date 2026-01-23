// lib/screens/parking/parking_map_screen.dart
// Modern parking map with search circle, filter chips, and real-time updates

import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:provider/provider.dart';
import 'package:smart_parking_app/config/theme.dart';
import 'package:smart_parking_app/providers/location_provider.dart';
import 'package:smart_parking_app/providers/parking_provider.dart';
import 'package:smart_parking_app/providers/traffic_provider.dart';
import 'package:smart_parking_app/models/parking_spot.dart';
import 'package:smart_parking_app/screens/parking/parking_spot_bottom_sheet.dart';
import 'package:smart_parking_app/screens/parking/add_parking_spot_dialog.dart';
import 'package:smart_parking_app/providers/auth_provider.dart';

class ParkingMapScreen extends StatefulWidget {
  const ParkingMapScreen({super.key});

  @override
  _ParkingMapScreenState createState() => _ParkingMapScreenState();
}

class _ParkingMapScreenState extends State<ParkingMapScreen>
    with AutomaticKeepAliveClientMixin, TickerProviderStateMixin {
  
  GoogleMapController? _mapController;
  Set<Marker> _markers = {};
  
  // Debouncing
  Timer? _markerUpdateDebounce;
  Timer? _searchDebounce;
  
  // Controllers
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  
  // State
  bool _initialLoadComplete = false;
  bool _isSearching = false;
  
  // Suggested places for search
  List<SearchSuggestion> _searchSuggestions = [];
  
  @override
  bool get wantKeepAlive => true;
  
  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
    
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeMap();
      // Listen to parking provider changes
      final parkingProvider = Provider.of<ParkingProvider>(context, listen: false);
      parkingProvider.addListener(_onParkingDataChanged);
    });
  }
  
  void _onParkingDataChanged() {
    if (!mounted || !_initialLoadComplete) return;
    final parkingProvider = Provider.of<ParkingProvider>(context, listen: false);
    if (!parkingProvider.isLoading) {
      _updateMarkers(parkingProvider.allParkingSpots);
    }
  }
  
  void _onSearchChanged() {
    final query = _searchController.text.trim();
    
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 300), () {
      if (query.isEmpty) {
        setState(() {
          _searchSuggestions = [];
          _isSearching = false;
        });
        return;
      }
      
      _performSearch(query);
    });
  }
  
  void _performSearch(String query) {
    final parkingProvider = Provider.of<ParkingProvider>(context, listen: false);
    
    final matchingSpots = parkingProvider.allParkingSpots.where((spot) {
      final nameMatch = spot.name.toLowerCase().contains(query.toLowerCase());
      final addressMatch = spot.address.toLowerCase().contains(query.toLowerCase());
      return nameMatch || addressMatch;
    }).take(5).toList();
    
    setState(() {
      _isSearching = true;
      _searchSuggestions = matchingSpots.map((spot) => SearchSuggestion(
        title: spot.name,
        subtitle: spot.address,
        latLng: LatLng(spot.latitude, spot.longitude),
        spotId: spot.id,
        availableSpots: spot.availableSpots,
        totalSpots: spot.totalSpots,
      )).toList();
    });
  }
  
  void _onSuggestionSelected(SearchSuggestion suggestion) {
    _searchController.text = suggestion.title;
    _searchFocusNode.unfocus();
    
    setState(() {
      _searchSuggestions = [];
      _isSearching = false;
    });
    
    _mapController?.animateCamera(
      CameraUpdate.newLatLngZoom(suggestion.latLng, 15.0),
    );
  }
  
  Future<void> _initializeMap() async {
    final trafficProvider = Provider.of<TrafficProvider>(context, listen: false);
    trafficProvider.initializeTrafficOverlay();
    
    await _loadParkingSpots();
  }
  
  Future<void> _loadParkingSpots() async {
    final locationProvider = Provider.of<LocationProvider>(context, listen: false);
    final parkingProvider = Provider.of<ParkingProvider>(context, listen: false);
    
    await parkingProvider.loadAllParkingSpots();
    
    if (!locationProvider.hasLocation) {
      await locationProvider.getCurrentLocation();
    }
    
    if (locationProvider.hasLocation) {
      final lat = locationProvider.currentLocation!.latitude;
      final lng = locationProvider.currentLocation!.longitude;
      
      final userLocation = LatLng(lat, lng);
      
      if (_mapController != null) {
        _mapController!.animateCamera(CameraUpdate.newLatLngZoom(
          userLocation, 14.0
        ));
      }
    }
    
    if (mounted) {
      setState(() {
        _initialLoadComplete = true;
      });
      
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _updateMarkers(parkingProvider.allParkingSpots);
        }
      });
    }
  }
  
  Future<void> _updateMarkers(List<ParkingSpot> spots) async {
    _markerUpdateDebounce?.cancel();
    // Longer debounce to prevent frequent updates
    _markerUpdateDebounce = Timer(const Duration(milliseconds: 500), () async {
      await _doUpdateMarkers(spots);
    });
  }
  
  Future<void> _doUpdateMarkers(List<ParkingSpot> spots) async {
    if (!mounted) return;
    
    final Set<Marker> newMarkers = {};
    
    // Filter to show only available spots (exclude full ones)
    final availableSpots = spots.where((spot) => spot.availableSpots > 0).toList();
    
    // Use lightweight default markers for smooth performance
    for (final spot in availableSpots) {
      newMarkers.add(Marker(
        markerId: MarkerId(spot.id),
        position: LatLng(spot.latitude, spot.longitude),
        icon: BitmapDescriptor.defaultMarkerWithHue(
          _getDefaultMarkerHue(spot.availableSpots, spot.totalSpots),
        ),
        infoWindow: InfoWindow(
          title: '${spot.name} (${spot.availableSpots} free)',
          snippet: '${spot.availableSpots}/${spot.totalSpots} spots • ₹${spot.pricePerHour.toInt()}/hr',
        ),
        onTap: () => _onMarkerTapped(spot),
      ));
    }
    
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
        infoWindow: const InfoWindow(title: 'You are here'),
        zIndex: 1000,
      ));
    }
    
    if (mounted) {
      setState(() {
        _markers = newMarkers;
      });
    }
  }
  
  // Get marker hue based on availability ratio
  double _getDefaultMarkerHue(int available, int total) {
    if (total == 0) return BitmapDescriptor.hueGreen;
    final ratio = available / total;
    if (ratio <= 0.1) return BitmapDescriptor.hueOrange;  // Very few spots
    if (ratio <= 0.25) return BitmapDescriptor.hueYellow; // Few spots
    return BitmapDescriptor.hueGreen;                     // Many spots
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
        SnackBar(
          content: const Text('Only approved QuickPark partners can add parking spots.'),
          backgroundColor: AppTheme.warningColor,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
        locationProvider.currentLocation?.latitude ?? 17.3850,
        locationProvider.currentLocation?.longitude ?? 78.4867
      ),
      zoom: 13.0,
    );
    
    final isPartner = authProvider.currentUser?.isPartnerApproved ?? false;
    
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      body: Stack(
        children: [
          // Main Map - Optimized to prevent lag
          GoogleMap(
            initialCameraPosition: initialCameraPosition,
            myLocationEnabled: true,
            myLocationButtonEnabled: false,
            zoomControlsEnabled: false,
            mapToolbarEnabled: false,
            compassEnabled: false,
            markers: _markers,
            tileOverlays: tileOverlays,
            onMapCreated: (controller) {
              _mapController = controller;
              _setMapStyle(controller);
              
              if (locationProvider.hasLocation) {
                final userLoc = LatLng(
                  locationProvider.currentLocation!.latitude,
                  locationProvider.currentLocation!.longitude
                );
                controller.animateCamera(CameraUpdate.newLatLngZoom(userLoc, 14.0));
              }
              
              if (!_initialLoadComplete) {
                _loadParkingSpots();
              }
            },
          ),
          
          // Top Search Section
          SafeArea(
            child: Column(
              children: [
                // Search Bar
                _buildSearchBar(),
                
                // Search Suggestions
                if (_searchSuggestions.isNotEmpty)
                  _buildSearchSuggestions(),
              ],
            ),
          ),
          
          // Loading Overlay
          Consumer<ParkingProvider>(
            builder: (context, provider, _) {
              if (provider.isLoading) {
                return Positioned.fill(
                  child: Container(
                    color: Colors.black26,
                    child: Center(
                      child: _buildLoadingIndicator(),
                    ),
                  ),
                );
              }
              return const SizedBox.shrink();
            },
          ),
          
          // No spots available message
          Consumer<ParkingProvider>(
            builder: (context, provider, _) {
              if (!provider.isLoading && 
                  _initialLoadComplete && 
                  provider.allParkingSpots.isEmpty) {
                return Positioned(
                  top: 100,
                  left: 16,
                  right: 16,
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                      boxShadow: AppTheme.shadowMd,
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: AppTheme.warningColor.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                          ),
                          child: Icon(
                            Icons.info_outline,
                            color: AppTheme.warningColor,
                            size: 24,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'No parking spots found',
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  color: AppTheme.textPrimary,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Try adjusting your location or zoom out to see more areas.',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: AppTheme.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: Icon(Icons.refresh, color: AppTheme.primaryColor),
                          onPressed: _loadParkingSpots,
                        ),
                      ],
                    ),
                  ),
                );
              }
              return const SizedBox.shrink();
            },
          ),
          
          // Availability Legend & Stats
          Positioned(
            left: 16,
            bottom: 140,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Spot count indicator
                Consumer<ParkingProvider>(
                  builder: (context, provider, _) {
                    final availableCount = provider.allParkingSpots
                        .where((s) => s.availableSpots > 0)
                        .length;
                    final totalCount = provider.allParkingSpots.length;
                    
                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      margin: const EdgeInsets.only(bottom: 8),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                        boxShadow: AppTheme.shadowSm,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.local_parking,
                            size: 18,
                            color: AppTheme.primaryColor,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            '$availableCount of $totalCount spots',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.textPrimary,
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
                _buildAvailabilityLegend(),
              ],
            ),
          ),
          
          // Map Controls
          Positioned(
            right: 16,
            bottom: 140,
            child: _buildMapControls(locationProvider, trafficProvider, isPartner),
          ),
        ],
      ),
    );
  }
  
  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(AppTheme.radiusFull),
          boxShadow: AppTheme.shadowMd,
        ),
        child: Row(
          children: [
            const SizedBox(width: 16),
            Icon(Icons.search, color: AppTheme.textMuted),
            const SizedBox(width: 12),
            Expanded(
              child: TextField(
                controller: _searchController,
                focusNode: _searchFocusNode,
                decoration: InputDecoration(
                  hintText: 'Search for parking...',
                  hintStyle: TextStyle(color: AppTheme.textMuted),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(vertical: 14),
                ),
                style: const TextStyle(fontSize: 16, color: AppTheme.textPrimary),
                textInputAction: TextInputAction.search,
                onSubmitted: (value) {
                  if (value.isNotEmpty && _searchSuggestions.isNotEmpty) {
                    _onSuggestionSelected(_searchSuggestions.first);
                  }
                },
              ),
            ),
            if (_searchController.text.isNotEmpty)
              IconButton(
                icon: Icon(Icons.clear, color: AppTheme.textMuted),
                onPressed: () {
                  _searchController.clear();
                  setState(() {
                    _searchSuggestions = [];
                    _isSearching = false;
                  });
                },
              ),
            Container(
              height: 24,
              width: 1,
              color: AppTheme.dividerColor,
            ),
            IconButton(
              icon: Icon(Icons.tune, color: AppTheme.textSecondary),
              onPressed: () {
                // Show advanced filters
              },
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildSearchSuggestions() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      constraints: const BoxConstraints(maxHeight: 200),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        boxShadow: AppTheme.shadowMd,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        child: ListView.builder(
          shrinkWrap: true,
          itemCount: _searchSuggestions.length,
          itemBuilder: (context, index) {
            final suggestion = _searchSuggestions[index];
            return ListTile(
              leading: Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: _getAvailabilityColor(suggestion.availableSpots, suggestion.totalSpots).withOpacity(0.15),
                  borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                ),
                child: Center(
                  child: Text(
                    '${suggestion.availableSpots}',
                    style: TextStyle(
                      color: _getAvailabilityColor(suggestion.availableSpots, suggestion.totalSpots),
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ),
              ),
              title: Text(
                suggestion.title,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              subtitle: Text(
                suggestion.subtitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
              ),
              trailing: Icon(Icons.north_east, color: AppTheme.primaryColor, size: 20),
              onTap: () => _onSuggestionSelected(suggestion),
            );
          },
        ),
      ),
    );
  }
  
  Widget _buildLoadingIndicator() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppTheme.radiusLg),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.9),
            borderRadius: BorderRadius.circular(AppTheme.radiusLg),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 48,
                height: 48,
                child: CircularProgressIndicator(
                  strokeWidth: 3,
                  valueColor: AlwaysStoppedAnimation(AppTheme.primaryColor),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Finding parking spots...',
                style: TextStyle(fontWeight: FontWeight.w500),
              ),
            ],
          ),
        ),
      ),
    );
  }
  
  Widget _buildAvailabilityLegend() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        boxShadow: AppTheme.shadowMd,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'AVAILABILITY',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 11,
              color: AppTheme.textSecondary,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 10),
          _legendItem(const Color(0xFF4CAF50), 'Many spots (>50%)'),
          _legendItem(const Color(0xFFFFC107), 'Some spots (25-50%)'),
          _legendItem(const Color(0xFFFF9800), 'Few spots (10-25%)'),
          _legendItem(const Color(0xFFFF5722), 'Very few (<10%)'),
          const SizedBox(height: 6),
          Text(
            'Full spots hidden',
            style: TextStyle(
              fontSize: 10,
              color: AppTheme.textMuted,
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _legendItem(Color color, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
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
          const SizedBox(width: 8),
          Text(
            text,
            style: TextStyle(
              fontSize: 12,
              color: AppTheme.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildMapControls(LocationProvider locationProvider, TrafficProvider trafficProvider, bool isPartner) {
    return Column(
      children: [
        // Zoom In
        _buildControlButton(
          Icons.add,
          'Zoom In',
          () {
            _mapController?.animateCamera(CameraUpdate.zoomIn());
          },
        ),
        const SizedBox(height: 2),
        // Zoom Out
        _buildControlButton(
          Icons.remove,
          'Zoom Out',
          () {
            _mapController?.animateCamera(CameraUpdate.zoomOut());
          },
        ),
        const SizedBox(height: 8),
        // My Location
        _buildControlButton(
          Icons.my_location,
          'My Location',
          () {
            if (locationProvider.hasLocation && _mapController != null) {
              final userLoc = LatLng(
                locationProvider.currentLocation!.latitude,
                locationProvider.currentLocation!.longitude
              );
              _mapController!.animateCamera(CameraUpdate.newLatLngZoom(userLoc, 15.0));
            }
          },
        ),
        if (isPartner) ...[
          const SizedBox(height: 8),
          _buildControlButton(
            Icons.add_location_alt,
            'Add Parking',
            () => _showAddParkingSpotDialog(),
            color: AppTheme.successColor,
          ),
        ],
      ],
    );
  }
  
  Widget _buildControlButton(IconData icon, String tooltip, VoidCallback onTap, {Color? color}) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        boxShadow: AppTheme.shadowSm,
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppTheme.radiusMd),
          child: Container(
            width: 44,
            height: 44,
            child: Icon(
              icon,
              color: color ?? AppTheme.textPrimary,
              size: 22,
            ),
          ),
        ),
      ),
    );
  }
  
  Color _getAvailabilityColor(int available, int total) {
    if (available == 0) return const Color(0xFFE53935); // Red - Full
    if (total == 0) return const Color(0xFF4CAF50);
    
    final ratio = available / total;
    if (ratio <= 0.1) return const Color(0xFFFF5722);  // Deep Orange - Almost full
    if (ratio <= 0.25) return const Color(0xFFFF9800); // Orange - Few spots
    if (ratio <= 0.5) return const Color(0xFFFFC107);  // Amber - Some spots
    return const Color(0xFF4CAF50);                    // Green - Many spots
  }
  
  Future<void> _setMapStyle(GoogleMapController controller) async {
    try {
      final style = '''
[
  {
    "featureType": "poi",
    "elementType": "labels",
    "stylers": [{"visibility": "off"}]
  },
  {
    "featureType": "transit",
    "elementType": "labels",
    "stylers": [{"visibility": "simplified"}]
  }
]
''';
      await controller.setMapStyle(style);
    } catch (e) {
      // Map style setting failed, continue without it
    }
  }
  
  @override
  void dispose() {
    // Remove parking provider listener
    try {
      final parkingProvider = Provider.of<ParkingProvider>(context, listen: false);
      parkingProvider.removeListener(_onParkingDataChanged);
    } catch (_) {}
    
    _mapController?.dispose();
    _markerUpdateDebounce?.cancel();
    _searchDebounce?.cancel();
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }
}

// Search suggestion model
class SearchSuggestion {
  final String title;
  final String subtitle;
  final LatLng latLng;
  final String spotId;
  final int availableSpots;
  final int totalSpots;
  
  SearchSuggestion({
    required this.title,
    required this.subtitle,
    required this.latLng,
    required this.spotId,
    required this.availableSpots,
    required this.totalSpots,
  });
}