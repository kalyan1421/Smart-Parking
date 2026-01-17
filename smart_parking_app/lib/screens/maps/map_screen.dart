// lib/screens/maps/map_screen.dart - Fully updated with fixed traffic provider integration
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:provider/provider.dart';
import 'package:smart_parking_app/config/constants.dart';
import 'package:smart_parking_app/config/routes.dart';
import 'package:smart_parking_app/models/traffic_bot.dart';
import 'package:smart_parking_app/models/route_option.dart';
import 'package:smart_parking_app/providers/location_provider.dart';
import 'package:smart_parking_app/providers/parking_provider.dart';
import 'package:smart_parking_app/providers/traffic_provider.dart';
import 'package:smart_parking_app/providers/routing_provider.dart';
import 'package:smart_parking_app/screens/maps/route_options_sheet.dart';
import 'package:smart_parking_app/screens/maps/navigation_screen.dart';
import 'package:smart_parking_app/widgets/common/loading_indicator.dart';

class MapScreen extends StatefulWidget {
  @override
  _MapScreenState createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  GoogleMapController? _mapController;
  Set<Marker> _markers = {};
  Set<Circle> _trafficBots = {};
  Set<Polyline> _routes = {};
  bool _isLoading = false;
  bool _isRoutingMode = false;
  LatLng? _destinationLocation;
  Timer? _trafficUpdateTimer;
  
