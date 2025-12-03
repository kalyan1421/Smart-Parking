// lib/screens/maps/route_options_sheet.dart
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:provider/provider.dart';
import 'package:smart_parking_app/models/route_option.dart';
import 'package:smart_parking_app/models/traffic_bot.dart';
import 'package:smart_parking_app/providers/location_provider.dart';
import 'package:smart_parking_app/screens/maps/navigation_screen.dart';

class RouteOptionsSheet extends StatefulWidget {
  final List<RouteOption> routeOptions;
  final Function(RouteOption) onRouteSelected;
  final VoidCallback onCancel;
  final LatLng destination;
  
  const RouteOptionsSheet({
    Key? key,
    required this.routeOptions,
    required this.onRouteSelected,
    required this.onCancel,
    required this.destination,
  }) : super(key: key);
  
  @override
  _RouteOptionsSheetState createState() => _RouteOptionsSheetState();
}

class _RouteOptionsSheetState extends State<RouteOptionsSheet> {
  int _selectedRouteIndex = 0;
  
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
        top: 16,
        left: 16,
        right: 16,
        // Add bottom padding to account for the safe area
        bottom: MediaQuery.of(context).padding.bottom + 16,
      ),
      // Fixed height to show route details
      height: 440,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            spreadRadius: 5,
          ),
        ],
      ),
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
          SizedBox(height: 16),
          
          // Header
          Row(
            children: [
              Icon(Icons.directions, color: Theme.of(context).primaryColor),
              SizedBox(width: 8),
              Text(
                'Route Options',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          
          SizedBox(height: 8),
          Text(
            'Choose from ${widget.routeOptions.length} routes to your destination:',
            style: TextStyle(
              color: Colors.grey[600],
              fontSize: 13,
            ),
          ),
          
          SizedBox(height: 16),
          
          // Route tabs
          Container(
            height: 44,
            decoration: BoxDecoration(
              color: Colors.grey[200],
              borderRadius: BorderRadius.circular(22),
            ),
            child: Row(
              children: List.generate(
                widget.routeOptions.length,
                (index) => Expanded(
                  child: GestureDetector(
                    onTap: () {
                      setState(() {
                        _selectedRouteIndex = index;
                      });
                      widget.onRouteSelected(widget.routeOptions[index]);
                    },
                    child: Container(
                      decoration: BoxDecoration(
                        color: _selectedRouteIndex == index
                            ? Theme.of(context).primaryColor
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(22),
                      ),
                      child: Center(
                        child: Text(
                          'Route ${index + 1}',
                          style: TextStyle(
                            color: _selectedRouteIndex == index
                                ? Colors.white
                                : Colors.black,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          
          SizedBox(height: 16),
          
          // Selected route details
          _buildRouteDetails(widget.routeOptions[_selectedRouteIndex]),
          
          Spacer(),
          
          // Buttons
          Row(
            children: [
              // Cancel button
              Expanded(
                child: OutlinedButton(
                  onPressed: widget.onCancel,
                  style: OutlinedButton.styleFrom(
                    padding: EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30),
                    ),
                  ),
                  child: Text('Cancel'),
                ),
              ),
              SizedBox(width: 16),
              
              // Start navigation button
              Expanded(
                child: ElevatedButton(
                  onPressed: () {
                    final locationProvider = Provider.of<LocationProvider>(context, listen: false);
                    final currentLocation = LatLng(
                      locationProvider.latitude,
                      locationProvider.longitude,
                    );
                    
                    _startNavigation(
                      context, 
                      widget.routeOptions[_selectedRouteIndex],
                      currentLocation, 
                      widget.destination,
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    padding: EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30),
                    ),
                  ),
                  child: Text('Start'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
  
  // Launch the navigation screen
  void _startNavigation(BuildContext context, RouteOption route, LatLng origin, LatLng destination) {
    // Select this route
    widget.onRouteSelected(route);
    
    // Close bottom sheet
    Navigator.pop(context);
    
    // Launch navigation screen
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => NavigationScreen(
          selectedRoute: route,
          origin: origin,
          destination: destination,
        ),
      ),
    );
  }
  
  // Build route details section
  Widget _buildRouteDetails(RouteOption route) {
    // Get color based on traffic level
    Color trafficColor;
    switch (route.trafficLevel) {
      case TrafficLevel.low:
        trafficColor = Colors.green;
        break;
      case TrafficLevel.medium:
        trafficColor = Colors.orange;
        break;
      case TrafficLevel.high:
        trafficColor = Colors.red;
        break;
      case TrafficLevel.severe:
        trafficColor = Colors.purple;
        break;
      default:
        trafficColor = Colors.blue;
    }
    
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Route name/description
          Text(
            route.description,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
          SizedBox(height: 12),
          
          // Traffic level indicator
          Row(
            children: [
              Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  color: trafficColor,
                  shape: BoxShape.circle,
                ),
              ),
              SizedBox(width: 8),
              Text(
                TrafficBot.getDescriptionForTrafficLevel(route.trafficLevel),
                style: TextStyle(
                  color: trafficColor,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          SizedBox(height: 12),
          
          // ETA and distance
          Row(
            children: [
              // Time
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Estimated Time',
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 12,
                      ),
                    ),
                    SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(Icons.access_time, size: 18),
                        SizedBox(width: 4),
                        Text(
                          route.formattedTime,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              
              // Distance
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Distance',
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 12,
                      ),
                    ),
                    SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(Icons.straighten, size: 18),
                        SizedBox(width: 4),
                        Text(
                          route.formattedDistance,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          
          // ETA time
          SizedBox(height: 12),
          Row(
            children: [
              Icon(Icons.schedule, size: 18, color: Colors.grey[600]),
              SizedBox(width: 4),
              Text(
                'ETA: ${_getEstimatedArrivalTime(route.durationMinutes)}',
                style: TextStyle(
                  color: Colors.grey[700],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
  
  // Calculate estimated arrival time
  String _getEstimatedArrivalTime(int durationMinutes) {
    final now = DateTime.now();
    final arrivalTime = now.add(Duration(minutes: durationMinutes));
    
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