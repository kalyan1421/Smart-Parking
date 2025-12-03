// lib/screens/booking/parking_directions_screen.dart
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:provider/provider.dart';
import 'package:smart_parking_app/models/parking_spot.dart';
import 'package:smart_parking_app/providers/location_provider.dart';
import 'package:url_launcher/url_launcher.dart';

class ParkingDirectionsScreen extends StatefulWidget {
  final ParkingSpot parkingSpot;

  const ParkingDirectionsScreen({
    Key? key,
    required this.parkingSpot,
  }) : super(key: key);

  @override
  _ParkingDirectionsScreenState createState() => _ParkingDirectionsScreenState();
}

class _ParkingDirectionsScreenState extends State<ParkingDirectionsScreen> {
  GoogleMapController? _mapController;
  Set<Marker> _markers = {};
  Set<Polyline> _polylines = {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeMap();
    });
  }

  Future<void> _initializeMap() async {
    final locationProvider = Provider.of<LocationProvider>(context, listen: false);
    
    // Wait for location if needed
    if (!locationProvider.hasLocation) {
      await locationProvider.getCurrentLocation();
    }
    
    // Initialize markers
    _updateMarkers();
    
    // Move camera to show both points
    if (_mapController != null && locationProvider.hasLocation) {
      final userLocation = LatLng(
        locationProvider.currentLocation!.latitude,
        locationProvider.currentLocation!.longitude,
      );
      
      final parkingLocation = LatLng(
        widget.parkingSpot.latitude,
        widget.parkingSpot.longitude,
      );
      
      // Calculate bounds to include both points
      final bounds = LatLngBounds(
        southwest: LatLng(
          min(userLocation.latitude, parkingLocation.latitude),
          min(userLocation.longitude, parkingLocation.longitude),
        ),
        northeast: LatLng(
          max(userLocation.latitude, parkingLocation.latitude),
          max(userLocation.longitude, parkingLocation.longitude),
        ),
      );
      
      // Add some padding
      _mapController!.animateCamera(CameraUpdate.newLatLngBounds(bounds, 100));
      
      // In a real app, you would draw the route here
      // For now, we'll just draw a straight line
      _drawRoute(userLocation, parkingLocation);
    }
  }
  
  void _updateMarkers() {
    final locationProvider = Provider.of<LocationProvider>(context, listen: false);
    
    Set<Marker> markers = {};
    
    // Add marker for parking spot
    markers.add(Marker(
      markerId: MarkerId('parking_spot'),
      position: LatLng(widget.parkingSpot.latitude, widget.parkingSpot.longitude),
      infoWindow: InfoWindow(
        title: widget.parkingSpot.name,
        snippet: 'Your destination',
      ),
      icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
    ));
    
    // Add marker for user location
    if (locationProvider.hasLocation) {
      markers.add(Marker(
        markerId: MarkerId('user_location'),
        position: LatLng(
          locationProvider.currentLocation!.latitude,
          locationProvider.currentLocation!.longitude,
        ),
        infoWindow: InfoWindow(
          title: 'Your Location',
        ),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
      ));
    }
    
    setState(() {
      _markers = markers;
    });
  }
  
  void _drawRoute(LatLng start, LatLng end) {
    // In a real app, you would fetch the route from a directions API
    // For now, we'll just draw a straight line
    
    setState(() {
      _polylines = {
        Polyline(
          polylineId: PolylineId('route'),
          points: [start, end],
          color: Colors.blue,
          width: 5,
        ),
      };
    });
  }
  
  Future<void> _openInMaps() async {
    final locationProvider = Provider.of<LocationProvider>(context, listen: false);
    
    if (!locationProvider.hasLocation) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Your location is not available'),
        ),
      );
      return;
    }
    
    final userLat = locationProvider.currentLocation!.latitude;
    final userLng = locationProvider.currentLocation!.longitude;
    final destLat = widget.parkingSpot.latitude;
    final destLng = widget.parkingSpot.longitude;
    
    // Prepare the URL for navigation
    final url = Uri.parse(
      'https://www.google.com/maps/dir/?api=1&origin=$userLat,$userLng&destination=$destLat,$destLng&travelmode=driving'
    );
    
    if (await canLaunchUrl(url)) {
      await launchUrl(url);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not open maps application'),
        ),
      );
    }
  }

  double min(double a, double b) => a < b ? a : b;
  double max(double a, double b) => a > b ? a : b;

  @override
  Widget build(BuildContext context) {
    final locationProvider = Provider.of<LocationProvider>(context);
    
    // Default camera position
    final initialCameraPosition = CameraPosition(
      target: LatLng(
        widget.parkingSpot.latitude,
        widget.parkingSpot.longitude,
      ),
      zoom: 14.0,
    );
    
    return Scaffold(
      appBar: AppBar(
        title: Text('Directions to Parking'),
      ),
      body: Column(
        children: [
          Expanded(
            child: GoogleMap(
              initialCameraPosition: initialCameraPosition,
              myLocationEnabled: true,
              myLocationButtonEnabled: false,
              zoomControlsEnabled: false,
              markers: _markers,
              polylines: _polylines,
              onMapCreated: (controller) {
                setState(() {
                  _mapController = controller;
                });
                
                _initializeMap();
              },
            ),
          ),
          
          // Bottom panel with directions info
          Container(
            padding: EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 10,
                  offset: Offset(0, -2),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.parkingSpot.name,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                SizedBox(height: 4),
                Text(
                  widget.parkingSpot.description,
                  style: TextStyle(
                    color: Colors.grey.shade700,
                  ),
                ),
                SizedBox(height: 16),
                
                // Distance and time info (would be calculated from route in real app)
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'DISTANCE',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade700,
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            '2.5 km', // Placeholder value
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'ESTIMATED TIME',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade700,
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            '8 min', // Placeholder value
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                
                SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _openInMaps,
                    icon: Icon(Icons.directions),
                    label: Text('NAVIGATE'),
                    style: ElevatedButton.styleFrom(
                      padding: EdgeInsets.symmetric(vertical: 16),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
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
        child: Icon(Icons.my_location),
        tooltip: 'My Location',
      ),
    );
  }
  
  @override
  void dispose() {
    _mapController?.dispose();
    super.dispose();
  }
}