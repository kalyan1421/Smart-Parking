// lib/screens/maps/location_picker_screen.dart
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:dio/dio.dart';
import 'dart:async';

import '../../config/app_config.dart';

class LocationPickerScreen extends StatefulWidget {
  final LatLng? initialLocation;
  final String? initialAddress;

  const LocationPickerScreen({
    super.key,
    this.initialLocation,
    this.initialAddress,
  });

  @override
  State<LocationPickerScreen> createState() => _LocationPickerScreenState();
}

class _LocationPickerScreenState extends State<LocationPickerScreen> {
  final _searchController = TextEditingController();
  final _dio = Dio();
  
  GoogleMapController? _mapController;
  LatLng _selectedLocation = const LatLng(17.385044, 78.486671); // Default to Hyderabad
  Set<Marker> _markers = {};
  bool _isMapLoading = true;
  String? _mapError;
  String? _selectedAddress;
  
  // Search related
  List<Map<String, dynamic>> _searchResults = [];
  bool _isSearching = false;
  bool _hasSearched = false;
  String? _searchError;
  Timer? _searchDebounce;
  final String _googleMapsApiKey = 'AIzaSyA3TG94CbG-lUzrgusZggVrOPEaZ9DD3D0';

  @override
  void initState() {
    super.initState();
    if (widget.initialLocation != null) {
      _selectedLocation = widget.initialLocation!;
      _selectedAddress = widget.initialAddress;
    } else {
      _getCurrentLocation();
    }
    _setupMapTimeout();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchDebounce?.cancel();
    _mapController?.dispose();
    _dio.close();
    super.dispose();
  }

  void _setupMapTimeout() {
    Future.delayed(const Duration(seconds: 10), () {
      if (mounted && _isMapLoading) {
        setState(() {
          _isMapLoading = false;
          _mapError = 'Map is taking longer than expected. Please check your internet connection.';
        });
      }
    });
  }

