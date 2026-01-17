// lib/screens/parking/parking_map_screen.dart
// Modern parking map with search circle, glassmorphism UI, and real-time updates

import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:provider/provider.dart';
import 'package:geolocator/geolocator.dart';
import 'package:smart_parking_app/providers/location_provider.dart';
import 'package:smart_parking_app/providers/parking_provider.dart';
import 'package:smart_parking_app/providers/traffic_provider.dart';
import 'package:smart_parking_app/models/parking_spot.dart';
import 'package:smart_parking_app/screens/parking/parking_spot_bottom_sheet.dart';
import 'package:smart_parking_app/screens/parking/add_parking_spot_dialog.dart';
import 'package:smart_parking_app/providers/auth_provider.dart';
import 'package:smart_parking_app/widgets/custom_marker_generator.dart';

class ParkingMapScreen extends StatefulWidget {
  const ParkingMapScreen({super.key});

  @override
  _ParkingMapScreenState createState() => _ParkingMapScreenState();
}

class _ParkingMapScreenState extends State<ParkingMapScreen>
    with AutomaticKeepAliveClientMixin, TickerProviderStateMixin {
  
  GoogleMapController? _mapController;
  Set<Marker> _markers = {};
  Set<Circle> _searchCircles = {};
  
  // Marker cache
  final Map<String, ParkingMarkerData> _markerDataCache = {};
  
  // Stream subscription
  StreamSubscription? _spotStreamSubscription;
  
  // Debouncing
  Timer? _markerUpdateDebounce;
  Timer? _searchDebounce;
  
  // Controllers
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  
  // State
  bool _initialLoadComplete = false;
  bool _showFilters = false;
  bool _isSearching = false;
  LatLng? _searchCenter;
  double _currentRadius = 10000; // meters (10km default)
  
  // Animation controllers
  late AnimationController _filterAnimController;
  late Animation<double> _filterAnimation;
  
  // Suggested places for search
  List<SearchSuggestion> _searchSuggestions = [];
  
  @override
  bool get wantKeepAlive => true;
  
  @override
  void initState() {
    super.initState();
    
    _filterAnimController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _filterAnimation = CurvedAnimation(
      parent: _filterAnimController,
      curve: Curves.easeOutCubic,
    );
    
    _searchController.addListener(_onSearchChanged);
    
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeMap();
    });
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
    
    // Search in existing parking spots
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
      _searchCenter = suggestion.latLng;
    });
    
    // Move map to selected location and show search radius circle
    _moveToLocationWithCircle(suggestion.latLng);
    
    // Load parking spots near this location
    final parkingProvider = Provider.of<ParkingProvider>(context, listen: false);
    parkingProvider.startStreamingNearby(
      suggestion.latLng.latitude,
      suggestion.latLng.longitude,
      radius: _currentRadius,
    );
  }
  
  void _moveToLocationWithCircle(LatLng center) {
    _mapController?.animateCamera(
      CameraUpdate.newLatLngZoom(center, _getZoomForRadius(_currentRadius)),
    );
    
    _updateSearchCircle(center);
  }
  
  void _updateSearchCircle(LatLng center) {
    setState(() {
      _searchCenter = center;
      _searchCircles = {
        Circle(
          circleId: const CircleId('search_radius'),
          center: center,
          radius: _currentRadius,
          fillColor: Theme.of(context).primaryColor.withOpacity(0.1),
          strokeColor: Theme.of(context).primaryColor.withOpacity(0.5),
          strokeWidth: 2,
        ),
      };
    });
  }
  
  double _getZoomForRadius(double radiusMeters) {
    // Approximate zoom level for given radius
    if (radiusMeters <= 500) return 16;
    if (radiusMeters <= 1000) return 15;
    if (radiusMeters <= 2000) return 14;
    if (radiusMeters <= 5000) return 13;
    if (radiusMeters <= 10000) return 12;
    if (radiusMeters <= 15000) return 11;
    if (radiusMeters <= 25000) return 10;
    return 9;
  }
  
  Future<void> _initializeMap() async {
      final trafficProvider = Provider.of<TrafficProvider>(context, listen: false);
      trafficProvider.initializeTrafficOverlay();
    
    await _loadParkingSpots();
  }
  
  Future<void> _loadParkingSpots() async {
    final locationProvider = Provider.of<LocationProvider>(context, listen: false);
    final parkingProvider = Provider.of<ParkingProvider>(context, listen: false);
    
    // First, load all parking spots to ensure we have data immediately
    await parkingProvider.loadAllParkingSpots();
    
    if (!locationProvider.hasLocation) {
      await locationProvider.getCurrentLocation();
    }
    
    if (locationProvider.hasLocation) {
      final lat = locationProvider.currentLocation!.latitude;
      final lng = locationProvider.currentLocation!.longitude;
      
      // Update search circle at user's location
      final userLocation = LatLng(lat, lng);
      
    if (mounted) {
        _updateSearchCircle(userLocation);
      }
      
      // Start streaming nearby spots for real-time updates
      parkingProvider.startStreamingNearby(lat, lng, radius: _currentRadius);
      
      // Move map to user location
      if (_mapController != null) {
        _mapController!.animateCamera(CameraUpdate.newLatLngZoom(
          userLocation, _getZoomForRadius(_currentRadius)
        ));
      }
    }
    
    if (mounted) {
      setState(() {
        _initialLoadComplete = true;
      });
      
      // Force marker update after initial load
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _updateMarkers(parkingProvider.nearbyParkingSpots);
        }
      });
    }
  }
  
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
      
      BitmapDescriptor icon;
      if (existingData == null || existingData.needsIconUpdate(newData)) {
        icon = await CustomMarkerGenerator.generateSlotMarker(
          availableSpots: spot.availableSpots,
          totalSpots: spot.totalSpots,
          size: 56,
        );
        newData.cachedIcon = icon;
      } else {
        icon = existingData.cachedIcon ?? await CustomMarkerGenerator.generateSlotMarker(
          availableSpots: spot.availableSpots,
          totalSpots: spot.totalSpots,
          size: 56,
        );
        newData.cachedIcon = icon;
      }
      
      newMarkers.add(Marker(
        markerId: MarkerId(spot.id),
        position: LatLng(spot.latitude, spot.longitude),
        icon: icon,
        infoWindow: InfoWindow(
          title: '${spot.name}',
          snippet: '${spot.availableSpots}/${spot.totalSpots} spots • ₹${spot.pricePerHour.toInt()}/hr',
        ),
        onTap: () => _onMarkerTapped(spot),
        anchor: const Offset(0.5, 1.0),
      ));
      
      _markerDataCache[spot.id] = newData;
    }
    
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
  
  void _onMarkerTapped(ParkingSpot spot) {
    final parkingProvider = Provider.of<ParkingProvider>(context, listen: false);
    parkingProvider.selectParkingSpot(spot);
    
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => ParkingSpotBottomSheet(),
    );
  }
  
  Future<void> _showAddParkingSpotDialog() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    
    if (authProvider.currentUser == null || !authProvider.currentUser!.isPartnerApproved) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Only approved QuickPark partners can add parking spots.'),
          backgroundColor: Colors.orange.shade700,
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
  
  void _toggleFilters() {
    setState(() {
      _showFilters = !_showFilters;
    });
    
    if (_showFilters) {
      _filterAnimController.forward();
    } else {
      _filterAnimController.reverse();
    }
  }
  
  void _onRadiusChanged(double newRadius) {
    setState(() {
      _currentRadius = newRadius;
    });
    
    final center = _searchCenter ?? 
        (_mapController != null ? null : null);
    
    if (center != null) {
      _updateSearchCircle(center);
      
      final parkingProvider = Provider.of<ParkingProvider>(context, listen: false);
      parkingProvider.updateSearchRadius(newRadius);
      parkingProvider.startStreamingNearby(
        center.latitude,
        center.longitude,
        radius: newRadius,
      );
      
      // Adjust zoom level
      _mapController?.animateCamera(
        CameraUpdate.newLatLngZoom(center, _getZoomForRadius(newRadius)),
      );
    }
  }
  
  void _searchHere() async {
    final bounds = await _mapController?.getVisibleRegion();
    if (bounds == null) return;
    
    final center = LatLng(
      (bounds.northeast.latitude + bounds.southwest.latitude) / 2,
      (bounds.northeast.longitude + bounds.southwest.longitude) / 2,
    );
    
    _updateSearchCircle(center);
    
    final parkingProvider = Provider.of<ParkingProvider>(context, listen: false);
    parkingProvider.startStreamingNearby(
      center.latitude,
      center.longitude,
      radius: _currentRadius,
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    
    final theme = Theme.of(context);
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
      backgroundColor: const Color(0xFF0A0E21),
      body: Stack(
        children: [
          // Main Map
          Consumer<ParkingProvider>(
              builder: (context, parkingProvider, child) {
              if (_initialLoadComplete && !parkingProvider.isLoading) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  _updateMarkers(parkingProvider.nearbyParkingSpots);
                });
              }
                
              return GoogleMap(
                      initialCameraPosition: initialCameraPosition,
                      myLocationEnabled: true,
                      myLocationButtonEnabled: false,
                      zoomControlsEnabled: false,
                mapToolbarEnabled: false,
                compassEnabled: false,
                      markers: _markers,
                circles: _searchCircles,
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
                    _updateSearchCircle(userLoc);
                  }
                  
                  if (!_initialLoadComplete) {
                              _loadParkingSpots();
                  }
                },
                onCameraIdle: () {},
              );
            },
          ),
          
          // Top Search Bar with Glass Effect
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  // Search Bar
                  _buildSearchBar(theme),
                  
                  // Search Suggestions
                  if (_searchSuggestions.isNotEmpty)
                    _buildSearchSuggestions(theme),
                  
                  // Filter Panel
                  if (_showFilters)
                    SizeTransition(
                      sizeFactor: _filterAnimation,
                      child: _buildFilterPanel(theme),
                    ),
                ],
              ),
            ),
          ),
          
          // Stats Bar (bottom of search area)
          Consumer<ParkingProvider>(
            builder: (context, provider, _) {
              return Positioned(
                top: MediaQuery.of(context).padding.top + 80 + 
                    (_searchSuggestions.isNotEmpty ? 200 : 0) +
                    (_showFilters ? 180 : 0),
                left: 16,
                right: 16,
                child: _buildStatsChip(provider, theme),
              );
            },
          ),
          
          // Loading Overlay
          Consumer<ParkingProvider>(
            builder: (context, provider, _) {
              if (provider.isLoading) {
                return Positioned.fill(
                    child: Container(
                    color: Colors.black26,
                      child: Center(
                      child: _buildLoadingIndicator(theme),
                    ),
                  ),
                );
              }
              return const SizedBox.shrink();
            },
          ),
          
          // Error Message
          Consumer<ParkingProvider>(
            builder: (context, provider, _) {
              if (provider.error != null) {
                return Positioned(
                  bottom: 140,
                  left: 16,
                  right: 16,
                  child: _buildErrorCard(provider, theme),
                );
              }
              return const SizedBox.shrink();
            },
          ),
          
          // Legend
                  Positioned(
                    left: 16,
            bottom: 130,
            child: _buildLegend(theme),
          ),
          
          // Right side controls
          Positioned(
                    right: 16,
            bottom: 130,
            child: _buildMapControls(theme, locationProvider, trafficProvider, isPartner),
          ),
          
          // Search Here Button
          Positioned(
            bottom: 80,
            left: 0,
            right: 0,
            child: Center(
              child: _buildSearchHereButton(theme),
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildSearchBar(ThemeData theme) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                    child: Container(
                      decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.9),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 20,
                offset: const Offset(0, 4),
              ),
            ],
                      ),
                      child: Row(
                        children: [
                          Expanded(
                child: TextField(
                  controller: _searchController,
                  focusNode: _searchFocusNode,
                  decoration: InputDecoration(
                    hintText: 'Search parking by name or area...',
                    hintStyle: TextStyle(color: Colors.grey.shade500),
                    prefixIcon: Icon(Icons.search, color: theme.primaryColor),
                    suffixIcon: _searchController.text.isNotEmpty
                        ? IconButton(
                            icon: Icon(Icons.clear, color: Colors.grey.shade600),
                            onPressed: () {
                              _searchController.clear();
                              setState(() {
                                _searchSuggestions = [];
                                _isSearching = false;
                              });
                            },
                          )
                        : null,
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                  ),
                  style: const TextStyle(fontSize: 16, color: Colors.black87),
                  textInputAction: TextInputAction.search,
                  onSubmitted: (value) {
                    if (value.isNotEmpty && _searchSuggestions.isNotEmpty) {
                      _onSuggestionSelected(_searchSuggestions.first);
                    }
                  },
                ),
              ),
              Container(
                height: 40,
                width: 1,
                color: Colors.grey.shade300,
                          ),
                          IconButton(
                icon: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 200),
                  child: Icon(
                    _showFilters ? Icons.filter_alt : Icons.filter_alt_outlined,
                    key: ValueKey(_showFilters),
                    color: _showFilters ? theme.primaryColor : Colors.grey.shade600,
                  ),
                ),
                onPressed: _toggleFilters,
                          ),
                        ],
                      ),
                    ),
                  ),
    );
  }
  
  Widget _buildSearchSuggestions(ThemeData theme) {
    return Container(
      margin: const EdgeInsets.only(top: 8),
      constraints: const BoxConstraints(maxHeight: 200),
                    decoration: BoxDecoration(
                      color: Colors.white,
        borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
                        ),
                      ],
                    ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
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
                  borderRadius: BorderRadius.circular(12),
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
                style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
              ),
              trailing: Icon(Icons.north_east, color: theme.primaryColor, size: 20),
              onTap: () => _onSuggestionSelected(suggestion),
            );
          },
        ),
      ),
    );
  }
  
  Widget _buildFilterPanel(ThemeData theme) {
    return Consumer<ParkingProvider>(
      builder: (context, provider, _) {
        return Container(
          margin: const EdgeInsets.only(top: 8),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Radius Slider
              Row(
                children: [
                  Icon(Icons.radar, color: theme.primaryColor, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    'Search Radius: ${(_currentRadius / 1000).toStringAsFixed(1)} km',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ],
              ),
              Slider(
                value: _currentRadius.clamp(500, 25000),
                min: 500,
                max: 25000,
                divisions: 49,
                activeColor: theme.primaryColor,
                label: '${(_currentRadius / 1000).toStringAsFixed(1)} km',
                onChanged: _onRadiusChanged,
              ),
              
              const Divider(),
              
              // Quick Filters
              Row(
                children: [
                  Icon(Icons.tune, color: theme.primaryColor, size: 20),
                  const SizedBox(width: 8),
                  const Text(
                    'Quick Filters',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _buildQuickFilter(
                    'Available Only',
                    Icons.check_circle,
                    provider.showAvailableOnly,
                    () => provider.toggleAvailabilityFilter(),
                    theme,
                  ),
                  _buildQuickFilter(
                    'Low Price',
                    Icons.attach_money,
                    provider.maxPrice <= 50,
                    () => provider.updatePriceRange(0, 50),
                    theme,
                  ),
                  _buildQuickFilter(
                    'High Rated',
                    Icons.star,
                    provider.sortBy == 'rating',
                    () => provider.updateSortBy('rating'),
                    theme,
                  ),
                  _buildQuickFilter(
                    'Nearby',
                    Icons.near_me,
                    provider.sortBy == 'distance',
                    () => provider.updateSortBy('distance'),
                    theme,
                  ),
                ],
              ),
              
              const SizedBox(height: 12),
              
              // Clear Filters
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: () => provider.clearFilters(),
                  icon: const Icon(Icons.refresh, size: 18),
                  label: const Text('Reset Filters'),
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.grey.shade700,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
  
  Widget _buildQuickFilter(String label, IconData icon, bool isSelected, VoidCallback onTap, ThemeData theme) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? theme.primaryColor.withOpacity(0.15) : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? theme.primaryColor : Colors.transparent,
            width: 1.5,
          ),
        ),
        child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
            Icon(
              icon,
              size: 16,
              color: isSelected ? theme.primaryColor : Colors.grey.shade600,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? theme.primaryColor : Colors.grey.shade700,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                fontSize: 13,
              ),
            ),
                        ],
                      ),
                    ),
    );
  }
  
  Widget _buildStatsChip(ParkingProvider provider, ThemeData theme) {
    final spotCount = provider.nearbyParkingSpots.length;
    final availableCount = provider.availableSpotsCount;
    
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.9),
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.08),
                blurRadius: 12,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: theme.primaryColor.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.local_parking, color: theme.primaryColor, size: 18),
              ),
              const SizedBox(width: 10),
              Text(
                '$spotCount parking',
                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
              ),
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 12),
                width: 1,
                height: 20,
                color: Colors.grey.shade300,
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF4CAF50).withOpacity(0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        color: Color(0xFF4CAF50),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '$availableCount available',
                      style: const TextStyle(
                        color: Color(0xFF2E7D32),
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
  
  Widget _buildLoadingIndicator(ThemeData theme) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.9),
            borderRadius: BorderRadius.circular(16),
          ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
              SizedBox(
                width: 48,
                height: 48,
                child: CircularProgressIndicator(
                  strokeWidth: 3,
                  valueColor: AlwaysStoppedAnimation(theme.primaryColor),
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
  
  Widget _buildErrorCard(ParkingProvider provider, ThemeData theme) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.red.shade50.withOpacity(0.95),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.red.shade200),
          ),
          child: Row(
            children: [
              Icon(Icons.error_outline, color: Colors.red.shade700),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  provider.error!,
                  style: TextStyle(color: Colors.red.shade700, fontSize: 14),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close, size: 20),
                onPressed: () => provider.clearError(),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ],
          ),
        ),
      ),
    );
  }
  
  Widget _buildLegend(ThemeData theme) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.9),
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.08),
                blurRadius: 10,
              ),
            ],
          ),
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
            width: 12,
            height: 12,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 1.5),
              boxShadow: [
                BoxShadow(
                  color: color.withOpacity(0.4),
                  blurRadius: 4,
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
  
  Widget _buildMapControls(ThemeData theme, LocationProvider locationProvider, TrafficProvider trafficProvider, bool isPartner) {
    return Column(
      children: [
        if (isPartner) ...[
          _buildControlButton(
            Icons.add_location_alt,
            'Add Parking',
            () => _showAddParkingSpotDialog(),
            theme,
          ),
          const SizedBox(height: 8),
        ],
        _buildControlButton(
          trafficProvider.showTrafficLayer ? Icons.traffic : Icons.traffic_outlined,
          'Traffic',
          () => trafficProvider.toggleTrafficLayer(),
          theme,
          isActive: trafficProvider.showTrafficLayer,
        ),
        const SizedBox(height: 8),
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
              _updateSearchCircle(userLoc);
              
              final parkingProvider = Provider.of<ParkingProvider>(context, listen: false);
              parkingProvider.startStreamingNearby(
                userLoc.latitude,
                userLoc.longitude,
                radius: _currentRadius,
              );
            }
          },
          theme,
        ),
        const SizedBox(height: 8),
        _buildControlButton(
          Icons.refresh,
          'Refresh',
          () => _loadParkingSpots(),
          theme,
        ),
      ],
    );
  }
  
  Widget _buildControlButton(IconData icon, String tooltip, VoidCallback onTap, ThemeData theme, {bool isActive = false}) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
        child: Material(
          color: isActive ? theme.primaryColor.withOpacity(0.2) : Colors.white.withOpacity(0.9),
          borderRadius: BorderRadius.circular(12),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(12),
            child: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.08),
                    blurRadius: 8,
                  ),
                ],
              ),
              child: Icon(
                icon,
                color: isActive ? theme.primaryColor : Colors.grey.shade700,
                size: 22,
              ),
            ),
          ),
        ),
      ),
    );
  }
  
  Widget _buildSearchHereButton(ThemeData theme) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(25),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
        child: Material(
          color: theme.primaryColor,
          borderRadius: BorderRadius.circular(25),
          child: InkWell(
            onTap: _searchHere,
            borderRadius: BorderRadius.circular(25),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(25),
                boxShadow: [
                  BoxShadow(
                    color: theme.primaryColor.withOpacity(0.4),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.search, color: Colors.white, size: 20),
          SizedBox(width: 8),
                  Text(
                    'Search This Area',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
  
  Color _getAvailabilityColor(int available, int total) {
    if (available == 0) return const Color(0xFFE53935);
    final ratio = available / total;
    if (ratio <= 0.2) return const Color(0xFFFF9800);
    if (ratio <= 0.5) return const Color(0xFFFFC107);
    return const Color(0xFF4CAF50);
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
    _mapController?.dispose();
    _spotStreamSubscription?.cancel();
    _markerUpdateDebounce?.cancel();
    _searchDebounce?.cancel();
    _searchController.dispose();
    _searchFocusNode.dispose();
    _filterAnimController.dispose();
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
