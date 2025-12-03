// lib/screens/maps/test_map_screen.dart
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';


class TestMapScreen extends StatefulWidget {
  const TestMapScreen({super.key});

  @override
  State<TestMapScreen> createState() => _TestMapScreenState();
}

class _TestMapScreenState extends State<TestMapScreen> {
  GoogleMapController? _mapController; // ignore: unused_field
  bool _isMapReady = false;
  String _mapStatus = 'Initializing...';
  Set<Marker> _markers = {};
  
  // Default location (San Francisco)
  static const LatLng _defaultLocation = LatLng(37.7749, -122.4194);

  @override
  void initState() {
    super.initState();
    _addTestMarker();
  }

  void _addTestMarker() {
    setState(() {
      _markers.add(
        const Marker(
          markerId: MarkerId('test_marker'),
          position: _defaultLocation,
          infoWindow: InfoWindow(
            title: 'Test Location',
            snippet: 'San Francisco, CA',
          ),
        ),
      );
    });
  }

  void _onMapCreated(GoogleMapController controller) {
    _mapController = controller;
    setState(() {
      _isMapReady = true;
      _mapStatus = 'Map loaded successfully!';
    });
    debugPrint('Google Map created successfully');
  }

  void _onMapTap(LatLng location) {
    setState(() {
      _markers.add(
        Marker(
          markerId: MarkerId('tap_${DateTime.now().millisecondsSinceEpoch}'),
          position: location,
          infoWindow: InfoWindow(
            title: 'Tapped Location',
            snippet: 'Lat: ${location.latitude.toStringAsFixed(4)}, Lng: ${location.longitude.toStringAsFixed(4)}',
          ),
        ),
      );
    });
    debugPrint('Map tapped at: ${location.latitude}, ${location.longitude}');
  }

  void _clearMarkers() {
    setState(() {
      _markers.clear();
    });
    _addTestMarker();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Test Map Screen'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            onPressed: _clearMarkers,
            icon: const Icon(Icons.clear),
            tooltip: 'Clear Markers',
          ),
        ],
      ),
      body: Column(
        children: [
          // Status bar
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            color: _isMapReady ? Colors.green.shade100 : Colors.orange.shade100,
            child: Row(
              children: [
                Icon(
                  _isMapReady ? Icons.check_circle : Icons.hourglass_empty,
                  color: _isMapReady ? Colors.green : Colors.orange,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _mapStatus,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: _isMapReady ? Colors.green.shade800 : Colors.orange.shade800,
                        ),
                      ),
                      Text(
                        'Markers: ${_markers.length} • Tap map to add markers',
                        style: TextStyle(
                          fontSize: 12,
                          color: _isMapReady ? Colors.green.shade700 : Colors.orange.shade700,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          
          // Map
          Expanded(
            child: GoogleMap(
              onMapCreated: _onMapCreated,
              onTap: _onMapTap,
              initialCameraPosition: const CameraPosition(
                target: _defaultLocation,
                zoom: 12.0,
              ),
              markers: _markers,
              myLocationEnabled: true,
              myLocationButtonEnabled: true,
              mapType: MapType.normal,
              zoomControlsEnabled: true,
              compassEnabled: true,
            ),
          ),
          
          // Debug info
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            color: Colors.grey.shade100,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Debug Information:',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text('Map Ready: $_isMapReady'),
                Text('Markers Count: ${_markers.length}'),
                Text('Default Location: ${_defaultLocation.latitude}, ${_defaultLocation.longitude}'),
                const SizedBox(height: 8),
                const Text(
                  'Instructions:',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const Text('• Tap anywhere on the map to add markers'),
                const Text('• Use the clear button to remove all markers'),
                const Text('• Check console for debug messages'),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