  @override
  void initState() {
    super.initState();
    
    // Initialize traffic provider safely after the frame is built
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final trafficProvider = Provider.of<TrafficProvider>(context, listen: false);
      trafficProvider.initializeTrafficOverlay();
      _loadParkingAreas();
      _startTrafficUpdates();
    });
  }
  
  @override
  void dispose() {
    _trafficUpdateTimer?.cancel();
    _mapController?.dispose();
    super.dispose();
  }
  
  // Start periodic traffic updates (only when not in routing mode)
  void _startTrafficUpdates() {
    // Update traffic every 30 seconds
    _trafficUpdateTimer = Timer.periodic(Duration(seconds: 30), (_) {
      if (!_isRoutingMode) {
        _updateTrafficBots();
      }
    });
    // Initial load
    _updateTrafficBots();
  }
  
  // Load and display traffic bots on map
  Future<void> _updateTrafficBots() async {
    if (_isRoutingMode) return; // Skip traffic updates when in routing mode
    
    try {
      final trafficProvider = Provider.of<TrafficProvider>(context, listen: false);
      final locationProvider = Provider.of<LocationProvider>(context, listen: false);
      
      await trafficProvider.loadTrafficData(
        locationProvider.latitude,
        locationProvider.longitude,
        8.0 // 8 km radius for traffic data
      );
      
      _createTrafficBots();
    } catch (e) {
      print('Error updating traffic data: $e');
    }
  }
  
  // Create traffic bot visualizations as colored circles with improved visibility
  void _createTrafficBots() {
    if (_isRoutingMode) {
      setState(() {
        _trafficBots = {}; // Clear traffic bots in routing mode
      });
      return;
    }
    
    final trafficProvider = Provider.of<TrafficProvider>(context, listen: false);
    final Set<Circle> trafficBots = {};
    
    for (final bot in trafficProvider.trafficBots) {
      // Determine color based on traffic level
      Color botColor;
      switch (bot.trafficLevel) {
        case TrafficLevel.low:
          botColor = Colors.green;
          break;
        case TrafficLevel.medium:
          botColor = Colors.orange;
          break;
        case TrafficLevel.high:
          botColor = Colors.red;
          break;
        case TrafficLevel.severe:
          botColor = Colors.purple;
          break;
        default:
          botColor = Colors.blue;
      }
      
      // Make traffic dots larger and more visible
      final circle = Circle(
        circleId: CircleId(bot.id),
        center: LatLng(bot.latitude, bot.longitude),
        radius: 80.0, // Increased radius for better visibility
        fillColor: botColor.withOpacity(0.7), // Increased opacity
        strokeColor: botColor,
        strokeWidth: 20, // Increased stroke width
        visible: true, // Ensure visibility
        zIndex: 1, // Higher z-index to appear above other map elements
      );
      
      trafficBots.add(circle);
    }
    
    setState(() {
      _trafficBots = trafficBots;
    });
  }
  
  Future<void> _loadParkingAreas() async {
    setState(() {
      _isLoading = true;
    });
    
    try {
      final locationProvider = Provider.of<LocationProvider>(context, listen: false);
      final parkingProvider = Provider.of<ParkingProvider>(context, listen: false);
      
      if (!locationProvider.hasLocation) {
        await locationProvider.getCurrentLocation();
      }
      
      // Load nearby parking spots and reflect them on the map
      await parkingProvider.loadParkingSpotsNear(
        locationProvider.latitude,
        locationProvider.longitude,
        radius: AppConstants.defaultSearchRadius,
      );
      
      _createMarkers();
    } catch (e) {
      print('Error loading parking areas: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }
  
  void _createMarkers() {
    final parkingProvider = Provider.of<ParkingProvider>(context, listen: false);
    final locationProvider = Provider.of<LocationProvider>(context, listen: false);
    
    if (_isRoutingMode && _destinationLocation != null) {
      // In routing mode, show only destination marker
      setState(() {
        _markers = {
          Marker(
            markerId: MarkerId('destination'),
            position: _destinationLocation!,
            icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
          ),
          if (locationProvider.hasLocation)
            Marker(
              markerId: MarkerId('origin'),
              position: LatLng(locationProvider.latitude, locationProvider.longitude),
              icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
              infoWindow: InfoWindow(title: 'You'),
            ),
        };
      });
      return;
    }
    
    final Set<Marker> markers = {};
    
    for (final spot in parkingProvider.parkingSpots) {
      // Color markers based on availability
      final hue = spot.availableSpots <= 0
          ? BitmapDescriptor.hueRed
          : spot.availableSpots <= 2
              ? BitmapDescriptor.hueOrange
              : BitmapDescriptor.hueGreen;
      
      markers.add(Marker(
        markerId: MarkerId(spot.id),
        position: LatLng(spot.latitude, spot.longitude),
        icon: BitmapDescriptor.defaultMarkerWithHue(hue),
        infoWindow: InfoWindow(
          title: spot.name,
          snippet: '${spot.availableSpots}/${spot.totalSpots} available',
        ),
      ));
    }
    
    // Mark user location for context
    if (locationProvider.hasLocation) {
      markers.add(
        Marker(
          markerId: MarkerId('user_location'),
          position: LatLng(locationProvider.latitude, locationProvider.longitude),
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
          infoWindow: InfoWindow(title: 'You are here'),
        ),
      );
    }
    
    setState(() {
      _markers = markers;
    });
  }
  
  // Create polylines for routes with colors based on traffic with better differentiation
  void _createRoutePolylines(List<RouteOption> routeOptions) {
    final Set<Polyline> routes = {};
    
    // Define base colors for different traffic levels
    const Map<TrafficLevel, Color> trafficBaseColors = {
      TrafficLevel.low: Colors.green,
      TrafficLevel.medium: Colors.orange,
      TrafficLevel.high: Colors.red,
      TrafficLevel.severe: Colors.purple,
    };
    
    // Count routes by traffic level to determine shade variations
    Map<TrafficLevel, int> trafficLevelCounts = {};
    for (final route in routeOptions) {
      trafficLevelCounts[route.trafficLevel] = (trafficLevelCounts[route.trafficLevel] ?? 0) + 1;
    }
    
    // Create shades for each traffic level
    Map<TrafficLevel, List<Color>> trafficColorShades = {};
    for (final trafficLevel in trafficLevelCounts.keys) {
      final baseColor = trafficBaseColors[trafficLevel] ?? Colors.blue;
      final count = trafficLevelCounts[trafficLevel] ?? 1;
      
      // Generate different shades for each route with the same traffic level
      if (count == 1) {
        trafficColorShades[trafficLevel] = [baseColor];
      } else {
        final List<Color> shades = [];
        
        // Create lighter and darker shades for the base color
        final HSLColor hslColor = HSLColor.fromColor(baseColor);
        
        for (int i = 0; i < count; i++) {
          // Adjust lightness to create different shades
          // For lighter shades: increase lightness
          // For darker shades: decrease lightness
          double lightnessAdjustment = (i - (count - 1) / 2) * 0.15;
          double newLightness = (hslColor.lightness + lightnessAdjustment).clamp(0.2, 0.8);
          
          shades.add(hslColor.withLightness(newLightness).toColor());
        }
        
        trafficColorShades[trafficLevel] = shades;
      }
    }
    
    // Keep track of how many routes of each traffic level have been processed
    Map<TrafficLevel, int> processedCounts = {};
    
    for (int i = 0; i < routeOptions.length; i++) {
      final route = routeOptions[i];
      final trafficLevel = route.trafficLevel;
      
      // Get the correct shade for this route
      int shadeIndex = processedCounts[trafficLevel] ?? 0;
      processedCounts[trafficLevel] = shadeIndex + 1;
      
      final shades = trafficColorShades[trafficLevel] ?? [trafficBaseColors[trafficLevel] ?? Colors.blue];
      final routeColor = shades[shadeIndex % shades.length];
      
      final polyline = Polyline(
        polylineId: PolylineId('route_$i'),
        points: route.points,
        color: routeColor,
        width: 6, // Make routes more visible
        patterns: [
          if (i == 0) PatternItem.dash(20), // Make the fastest route dashed for distinction
        ],
      );
      
      routes.add(polyline);
    }
    
    setState(() {
      _routes = routes;
    });
  }
  
  // Show route options in bottom sheet
  void _showRouteOptionsSheet(List<RouteOption> routeOptions) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      isDismissible: false, // Prevent dismissing by dragging down
      enableDrag: false, // Disable dragging
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => RouteOptionsSheet(
        routeOptions: routeOptions,
        onRouteSelected: (route) {
          // Keep sheet open, just highlight the selected route
          _selectRoute(route);
        },
        onCancel: () {
          Navigator.pop(context);
          _cancelRouting();
        },
        destination: _destinationLocation!, // Pass the destination
      ),
    );
  }
  
  // Handle route selection
  void _selectRoute(RouteOption route) {
    final routingProvider = Provider.of<RoutingProvider>(context, listen: false);
    routingProvider.selectRoute(route);
    
    // Zoom to show the selected route
    _fitRoute(route.points);
  }
  
  // Cancel routing mode
  void _cancelRouting() {
    // Exit routing mode
    setState(() {
      _isRoutingMode = false;
      _destinationLocation = null;
      _routes = {};
    });
    
    // Reload normal map elements
    _loadParkingAreas();
    _updateTrafficBots();
  }
  
  // Fit map to show the entire route
  void _fitRoute(List<LatLng> points) {
    if (_mapController == null || points.isEmpty) return;
    
    final bounds = _calculateBounds(points);
    _mapController!.animateCamera(
      CameraUpdate.newLatLngBounds(bounds, 80), // Increased padding
    );
  }
  
  // Fit map to show all available routes
  void _fitAllRoutes(List<RouteOption> routes) {
    if (_mapController == null || routes.isEmpty) return;
    
    // Collect all points from all routes
    List<LatLng> allPoints = [];
    for (final route in routes) {
      allPoints.addAll(route.points);
    }
    
    final bounds = _calculateBounds(allPoints);
    _mapController!.animateCamera(
      CameraUpdate.newLatLngBounds(bounds, 80), // Increased padding
    );
  }
  
  // Calculate bounds for a list of points
  LatLngBounds _calculateBounds(List<LatLng> points) {
    double? minLat, maxLat, minLng, maxLng;
    
    for (final point in points) {
      minLat = minLat == null ? point.latitude : min(minLat, point.latitude);
      maxLat = maxLat == null ? point.latitude : max(maxLat, point.latitude);
      minLng = minLng == null ? point.longitude : min(minLng, point.longitude);
      maxLng = maxLng == null ? point.longitude : max(maxLng, point.longitude);
    }
    
    return LatLngBounds(
      southwest: LatLng(minLat!, minLng!),
      northeast: LatLng(maxLat!, maxLng!),
    );
  }
  
  void _onMapCreated(GoogleMapController controller) {
    _mapController = controller;
    _centerOnUser();
  }
  
  Future<void> _centerOnUser() async {
    if (_mapController != null) {
      final locationProvider = Provider.of<LocationProvider>(context, listen: false);
      
      if (locationProvider.hasLocation) {
        _mapController!.animateCamera(
          CameraUpdate.newCameraPosition(
            CameraPosition(
              target: LatLng(
                locationProvider.latitude,
                locationProvider.longitude,
              ),
              zoom: 15.0,
            ),
          ),
        );
      }
    }
  }
  
  // Calculate the minimum value between two numbers
  double min(double a, double b) => a < b ? a : b;
  
  // Calculate the maximum value between two numbers
  double max(double a, double b) => a > b ? a : b;
  
  @override
  Widget build(BuildContext context) {
    final locationProvider = Provider.of<LocationProvider>(context);
    final trafficProvider = Provider.of<TrafficProvider>(context);
    
    // Ensure traffic overlay is set up (without notifying)
    if (!trafficProvider.isOverlaySetup) {
      trafficProvider.setupTrafficOverlay();
    }
    
    // Prepare tile overlays
    Set<TileOverlay> tileOverlays = {};
    if (trafficProvider.isOverlaySetup && 
        trafficProvider.trafficOverlay != null &&
        !_isRoutingMode && 
        trafficProvider.showTrafficLayer) {
      tileOverlays = {trafficProvider.trafficOverlay!};
    }
    
    return Scaffold(
      appBar: AppBar(
        title: Text(_isRoutingMode ? 'Navigation' : 'Find Parking'),
        actions: [
          // Traffic toggle button (only shown when not in routing mode)
          if (!_isRoutingMode)
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
            onPressed: () {
              if (_isRoutingMode) {
                // Refresh routes
                if (_destinationLocation != null) {
                  _findRoutesToDestination();
                }
              } else {
                // Refresh parking areas and traffic
                _loadParkingAreas();
                _updateTrafficBots();
              }
            },
          ),
          if (_isRoutingMode)
            IconButton(
              icon: Icon(Icons.close),
              onPressed: _cancelRouting,
            ),
        ],
      ),
      body: Stack(
        children: [
          // Map
          GoogleMap(
            initialCameraPosition: CameraPosition(
              target: LatLng(
                locationProvider.latitude,
                locationProvider.longitude,
              ),
              zoom: 15.0,
            ),
            onMapCreated: _onMapCreated,
            myLocationEnabled: true,
            myLocationButtonEnabled: true,
            markers: _markers,
            circles: _trafficBots, // Add traffic bots (will be empty in routing mode)
            polylines: _routes, // Add routes
            tileOverlays: tileOverlays,
            trafficEnabled: false, // Use our custom traffic layer via tileOverlays
            mapToolbarEnabled: false,
            zoomControlsEnabled: false,
            compassEnabled: true,
            onTap: _isRoutingMode ? (location) {
              // In routing mode, tapping the map selects a new destination
              setState(() {
                _destinationLocation = location;
                _markers = {
                  // Origin marker
                  Marker(
                    markerId: MarkerId('origin'),
                    position: LatLng(
                      locationProvider.latitude,
                      locationProvider.longitude,
                    ),
                    icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
                  ),
                  // Destination marker
                  Marker(
                    markerId: MarkerId('destination'),
                    position: location,
                    icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
                  ),
                };
              });
            } : null,
          ),
          
          // Loading indicator
          if (_isLoading)
            Container(
              color: Colors.black.withOpacity(0.3),
              child: Center(
                child: LoadingIndicator(),
              ),
            ),
          
          // Search bar
          if (!_isRoutingMode) // Hide search bar in routing mode
            Positioned(
              top: 16,
              left: 16,
              right: 16,
              child: Card(
                elevation: 4,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: InkWell(
                  onTap: () {
                    // TODO: Navigate to search screen
                  },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    child: Row(
                      children: [
                        Icon(Icons.search),
                        SizedBox(width: 12),
                        Text(
                          'Search for parking locations',
                          style: TextStyle(color: Colors.grey[600]),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          
          // Traffic legend - only show when not in routing mode
          if (!_isRoutingMode)
            Positioned(
              left: 16,
              bottom: 200,
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
                      Text('Traffic:', style: TextStyle(fontWeight: FontWeight.bold)),
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
          
          // Route legend - only show in routing mode
          if (_isRoutingMode)
            Positioned(
              left: 16,
              bottom: 150,
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
                      Text('Routes:', style: TextStyle(fontWeight: FontWeight.bold)),
                      SizedBox(height: 4),
                      _legendItem(Colors.green, 'Low Traffic'),
                      _legendItem(Colors.orange, 'Medium Traffic'),
                      _legendItem(Colors.red, 'Heavy Traffic'),
                      Padding(
                        padding: const EdgeInsets.only(top: 4.0),
                        child: Row(
                          children: [
                            Container(
                              width: 24,
                              height: 2,
                              color: Colors.black,
                              child: Stack(
                                children: [
                                  Positioned(
                                    left: 4,
                                    top: 0,
                                    child: Container(width: 2, height: 2, color: Colors.white),
                                  ),
                                  Positioned(
                                    left: 12,
                                    top: 0,
                                    child: Container(width: 2, height: 2, color: Colors.white),
                                  ),
                                  Positioned(
                                    left: 20,
                                    top: 0,
                                    child: Container(width: 2, height: 2, color: Colors.white),
                                  ),
                                ],
                              ),
                            ),
                            SizedBox(width: 8),
                            Text('Fastest Route'),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          
          // Center on user button
          Positioned(
            right: 16,
            bottom: 110,
            child: FloatingActionButton(
              heroTag: 'centerOnUser',
              mini: true,
              backgroundColor: Colors.white,
              onPressed: _centerOnUser,
              child: Icon(
                Icons.my_location,
                color: Theme.of(context).primaryColor,
              ),
            ),
          ),
          
          // Route button (only shown when not in routing mode)
          if (!_isRoutingMode)
            Positioned(
              right: 16,
              bottom: 170,
              child: FloatingActionButton(
                heroTag: 'startRouting',
                mini: true,
                backgroundColor: Colors.white,
                onPressed: () {
                  // Enter routing mode and hide traffic
                  setState(() {
                    _isRoutingMode = true;
                    _trafficBots = {}; // Clear traffic bots
                  });
                  
                  // Toggle off traffic layer in routing mode
                  if (trafficProvider.showTrafficLayer) {
                    trafficProvider.updateOverlayVisibility(false);
                  }
                  
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Tap on the map to select a destination')),
                  );
                },
                child: Icon(
                  Icons.directions,
                  color: Theme.of(context).primaryColor,
                ),
              ),
            ),
          
          // Find routes button (only shown in routing mode with destination selected)
          if (_isRoutingMode && _destinationLocation != null)
            Positioned(
              bottom: 24,
              left: 24,
              right: 24,
              child: ElevatedButton(
                onPressed: () {
                  // Find routes to selected destination
                  _findRoutesToDestination();
                },
                style: ElevatedButton.styleFrom(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                ),
                child: Text(
                  'Find Routes',
                  style: TextStyle(fontSize: 16),
                ),
              ),
            ),
        ],
      ),
      floatingActionButton: _isRoutingMode ? null : FloatingActionButton.extended(
        onPressed: () {
          Navigator.pushNamed(context, AppRoutes.parkingList);
        },
        label: Text('List View'),
        icon: Icon(Icons.list),
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
  
  // Method to find routes to manually selected destination
  Future<void> _findRoutesToDestination() async {
    if (_destinationLocation == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Please select a destination first')),
      );
      return;
    }
    
    setState(() {
      _isLoading = true;
      _routes = {}; // Clear existing routes
    });
    
    try {
      final locationProvider = Provider.of<LocationProvider>(context, listen: false);
      final routingProvider = Provider.of<RoutingProvider>(context, listen: false);
      
      if (!locationProvider.hasLocation) {
        await locationProvider.getCurrentLocation();
      }
      
      final currentLocation = LatLng(
        locationProvider.latitude,
        locationProvider.longitude,
      );
      
      await routingProvider.findRoutes(
        origin: currentLocation,
        destination: _destinationLocation!,
      );
      
      // Update markers for origin and destination
      setState(() {
        _markers = {
          // Origin marker
          Marker(
            markerId: MarkerId('origin'),
            position: currentLocation,
            icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
          ),
          // Destination marker
          Marker(
            markerId: MarkerId('destination'),
            position: _destinationLocation!,
            icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
          ),
        };
      });
      
      _createRoutePolylines(routingProvider.routeOptions);
      
      // Show route options sheet
      _showRouteOptionsSheet(routingProvider.routeOptions);
      
      // Fit map to show all routes
      if (routingProvider.routeOptions.isNotEmpty) {
        _fitAllRoutes(routingProvider.routeOptions);
      }
      
    } catch (e) {
      print('Error finding routes: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to find routes. Please try again.')),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }
}
