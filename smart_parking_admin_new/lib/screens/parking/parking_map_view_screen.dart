// lib/screens/parking/parking_map_view_screen.dart
import 'dart:async';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../providers/admin_provider.dart';
import '../../models/parking_spot.dart';
import '../../config/theme.dart';
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
  bool _isMapReady = false;
  bool _isGeneratingMarkers = false;
  
  // Marker icon cache
  final Map<String, BitmapDescriptor> _markerIconCache = {};
  
  // Debouncer for marker updates
  Timer? _markerUpdateDebouncer;
  
  // Track last parking spots to avoid unnecessary updates
  List<String> _lastParkingSpotIds = [];
  Map<String, int> _lastAvailableSpots = {};

  // Default location (Hyderabad, India - adjust as needed)
  static const LatLng _defaultLocation = LatLng(17.3850, 78.4867);
  
  // Stream subscription
  StreamSubscription? _parkingSpotsSubscription;

  @override
  void initState() {
    super.initState();
    _preloadMarkerIcons();
    
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _setupParkingSpotsListener();
    });
  }

  @override
  void dispose() {
    _markerUpdateDebouncer?.cancel();
    _parkingSpotsSubscription?.cancel();
    _mapController?.dispose();
    super.dispose();
  }

  /// Preload marker icons for all statuses
  Future<void> _preloadMarkerIcons() async {
    for (final status in ParkingSpotStatus.values) {
      _markerIconCache[status.name] = _getDefaultMarkerIcon(status);
    }
  }

  /// Setup listener for parking spots changes
  void _setupParkingSpotsListener() {
    final adminProvider = context.read<AdminProvider>();
    
    // Start real-time stream if enabled
    if (adminProvider.isRealTimeEnabled) {
      adminProvider.startParkingSpotsRealTime();
    } else {
      adminProvider.loadParkingSpots(refresh: true);
    }
  }

  void _onMapCreated(GoogleMapController controller) {
    _mapController = controller;
    _isMapReady = true;
    
    // Apply dark mode style if needed
    if (Theme.of(context).brightness == Brightness.dark) {
      _applyDarkMapStyle();
    }
    
    // Initial marker update after map is ready
    _scheduleMarkerUpdate();
  }

  Future<void> _applyDarkMapStyle() async {
    try {
      final style = await rootBundle.loadString('assets/map_style_dark.json');
      await _mapController?.setMapStyle(style);
    } catch (e) {
      // If style file doesn't exist, use default
      debugPrint('Dark map style not found: $e');
    }
  }

  /// Schedule a debounced marker update
  void _scheduleMarkerUpdate() {
    _markerUpdateDebouncer?.cancel();
    _markerUpdateDebouncer = Timer(const Duration(milliseconds: 300), () {
      if (mounted && _isMapReady) {
        _updateMarkersEfficiently();
      }
    });
  }

  /// Efficiently update markers only when necessary
  Future<void> _updateMarkersEfficiently() async {
    if (_isGeneratingMarkers) return;
    
    final adminProvider = context.read<AdminProvider>();
    final parkingSpots = adminProvider.parkingSpots;
    
    if (parkingSpots.isEmpty) {
      if (_markers.isNotEmpty) {
        setState(() => _markers = {});
      }
      return;
    }
    
    // Check if we actually need to update
    final currentIds = parkingSpots.map((s) => s.id).toList();
    final currentAvailable = {for (var s in parkingSpots) s.id: s.availableSpots};
    
    bool needsUpdate = false;
    
    // Check for added/removed spots
    if (currentIds.length != _lastParkingSpotIds.length ||
        !currentIds.every((id) => _lastParkingSpotIds.contains(id))) {
      needsUpdate = true;
    }
    
    // Check for availability changes
    if (!needsUpdate) {
      for (final spot in parkingSpots) {
        if (_lastAvailableSpots[spot.id] != spot.availableSpots) {
          needsUpdate = true;
          break;
        }
      }
    }
    
    if (!needsUpdate && _markers.isNotEmpty) return;
    
    _isGeneratingMarkers = true;
    
    try {
      final Set<Marker> newMarkers = {};
      
      for (final spot in parkingSpots) {
        final icon = _markerIconCache[spot.status.name] ?? 
                     BitmapDescriptor.defaultMarker;
        
        newMarkers.add(
          Marker(
            markerId: MarkerId(spot.id),
            position: LatLng(spot.latitude, spot.longitude),
            icon: icon,
            infoWindow: InfoWindow(
              title: spot.name,
              snippet: '${spot.availableSpots}/${spot.totalSpots} slots • ₹${spot.pricePerHour.toStringAsFixed(0)}/hr',
            ),
            onTap: () => _onMarkerTapped(spot),
          ),
        );
      }
      
      // Update tracking
      _lastParkingSpotIds = currentIds;
      _lastAvailableSpots = currentAvailable;
      
      if (mounted) {
        setState(() => _markers = newMarkers);
        
        // Move camera to show all markers on first load
        if (_markers.isNotEmpty && _lastParkingSpotIds.isEmpty) {
          _fitBoundsToMarkers(parkingSpots);
        }
      }
    } finally {
      _isGeneratingMarkers = false;
    }
  }

  /// Fit camera to show all parking spots
  Future<void> _fitBoundsToMarkers(List<ParkingSpot> spots) async {
    if (spots.isEmpty || _mapController == null) return;
    
    if (spots.length == 1) {
      await _mapController?.animateCamera(
        CameraUpdate.newLatLngZoom(
          LatLng(spots.first.latitude, spots.first.longitude),
          15.0,
        ),
      );
      return;
    }
    
    double minLat = spots.first.latitude;
    double maxLat = spots.first.latitude;
    double minLng = spots.first.longitude;
    double maxLng = spots.first.longitude;
    
    for (final spot in spots) {
      if (spot.latitude < minLat) minLat = spot.latitude;
      if (spot.latitude > maxLat) maxLat = spot.latitude;
      if (spot.longitude < minLng) minLng = spot.longitude;
      if (spot.longitude > maxLng) maxLng = spot.longitude;
    }
    
    final bounds = LatLngBounds(
      southwest: LatLng(minLat - 0.01, minLng - 0.01),
      northeast: LatLng(maxLat + 0.01, maxLng + 0.01),
    );
    
    await _mapController?.animateCamera(
      CameraUpdate.newLatLngBounds(bounds, 50),
    );
  }

  BitmapDescriptor _getDefaultMarkerIcon(ParkingSpotStatus status) {
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

  void _onMarkerTapped(ParkingSpot spot) {
    setState(() => _selectedParkingSpot = spot);
    _showParkingSpotBottomSheet(spot);
  }

  void _showParkingSpotBottomSheet(ParkingSpot spot) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _ParkingSpotDetailSheet(
        spot: spot,
        isDark: isDark,
        onEdit: () {
          Navigator.pop(context);
          _showEditParkingSpotDialog(spot);
        },
        onDelete: () {
          Navigator.pop(context);
          _deleteParkingSpot(spot);
        },
        onNavigate: () {
          Navigator.pop(context);
          _navigateToSpot(spot);
        },
      ),
    );
  }

  void _navigateToSpot(ParkingSpot spot) {
    _mapController?.animateCamera(
      CameraUpdate.newLatLngZoom(
        LatLng(spot.latitude, spot.longitude),
        17.0,
      ),
    );
  }

  void _showAddParkingSpotDialog() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const AddParkingSpotScreen()),
    );
    // Real-time stream will auto-update
  }

  void _showEditParkingSpotDialog(ParkingSpot parkingSpot) {
    showDialog(
      context: context,
      builder: (context) => EditParkingSpotDialog(parkingSpot: parkingSpot),
    );
  }

  void _deleteParkingSpot(ParkingSpot spot) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'Delete Parking Spot',
          style: TextStyle(color: isDark ? Colors.white : null),
        ),
        content: Text(
          'Are you sure you want to delete "${spot.name}"?',
          style: TextStyle(color: isDark ? const Color(0xFF8B949E) : null),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              await context.read<AdminProvider>().deleteParkingSpot(spot.id);
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: const Text('Parking spot deleted'),
                    backgroundColor: isDark ? AppTheme.neonGreen : AppTheme.successColor,
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: isDark ? AppTheme.neonPink : Colors.red,
              foregroundColor: isDark ? const Color(0xFF0D1117) : Colors.white,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Scaffold(
      appBar: _buildAppBar(isDark),
      drawer: const AdminDrawer(),
      body: Consumer<AdminProvider>(
        builder: (context, adminProvider, child) {
          // Schedule marker update when data changes
          // Using addPostFrameCallback to avoid build-time setState
          if (_isMapReady && !_isGeneratingMarkers) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              _scheduleMarkerUpdate();
            });
          }
          
          return Column(
            children: [
              _buildStatsBar(adminProvider, isDark),
              _buildLegend(isDark),
              Expanded(
                child: Stack(
                  children: [
                    _buildMap(adminProvider, isDark),
                    if (adminProvider.parkingSpotsLoading)
                      _buildLoadingOverlay(isDark),
                    _buildZoomControls(isDark),
                  ],
                ),
              ),
            ],
          );
        },
      ),
      floatingActionButton: _buildFAB(isDark),
    );
  }

  PreferredSizeWidget _buildAppBar(bool isDark) {
    return AppBar(
      title: Row(
        children: [
          if (isDark) ...[
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    AppTheme.neonBlue.withOpacity(0.3),
                    AppTheme.neonCyan.withOpacity(0.3),
                  ],
                ),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(Icons.map_rounded, color: AppTheme.neonBlue, size: 22),
            ),
            const SizedBox(width: 12),
          ],
          Text(
            'Parking Map',
            style: TextStyle(
              color: isDark ? AppTheme.neonBlue : null,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
      actions: [
        Consumer<AdminProvider>(
          builder: (context, provider, _) => IconButton(
            icon: Icon(
              provider.isRealTimeEnabled ? Icons.sync : Icons.sync_disabled,
              color: provider.isRealTimeEnabled ? AppTheme.neonGreen : Colors.grey,
            ),
            onPressed: () {
              provider.toggleRealTimeMode(!provider.isRealTimeEnabled);
              if (provider.isRealTimeEnabled) {
                provider.startParkingSpotsRealTime();
              }
            },
            tooltip: provider.isRealTimeEnabled ? 'Real-time ON' : 'Real-time OFF',
          ),
        ),
        IconButton(
          icon: const Icon(Icons.refresh_rounded),
          onPressed: () {
            final provider = context.read<AdminProvider>();
            if (provider.isRealTimeEnabled) {
              provider.startParkingSpotsRealTime();
            } else {
              provider.loadParkingSpots(refresh: true);
            }
          },
          tooltip: 'Refresh',
        ),
        IconButton(
          icon: const Icon(Icons.center_focus_strong_rounded),
          onPressed: () => _fitBoundsToMarkers(context.read<AdminProvider>().parkingSpots),
          tooltip: 'Fit All',
        ),
      ],
    );
  }

  Widget _buildStatsBar(AdminProvider adminProvider, bool isDark) {
    final spots = adminProvider.parkingSpots;
    final total = spots.length;
    final available = spots.where((s) => s.status == ParkingSpotStatus.available).length;
    final totalSlots = spots.fold<int>(0, (sum, s) => sum + s.totalSpots);
    final availableSlots = spots.fold<int>(0, (sum, s) => sum + s.availableSpots);
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF161B22) : Colors.white,
        border: Border(
          bottom: BorderSide(
            color: isDark ? const Color(0xFF30363D) : const Color(0xFFE2E8F0),
          ),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildMiniStat('Locations', total.toString(), 
              isDark ? AppTheme.neonBlue : AppTheme.primaryColor, isDark),
          _buildMiniStat('Available', '$available / $total', 
              isDark ? AppTheme.neonGreen : AppTheme.successColor, isDark),
          _buildMiniStat('Total Slots', totalSlots.toString(), 
              isDark ? AppTheme.neonPurple : AppTheme.accentColor, isDark),
          _buildMiniStat('Free Slots', availableSlots.toString(), 
              isDark ? AppTheme.neonOrange : AppTheme.warningColor, isDark),
        ],
      ),
    );
  }

  Widget _buildMiniStat(String label, String value, Color color, bool isDark) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: color,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: isDark ? const Color(0xFF8B949E) : Colors.grey[600],
          ),
        ),
      ],
    );
  }

  Widget _buildLegend(bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0D1117) : const Color(0xFFF8FAFC),
        border: Border(
          bottom: BorderSide(
            color: isDark ? const Color(0xFF30363D) : const Color(0xFFE2E8F0),
          ),
        ),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            _buildLegendItem('Available', Colors.green, isDark),
            _buildLegendItem('Occupied', Colors.red, isDark),
            _buildLegendItem('Maintenance', Colors.orange, isDark),
            _buildLegendItem('Reserved', Colors.blue, isDark),
            _buildLegendItem('Closed', Colors.grey, isDark),
          ],
        ),
      ),
    );
  }

  Widget _buildLegendItem(String label, Color color, bool isDark) {
    return Container(
      margin: const EdgeInsets.only(right: 16),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              boxShadow: isDark ? [
                BoxShadow(
                  color: color.withOpacity(0.5),
                  blurRadius: 4,
                  spreadRadius: 1,
                ),
              ] : null,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: isDark ? const Color(0xFF8B949E) : Colors.grey[700],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMap(AdminProvider adminProvider, bool isDark) {
    // Get initial position from first parking spot or use default
    LatLng initialPosition = _defaultLocation;
    if (adminProvider.parkingSpots.isNotEmpty) {
      final first = adminProvider.parkingSpots.first;
      initialPosition = LatLng(first.latitude, first.longitude);
    }
    
    return GoogleMap(
      onMapCreated: _onMapCreated,
      initialCameraPosition: CameraPosition(
        target: initialPosition,
        zoom: 12.0,
      ),
      markers: _markers,
      myLocationEnabled: true,
      myLocationButtonEnabled: false,
      mapType: MapType.normal,
      zoomControlsEnabled: false,
      compassEnabled: true,
      mapToolbarEnabled: false,
      buildingsEnabled: true,
      liteModeEnabled: false,
    );
  }

  Widget _buildLoadingOverlay(bool isDark) {
    return Positioned.fill(
      child: Container(
        color: (isDark ? Colors.black : Colors.white).withOpacity(0.5),
        child: Center(
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF21262D) : Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.2),
                  blurRadius: 20,
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation(
                    isDark ? AppTheme.neonBlue : AppTheme.primaryColor,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Loading parking spots...',
                  style: TextStyle(
                    color: isDark ? Colors.white : null,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildZoomControls(bool isDark) {
    return Positioned(
      right: 16,
      bottom: 100,
      child: Column(
        children: [
          _buildZoomButton(Icons.add, () {
            _mapController?.animateCamera(CameraUpdate.zoomIn());
          }, isDark),
          const SizedBox(height: 8),
          _buildZoomButton(Icons.remove, () {
            _mapController?.animateCamera(CameraUpdate.zoomOut());
          }, isDark),
          const SizedBox(height: 8),
          _buildZoomButton(Icons.my_location, () async {
            _fitBoundsToMarkers(context.read<AdminProvider>().parkingSpots);
          }, isDark),
        ],
      ),
    );
  }

  Widget _buildZoomButton(IconData icon, VoidCallback onTap, bool isDark) {
    return Material(
      color: isDark ? const Color(0xFF21262D) : Colors.white,
      elevation: 4,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isDark ? const Color(0xFF30363D) : const Color(0xFFE2E8F0),
            ),
          ),
          child: Icon(
            icon,
            color: isDark ? AppTheme.neonBlue : AppTheme.primaryColor,
          ),
        ),
      ),
    );
  }

  Widget _buildFAB(bool isDark) {
    return Container(
      decoration: isDark
          ? BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: AppTheme.neonGreen.withOpacity(0.4),
                  blurRadius: 20,
                  spreadRadius: 2,
                ),
              ],
            )
          : null,
      child: FloatingActionButton.extended(
        onPressed: _showAddParkingSpotDialog,
        icon: const Icon(Icons.add_location_alt_rounded),
        label: const Text('Add Spot'),
        backgroundColor: isDark ? AppTheme.neonGreen : null,
        foregroundColor: isDark ? const Color(0xFF0D1117) : null,
      ),
    );
  }
}

