// lib/screens/maps/navigation_screen.dart
import 'dart:async';
import 'dart:math' as math;
// import 'dart:math';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:provider/provider.dart';
import 'package:smart_parking_app/config/constants.dart';
import 'package:smart_parking_app/models/route_option.dart';
import 'package:smart_parking_app/models/traffic_bot.dart';
import 'package:smart_parking_app/providers/location_provider.dart';
import 'package:smart_parking_app/widgets/common/loading_indicator.dart';

class NavigationScreen extends StatefulWidget {
  final RouteOption selectedRoute;
  final LatLng origin;
  final LatLng destination;

  const NavigationScreen({
    Key? key,
    required this.selectedRoute,
    required this.origin,
    required this.destination,
  }) : super(key: key);

  @override
  _NavigationScreenState createState() => _NavigationScreenState();
}

class _NavigationScreenState extends State<NavigationScreen> {
  GoogleMapController? _mapController;
  bool _isLoading = true;
  int _currentStep = 0;
  Timer? _navigationTimer;
  double _remainingDistanceKm = 0;
  int _remainingTimeMinutes = 0;
  bool _showRecenterPrompt = false;
  
  // Mock navigation steps
  late List<Map<String, dynamic>> _navigationSteps;
  
  @override
  void initState() {
    super.initState();
    _remainingDistanceKm = widget.selectedRoute.distanceKm;
    _remainingTimeMinutes = widget.selectedRoute.durationMinutes;
    _generateNavigationSteps();
    _startNavigation();
  }
  
  @override
  void dispose() {
    _navigationTimer?.cancel();
    _mapController?.dispose();
    super.dispose();
  }
  
  // Generate mock turn-by-turn instructions based on route
  void _generateNavigationSteps() {
    _navigationSteps = [];
    final points = widget.selectedRoute.points;
    
    if (points.length < 2) return;
    
    // Start step
    _navigationSteps.add({
      'instruction': 'Start navigation',
      'icon': Icons.play_arrow,
      'distance': '${widget.selectedRoute.distanceKm.toStringAsFixed(1)} km',
      'position': points[0],
    });
    
    // Generate some mock directions based on route points
    for (int i = 1; i < points.length - 1; i++) {
      if (i % 3 == 0) { // Add a step every few points to simulate turns
        // Calculate direction
        final prevPoint = points[i-1];
        final currPoint = points[i];
        final nextPoint = points[i+1];
        
        // Crude direction calculation based on lat/lng differences
        final String direction = _calculateDirection(prevPoint, currPoint, nextPoint);
        final double stepDistanceKm = (widget.selectedRoute.distanceKm / points.length) * (points.length - i);
        
        _navigationSteps.add({
          'instruction': direction,
          'icon': _getDirectionIcon(direction),
          'distance': '${stepDistanceKm.toStringAsFixed(1)} km',
          'position': currPoint,
        });
      }
    }
    
    // Destination step
    _navigationSteps.add({
      'instruction': 'Arrive at destination',
      'icon': Icons.location_on,
      'distance': '0 km',
      'position': points.last,
    });
  }
  
  // Crude direction calculation
  String _calculateDirection(LatLng prev, LatLng curr, LatLng next) {
    final directions = [
      'Turn left',
      'Turn right',
      'Continue straight',
      'Keep left',
      'Keep right',
      'Make a U-turn',
    ];
    
    // Simplified logic - would use actual heading calculation in real app
    return directions[DateTime.now().microsecond % directions.length];
  }
  
  // Get icon based on direction
  IconData _getDirectionIcon(String direction) {
    switch (direction) {
      case 'Turn left':
        return Icons.turn_left;
      case 'Turn right':
        return Icons.turn_right;
      case 'Continue straight':
        return Icons.arrow_upward;
      case 'Keep left':
        return Icons.arrow_upward;
      case 'Keep right':
        return Icons.arrow_upward;
      case 'Make a U-turn':
        return Icons.u_turn_left;
      default:
        return Icons.arrow_forward;
    }
  }
  