  Future<void> _getCurrentLocation() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Location services are disabled')),
          );
        }
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Location permission denied')),
            );
          }
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Location permission permanently denied')),
          );
        }
        return;
      }

      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      setState(() {
        _selectedLocation = LatLng(position.latitude, position.longitude);
        _updateMarker(_selectedLocation);
      });

      if (_mapController != null) {
        _mapController!.animateCamera(
          CameraUpdate.newCameraPosition(
            CameraPosition(
              target: _selectedLocation,
              zoom: 15.0,
            ),
          ),
        );
      }
      
      _getAddressFromCoordinates(_selectedLocation);
    } catch (e) {
      debugPrint('Error getting location: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error getting location: $e')),
        );
      }
    }
  }

  void _updateMarker(LatLng location) {
    setState(() {
      _selectedLocation = location;
      _markers = {
        Marker(
          markerId: const MarkerId('selected_location'),
          position: location,
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
          draggable: true,
          infoWindow: InfoWindow(
            title: 'Selected Location',
            snippet: 'Lat: ${location.latitude.toStringAsFixed(6)}, Lng: ${location.longitude.toStringAsFixed(6)}\nDrag to adjust',
          ),
          onDragEnd: (LatLng newPosition) {
            debugPrint('📍 Marker dragged to: ${newPosition.latitude}, ${newPosition.longitude}');
            setState(() {
              _selectedLocation = newPosition;
            });
            _getAddressFromCoordinates(newPosition);
          },
        ),
      };
    });
  }

  void _onMapCreated(GoogleMapController controller) {
    debugPrint('✅ Google Map created successfully!');
    _mapController = controller;
    setState(() {
      _isMapLoading = false;
      _mapError = null;
    });
    _updateMarker(_selectedLocation);
    
    Future.delayed(const Duration(milliseconds: 500), () {
      if (_mapController != null && mounted) {
        _mapController!.animateCamera(
          CameraUpdate.newCameraPosition(
            CameraPosition(
              target: _selectedLocation,
              zoom: 15.0,
            ),
          ),
        );
      }
    });
    
    if (widget.initialLocation == null) {
      _getAddressFromCoordinates(_selectedLocation);
    }
  }

  void _onMapTapped(LatLng location) {
    debugPrint('📍 Map tapped at: ${location.latitude}, ${location.longitude}');
    _updateMarker(location);
    _getAddressFromCoordinates(location);
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '📍 Pin dropped at:\n${location.latitude.toStringAsFixed(6)}, ${location.longitude.toStringAsFixed(6)}',
            style: const TextStyle(fontSize: 12),
          ),
          backgroundColor: Colors.blue,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  Future<void> _searchPlaces(String query) async {
    if (query.isEmpty) {
      setState(() {
        _searchResults = [];
        _isSearching = false;
        _hasSearched = false;
      });
      return;
    }

    setState(() {
      _isSearching = true;
      _hasSearched = true;
      _searchError = null; // Clear previous errors
    });

    try {
      debugPrint('🔍 Searching for: $query');
      
      final response = await _dio.get(
        'https://maps.googleapis.com/maps/api/place/autocomplete/json',
        queryParameters: {
          'input': query,
          'key': _googleMapsApiKey,
          'language': 'en',
          // Try without country restriction first
          // 'components': 'country:in', // Uncomment to restrict to India
        },
        options: Options(
          validateStatus: (status) => status! < 500,
          headers: {
            'Accept': 'application/json',
          },
        ),
      );

      debugPrint('📡 Response status: ${response.statusCode}');
      debugPrint('📡 Response data: ${response.data}');

      if (response.statusCode == 200) {
        final status = response.data['status'] as String? ?? 'UNKNOWN_ERROR';
        debugPrint('📊 API Status: $status');
        
        if (status == 'OK') {
          final predictions = response.data['predictions'] as List<dynamic>? ?? [];
          debugPrint('✅ Found ${predictions.length} results');
          
          setState(() {
            _searchResults = List<Map<String, dynamic>>.from(predictions);
          });
        } else if (status == 'ZERO_RESULTS') {
          debugPrint('⚠️ No results found');
          setState(() {
            _searchResults = [];
          });
        } else if (status == 'REQUEST_DENIED') {
          debugPrint('❌ Request denied - Check API key and Places API enablement');
          final errorMessage = response.data['error_message'] as String? ?? 'API request denied';
          setState(() {
            _searchResults = [];
            _searchError = 'Search unavailable. Please enable Places API in Google Cloud Console.';
          });
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Search error: $errorMessage'),
                backgroundColor: Colors.red,
                duration: const Duration(seconds: 4),
              ),
            );
          }
        } else if (status == 'INVALID_REQUEST') {
          debugPrint('❌ Invalid request');
          setState(() {
            _searchResults = [];
          });
        } else {
          debugPrint('❌ Places API error: $status');
          final errorMessage = response.data['error_message'] as String? ?? 'Unknown error';
          debugPrint('Error message: $errorMessage');
          setState(() {
            _searchResults = [];
            _searchError = 'Search error: $status';
          });
        }
      } else {
        debugPrint('❌ HTTP Error: ${response.statusCode}');
        setState(() {
          _searchResults = [];
        });
      }
    } catch (e, stackTrace) {
      debugPrint('❌ Error searching places: $e');
      debugPrint('Stack trace: $stackTrace');
      
      setState(() {
        _searchResults = [];
        _searchError = 'Network error. Please check your internet connection.';
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Search error: ${e.toString()}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } finally {
      setState(() {
        _isSearching = false;
      });
    }
  }

  Future<void> _getPlaceDetails(String placeId) async {
    try {
      final response = await _dio.get(
        'https://maps.googleapis.com/maps/api/place/details/json',
        queryParameters: {
          'place_id': placeId,
          'key': _googleMapsApiKey,
          'fields': 'geometry,formatted_address,name',
        },
      );

      if (response.statusCode == 200 && response.data['status'] == 'OK') {
        final result = response.data['result'];
        final location = result['geometry']['location'];
        final lat = location['lat'] as double;
        final lng = location['lng'] as double;
        final address = result['formatted_address'] as String? ?? result['name'] as String? ?? '';

        final newLocation = LatLng(lat, lng);
        
        setState(() {
          _selectedLocation = newLocation;
          _selectedAddress = address;
          _searchController.text = address;
          _searchResults = [];
        });

        _updateMarker(newLocation);

        if (_mapController != null) {
          _mapController!.animateCamera(
            CameraUpdate.newCameraPosition(
              CameraPosition(
                target: newLocation,
                zoom: 16.0,
              ),
            ),
          );
        }

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('📍 Location selected: $address'),
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 2),
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('Error getting place details: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error getting place details: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _getAddressFromCoordinates(LatLng location) async {
    try {
      final response = await _dio.get(
        'https://maps.googleapis.com/maps/api/geocode/json',
        queryParameters: {
          'latlng': '${location.latitude},${location.longitude}',
          'key': _googleMapsApiKey,
        },
      );

      if (response.statusCode == 200 && response.data['status'] == 'OK') {
        final results = response.data['results'] as List;
        if (results.isNotEmpty) {
          setState(() {
            _selectedAddress = results[0]['formatted_address'] as String;
          });
        }
      }
    } catch (e) {
      debugPrint('Error getting address: $e');
    }
  }

  void _onSearchChanged(String value) {
    _searchDebounce?.cancel();
    if (value.isEmpty) {
      setState(() {
        _searchResults = [];
        _hasSearched = false;
      });
      return;
    }
    _searchDebounce = Timer(const Duration(milliseconds: 500), () {
      _searchPlaces(value);
    });
  }

  void _confirmSelection() {
    Navigator.of(context).pop({
      'location': _selectedLocation,
      'address': _selectedAddress ?? '${_selectedLocation.latitude}, ${_selectedLocation.longitude}',
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Select Location'),
        backgroundColor: AppConfig.primaryColor,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          TextButton.icon(
            onPressed: _confirmSelection,
            icon: const Icon(Icons.check, color: Colors.white),
            label: const Text(
              'Confirm',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // Search Bar
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.white,
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search for a location...',
                prefixIcon: const Icon(Icons.search, color: Colors.grey),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, color: Colors.grey),
                        onPressed: () {
                          _searchController.clear();
                          setState(() {
                            _searchResults = [];
                            _hasSearched = false;
                          });
                        },
                      )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.grey.shade300),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.grey.shade300),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: AppConfig.primaryColor, width: 2),
                ),
                filled: true,
                fillColor: Colors.grey.shade50,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
              onChanged: _onSearchChanged,
            ),
          ),

          // Search Results List (Google Maps style)
          if (_searchResults.isNotEmpty)
            Container(
              color: Colors.white,
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.5,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                    child: Text(
                      'Search Results',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey.shade600,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                  Expanded(
                    child: ListView.separated(
                      padding: EdgeInsets.zero,
                      itemCount: _searchResults.length,
                      separatorBuilder: (context, index) => Divider(
                        height: 1,
                        thickness: 1,
                        indent: 56,
                        color: Colors.grey.shade200,
                      ),
                      itemBuilder: (context, index) {
                        final place = _searchResults[index];
                        final structuredFormatting = place['structured_formatting'] as Map<String, dynamic>?;
                        final mainText = structuredFormatting?['main_text'] as String? ?? place['description'] as String? ?? '';
                        final secondaryText = structuredFormatting?['secondary_text'] as String? ?? '';
                        final types = place['types'] as List<dynamic>? ?? [];
                        
                        // Determine icon based on place type
                        IconData placeIcon = Icons.location_on;
                        Color iconColor = Colors.red;
                        
                        if (types.isNotEmpty) {
                          final primaryType = types[0] as String;
                          if (primaryType.contains('establishment') || primaryType.contains('point_of_interest')) {
                            placeIcon = Icons.business;
                            iconColor = Colors.blue;
                          } else if (primaryType.contains('restaurant') || primaryType.contains('food')) {
                            placeIcon = Icons.restaurant;
                            iconColor = Colors.orange;
                          } else if (primaryType.contains('gas_station') || primaryType.contains('parking')) {
                            placeIcon = Icons.local_parking;
                            iconColor = Colors.green;
                          } else if (primaryType.contains('lodging') || primaryType.contains('hotel')) {
                            placeIcon = Icons.hotel;
                            iconColor = Colors.purple;
                          } else if (primaryType.contains('store') || primaryType.contains('shopping')) {
                            placeIcon = Icons.store;
                            iconColor = Colors.teal;
                          } else if (primaryType.contains('school') || primaryType.contains('university')) {
                            placeIcon = Icons.school;
                            iconColor = Colors.indigo;
                          } else if (primaryType.contains('hospital') || primaryType.contains('health')) {
                            placeIcon = Icons.local_hospital;
                            iconColor = Colors.red.shade700;
                          }
                        }

                        return Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: () {
                              _getPlaceDetails(place['place_id'] as String);
                            },
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Container(
                                    width: 40,
                                    height: 40,
                                    decoration: BoxDecoration(
                                      color: iconColor.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: Icon(
                                      placeIcon,
                                      color: iconColor,
                                      size: 22,
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          mainText,
                                          style: const TextStyle(
                                            fontSize: 15,
                                            fontWeight: FontWeight.w500,
                                            color: Colors.black87,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        if (secondaryText.isNotEmpty) ...[
                                          const SizedBox(height: 4),
                                          Text(
                                            secondaryText,
                                            style: TextStyle(
                                              fontSize: 13,
                                              color: Colors.grey.shade600,
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                  Icon(
                                    Icons.chevron_right,
                                    color: Colors.grey.shade400,
                                    size: 20,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          
          // Loading indicator for search
          if (_isSearching && _searchResults.isEmpty)
            Container(
              padding: const EdgeInsets.all(16),
              color: Colors.white,
              child: Row(
                children: [
                  SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(AppConfig.primaryColor),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'Searching...',
                    style: TextStyle(
                      color: Colors.grey.shade600,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
          
          // No results message
          if (!_isSearching && _hasSearched && _searchResults.isEmpty && _searchController.text.isNotEmpty)
            Container(
              padding: const EdgeInsets.all(24),
              color: Colors.white,
              child: Column(
                children: [
                  Icon(
                    _searchError != null ? Icons.error_outline : Icons.search_off,
                    size: 48,
                    color: _searchError != null ? Colors.red.shade400 : Colors.grey.shade400,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    _searchError ?? 'No results found',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: _searchError != null ? Colors.red.shade700 : Colors.grey.shade700,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 4),
                  if (_searchError == null)
                    Text(
                      'Try a different search term',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey.shade500,
                      ),
                    ),
                  if (_searchError != null && _searchError!.contains('Places API')) ...[
                    const SizedBox(height: 8),
                    Text(
                      'Make sure Places API is enabled in Google Cloud Console',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ],
              ),
            ),

          // Map View
          Expanded(
            child: Stack(
              children: [
                GoogleMap(
                  onMapCreated: _onMapCreated,
                  initialCameraPosition: CameraPosition(
                    target: _selectedLocation,
                    zoom: 15.0,
                  ),
                  markers: _markers,
                  onTap: _onMapTapped,
                  myLocationEnabled: true,
                  myLocationButtonEnabled: false,
                  mapType: MapType.normal,
                  zoomControlsEnabled: false,
                  compassEnabled: true,
                  scrollGesturesEnabled: true,
                  zoomGesturesEnabled: true,
                  rotateGesturesEnabled: true,
                  tiltGesturesEnabled: false,
                  mapToolbarEnabled: false,
                  liteModeEnabled: false,
                  buildingsEnabled: true,
                  trafficEnabled: false,
                ),
                
                // Loading indicator
                if (_isMapLoading)
                  Container(
                    color: Colors.white.withOpacity(0.9),
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const CircularProgressIndicator(),
                          const SizedBox(height: 16),
                          const Text(
                            'Loading Map...',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          if (_mapError != null) ...[
                            const SizedBox(height: 8),
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 32),
                              child: Text(
                                _mapError!,
                                style: TextStyle(
                                  color: Colors.red.shade700,
                                  fontSize: 12,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                
                // Instructions overlay
                if (!_isMapLoading && _mapError == null)
                  Positioned(
                    top: 8,
                    left: 8,
                    right: 8,
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.blue.shade200),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.info_outline, color: Colors.blue.shade700, size: 18),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Tap to drop pin • Drag marker to adjust • Search for locations',
                              style: TextStyle(
                                color: Colors.blue.shade900,
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                
                // Location Info Card
                if (!_isMapLoading && _selectedAddress != null)
                  Positioned(
                    bottom: 16,
                    left: 16,
                    right: 16,
                    child: Card(
                      elevation: 4,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Row(
                              children: [
                                Icon(Icons.location_on, color: Colors.red, size: 20),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    _selectedAddress!,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Coordinates: ${_selectedLocation.latitude.toStringAsFixed(6)}, ${_selectedLocation.longitude.toStringAsFixed(6)}',
                              style: TextStyle(
                                color: Colors.grey.shade600,
                                fontSize: 12,
                                fontFamily: 'monospace',
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                
                // Map Controls
                Positioned(
                  right: 16,
                  bottom: _selectedAddress != null ? 120 : 16,
                  child: Column(
                    children: [
                      FloatingActionButton.small(
                        heroTag: 'zoom_in',
                        onPressed: () {
                          _mapController?.animateCamera(CameraUpdate.zoomIn());
                        },
                        backgroundColor: Colors.white,
                        child: const Icon(Icons.add, color: Colors.black87),
                      ),
                      const SizedBox(height: 8),
                      FloatingActionButton.small(
                        heroTag: 'zoom_out',
                        onPressed: () {
                          _mapController?.animateCamera(CameraUpdate.zoomOut());
                        },
                        backgroundColor: Colors.white,
                        child: const Icon(Icons.remove, color: Colors.black87),
                      ),
                      const SizedBox(height: 8),
                      FloatingActionButton.small(
                        heroTag: 'my_location',
                        onPressed: _getCurrentLocation,
                        backgroundColor: Colors.white,
                        child: const Icon(Icons.my_location, color: Colors.blue),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