/// Bottom sheet for parking spot details
class _ParkingSpotDetailSheet extends StatelessWidget {
  final ParkingSpot spot;
  final bool isDark;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onNavigate;

  const _ParkingSpotDetailSheet({
    required this.spot,
    required this.isDark,
    required this.onEdit,
    required this.onDelete,
    required this.onNavigate,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF161B22) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        border: isDark
            ? Border.all(color: const Color(0xFF30363D))
            : null,
      ),
      child: DraggableScrollableSheet(
        initialChildSize: 0.45,
        minChildSize: 0.25,
        maxChildSize: 0.85,
        expand: false,
        builder: (context, scrollController) => SingleChildScrollView(
          controller: scrollController,
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Handle bar
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF30363D) : Colors.grey[300],
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                
                // Header
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: (isDark ? AppTheme.neonBlue : AppTheme.primaryColor)
                                  .withOpacity(0.1),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              spot.id,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: isDark ? AppTheme.neonBlue : AppTheme.primaryColor,
                                fontFamily: 'monospace',
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            spot.name,
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w700,
                              color: isDark ? Colors.white : null,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Icon(
                                Icons.location_on_outlined,
                                size: 14,
                                color: isDark ? const Color(0xFF8B949E) : Colors.grey[600],
                              ),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  spot.address,
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: isDark ? const Color(0xFF8B949E) : Colors.grey[600],
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 16),
                    _buildStatusBadge(),
                  ],
                ),
                const SizedBox(height: 20),
                
                // Stats row
                Row(
                  children: [
                    _buildStatChip(Icons.local_parking_rounded, 
                        '${spot.availableSpots}/${spot.totalSpots}', 'Slots',
                        isDark ? AppTheme.neonBlue : AppTheme.primaryColor),
                    const SizedBox(width: 12),
                    _buildStatChip(Icons.currency_rupee_rounded, 
                        '₹${spot.pricePerHour.toStringAsFixed(0)}/hr', 'Price',
                        isDark ? AppTheme.neonGreen : AppTheme.successColor),
                    const SizedBox(width: 12),
                    _buildStatChip(Icons.star_rounded, 
                        spot.rating.toStringAsFixed(1), 'Rating',
                        isDark ? AppTheme.neonOrange : AppTheme.warningColor),
                  ],
                ),
                const SizedBox(height: 20),
                
                // Description
                if (spot.description.isNotEmpty) ...[
                  Text(
                    'Description',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white : null,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    spot.description,
                    style: TextStyle(
                      fontSize: 13,
                      color: isDark ? const Color(0xFF8B949E) : Colors.grey[700],
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
                
                // Amenities
                if (spot.amenities.isNotEmpty) ...[
                  Text(
                    'Amenities',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white : null,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: spot.amenities.map((amenity) => Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: (isDark ? AppTheme.neonPurple : AppTheme.accentColor)
                            .withOpacity(0.1),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: (isDark ? AppTheme.neonPurple : AppTheme.accentColor)
                              .withOpacity(0.3),
                        ),
                      ),
                      child: Text(
                        amenity,
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark ? AppTheme.neonPurple : AppTheme.accentColor,
                        ),
                      ),
                    )).toList(),
                  ),
                  const SizedBox(height: 20),
                ],
                
                // Actions
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: onNavigate,
                        icon: const Icon(Icons.center_focus_strong_rounded, size: 18),
                        label: const Text('Focus'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: isDark ? AppTheme.neonBlue : AppTheme.primaryColor,
                          foregroundColor: isDark ? const Color(0xFF0D1117) : Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: onEdit,
                        icon: const Icon(Icons.edit_rounded, size: 18),
                        label: const Text('Edit'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: isDark ? AppTheme.neonGreen : AppTheme.successColor,
                          side: BorderSide(
                            color: (isDark ? AppTheme.neonGreen : AppTheme.successColor)
                                .withOpacity(0.5),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      onPressed: onDelete,
                      icon: Icon(
                        Icons.delete_rounded,
                        color: isDark ? AppTheme.neonPink : Colors.red,
                      ),
                      style: IconButton.styleFrom(
                        backgroundColor: (isDark ? AppTheme.neonPink : Colors.red)
                            .withOpacity(0.1),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
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

  Widget _buildStatusBadge() {
    final color = AppTheme.getParkingSpotStatusColor(spot.status.name);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(isDark ? 0.2 : 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.5)),
        boxShadow: isDark ? [
          BoxShadow(
            color: color.withOpacity(0.3),
            blurRadius: 10,
            spreadRadius: 0,
          ),
        ] : null,
      ),
      child: Text(
        spot.status.name.toUpperCase(),
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 1,
        ),
      ),
    );
  }

  Widget _buildStatChip(IconData icon, String value, String label, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: color.withOpacity(isDark ? 0.1 : 0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.2)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(height: 6),
            Text(
              value,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: isDark ? Colors.white : color,
              ),
            ),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                color: isDark ? const Color(0xFF8B949E) : Colors.grey[600],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