  // Start the navigation simulation
  void _startNavigation() {
    // Update every 5 seconds
    _navigationTimer = Timer.periodic(Duration(seconds: 5), (timer) {
      if (_currentStep < _navigationSteps.length - 1) {
        setState(() {
          _currentStep++;
          
          // Update remaining values
          _remainingDistanceKm = double.parse(
            _navigationSteps[_currentStep]['distance'].replaceAll(' km', '')
          );
          _remainingTimeMinutes = (_remainingDistanceKm / widget.selectedRoute.distanceKm * 
              widget.selectedRoute.durationMinutes).round();
              
          // Move map to current position
          _moveToCurrent();
        });
      } else {
        // End of navigation
        _navigationTimer?.cancel();
        
        // Show completion dialog
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => AlertDialog(
            title: Text('You have arrived'),
            content: Text('You have reached your destination.'),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(context); // Close dialog
                  Navigator.pop(context); // Return to map screen
                },
                child: Text('OK'),
              ),
            ],
          ),
        );
      }
    });
  }
  
  // Move map to current navigation step
  void _moveToCurrent() {
    if (_mapController != null && _currentStep < _navigationSteps.length) {
      final currentPosition = _navigationSteps[_currentStep]['position'] as LatLng;
      
      // Get bearing to next point if available
      double bearing = 0;
      if (_currentStep < _navigationSteps.length - 1) {
        final nextPosition = _navigationSteps[_currentStep + 1]['position'] as LatLng;
        bearing = _getBearing(currentPosition, nextPosition);
      }
      
      _mapController!.animateCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(
            target: currentPosition,
            zoom: 18,
            tilt: 50, // Tilt for better navigation view
            bearing: bearing,
          ),
        ),
      );
      
      setState(() {
        _showRecenterPrompt = false;
      });
    }
  }
  
  double _getBearing(LatLng start, LatLng end) {
  // Convert to radians
  final double startLat = start.latitude * math.pi / 180;
  final double startLng = start.longitude * math.pi / 180;
  final double endLat = end.latitude * math.pi / 180;
  final double endLng = end.longitude * math.pi / 180;
  
  // Calculate the bearing
  final double y = math.sin(endLng - startLng) * math.cos(endLat);
  final double x = math.cos(startLat) * math.sin(endLat) -
                  math.sin(startLat) * math.cos(endLat) * math.cos(endLng - startLng);
  final double bearing = math.atan2(y, x);
  
  // Convert to degrees
  return ((bearing * 180 / math.pi) + 360) % 360;
}
  
  void _onMapCreated(GoogleMapController controller) {
    _mapController = controller;
    
    // Set map style for navigation (optional)
    _mapController!.setMapStyle('''
      [
        {
          "featureType": "poi",
          "elementType": "labels",
          "stylers": [
            {
              "visibility": "off"
            }
          ]
        }
      ]
    ''');
    
    setState(() {
      _isLoading = false;
    });
    
    // Initial camera position
    Future.delayed(Duration(milliseconds: 500), () {
      _moveToCurrent();
    });
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Navigation'),
        actions: [
          IconButton(
            icon: Icon(Icons.close),
            onPressed: () {
              // Confirm exit navigation
              showDialog(
                context: context,
                builder: (context) => AlertDialog(
                  title: Text('Exit Navigation'),
                  content: Text('Are you sure you want to exit navigation?'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: Text('No'),
                    ),
                    TextButton(
                      onPressed: () {
                        Navigator.pop(context); // Close dialog
                        Navigator.pop(context); // Return to map screen
                      },
                      child: Text('Yes'),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
      body: Stack(
        children: [
          // Map view
          GoogleMap(
            initialCameraPosition: CameraPosition(
              target: widget.origin,
              zoom: 15.0,
            ),
            onMapCreated: _onMapCreated,
            myLocationEnabled: true,
            myLocationButtonEnabled: false,
            zoomControlsEnabled: false,
            compassEnabled: true,
            indoorViewEnabled: false,
            trafficEnabled: false,
            mapToolbarEnabled: false,
            tiltGesturesEnabled: true,
            rotateGesturesEnabled: true,
            polylines: {
              Polyline(
                polylineId: PolylineId('navigation_route'),
                points: widget.selectedRoute.points,
                color: _getTrafficColor(widget.selectedRoute.trafficLevel),
                width: 6,
              ),
            },
            markers: {
              // Origin marker
              Marker(
                markerId: MarkerId('origin'),
                position: widget.origin,
                icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
              ),
              // Destination marker
              Marker(
                markerId: MarkerId('destination'),
                position: widget.destination,
                icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
              ),
            },
            onCameraMove: (position) {
              // Show recenter prompt if user moves the map manually
              if (!_isLoading && !_showRecenterPrompt) {
                setState(() {
                  _showRecenterPrompt = true;
                });
              }
            },
          ),
          
          // Loading indicator
          if (_isLoading)
            Container(
              color: Colors.black.withOpacity(0.3),
              child: Center(
                child: LoadingIndicator(),
              ),
            ),
          
          // Navigation instruction panel
          Positioned(
            top: 16,
            left: 16,
            right: 16,
            child: Card(
              elevation: 4,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    // Current step instruction
                    Row(
                      children: [
                        Icon(
                          _currentStep < _navigationSteps.length
                              ? _navigationSteps[_currentStep]['icon'] as IconData
                              : Icons.arrow_forward,
                          size: 36,
                          color: Theme.of(context).primaryColor,
                        ),
                        SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _currentStep < _navigationSteps.length
                                    ? _navigationSteps[_currentStep]['instruction'] as String
                                    : 'Navigating...',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              SizedBox(height: 4),
                              Text(
                                'In ${_remainingDistanceKm.toStringAsFixed(1)} km',
                                style: TextStyle(
                                  color: Colors.grey[600],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    
                    Divider(height: 24),
                    
                    // Next step preview (if available)
                    if (_currentStep < _navigationSteps.length - 1)
                      Row(
                        children: [
                          Icon(
                            _navigationSteps[_currentStep + 1]['icon'] as IconData,
                            size: 24,
                            color: Colors.grey[600],
                          ),
                          SizedBox(width: 16),
                          Expanded(
                            child: Text(
                              _navigationSteps[_currentStep + 1]['instruction'] as String,
                              style: TextStyle(
                                color: Colors.grey[600],
                              ),
                            ),
                          ),
                        ],
                      ),
                    
                    // ETA info
                    SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        // Remaining time
                        Row(
                          children: [
                            Icon(Icons.access_time, size: 16, color: Colors.grey[600]),
                            SizedBox(width: 4),
                            Text(
                              '$_remainingTimeMinutes min',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        
                        // ETA
                        Row(
                          children: [
                            Icon(Icons.flag, size: 16, color: Colors.grey[600]),
                            SizedBox(width: 4),
                            Text(
                              'ETA: ${_getEstimatedArrivalTime(_remainingTimeMinutes)}',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
          
          // Recenter button (only shown when map moved manually)
          if (_showRecenterPrompt)
            Positioned(
              bottom: 24,
              right: 16,
              child: FloatingActionButton(
                onPressed: _moveToCurrent,
                child: Icon(Icons.gps_fixed),
                tooltip: 'Recenter navigation',
              ),
            ),
        ],
      ),
    );
  }
  
  // Get color based on traffic level
  Color _getTrafficColor(TrafficLevel trafficLevel) {
    switch (trafficLevel) {
      case TrafficLevel.low:
        return Colors.green;
      case TrafficLevel.medium:
        return Colors.orange;
      case TrafficLevel.high:
        return Colors.red;
      case TrafficLevel.severe:
        return Colors.purple;
      default:
        return Colors.blue;
    }
  }
  
  // Calculate estimated arrival time
  String _getEstimatedArrivalTime(int minutesFromNow) {
    final now = DateTime.now();
    final arrivalTime = now.add(Duration(minutes: minutesFromNow));
    
    // Format time as HH:MM AM/PM
    String period = arrivalTime.hour >= 12 ? 'PM' : 'AM';
    int hour = arrivalTime.hour > 12 ? arrivalTime.hour - 12 : arrivalTime.hour;
    if (hour == 0) hour = 12; // 12 AM instead of 0 AM
    
    String minute = arrivalTime.minute < 10 
        ? '0${arrivalTime.minute}' 
        : '${arrivalTime.minute}';
    
    return '$hour:$minute $period';
  }
}