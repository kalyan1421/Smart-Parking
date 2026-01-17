// lib/screens/parking/add_parking_spot_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'dart:async';

import '../../providers/admin_provider.dart';
import '../../providers/auth_provider.dart';
import '../../models/parking_spot.dart';
import '../../config/app_config.dart';
import '../maps/location_picker_screen.dart';

class AddParkingSpotScreen extends StatefulWidget {
  const AddParkingSpotScreen({super.key});

  @override
  State<AddParkingSpotScreen> createState() => _AddParkingSpotScreenState();
}

class _AddParkingSpotScreenState extends State<AddParkingSpotScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _addressController = TextEditingController();
  final _totalSpotsController = TextEditingController();
  final _pricePerHourController = TextEditingController();
  final _contactPhoneController = TextEditingController();

  List<String> _selectedAmenities = [];
  List<String> _selectedVehicleTypes = ['car'];
  ParkingSpotStatus _status = ParkingSpotStatus.available;
  bool _isLoading = false;
  
  // Map related
  GoogleMapController? _mapController;
  LatLng _selectedLocation = const LatLng(17.385044, 78.486671); // Default to Hyderabad
  Set<Marker> _markers = {};
  bool _showMap = false;
  bool _isMapLoading = true;
  String? _mapError;

  final List<String> _amenityOptions = [
    'Security Camera',
    'Lighting',
    'Covered',
    'EV Charging',
    '24/7 Access',
    'Wheelchair Accessible',
    'Restroom Nearby',
    'Car Wash',
    'Valet Service',
    'Security Guard',
    'CCTV',
    'Fire Safety',
  ];

  final List<String> _vehicleTypeOptions = [
    'car',
    'motorcycle',
    'bicycle',
    'truck',
    'rv',
    'bus',
  ];

  @override
  void initState() {
    super.initState();
    _getCurrentLocation();
    // Set timeout for map loading
    _setupMapTimeout();
  }

  void _setupMapTimeout() {
    // If map doesn't load within 10 seconds, show error
    Future.delayed(const Duration(seconds: 10), () {
      if (mounted && _isMapLoading && _showMap) {
        setState(() {
          _isMapLoading = false;
          _mapError = 'Map is taking longer than expected. Please check your internet connection and try again.';
        });
      }
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _addressController.dispose();
    _totalSpotsController.dispose();
    _pricePerHourController.dispose();
    _contactPhoneController.dispose();
    _mapController?.dispose();
    super.dispose();
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
            title: 'Parking Location',
            snippet: 'Lat: ${location.latitude.toStringAsFixed(6)}, Lng: ${location.longitude.toStringAsFixed(6)}\nDrag to adjust',
          ),
          onDragEnd: (LatLng newPosition) {
            debugPrint('📍 Marker dragged to: ${newPosition.latitude}, ${newPosition.longitude}');
            setState(() {
              _selectedLocation = newPosition;
            });
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    '📍 Location updated:\n${newPosition.latitude.toStringAsFixed(6)}, ${newPosition.longitude.toStringAsFixed(6)}',
                    style: const TextStyle(fontSize: 12),
                  ),
                  backgroundColor: Colors.green,
                  duration: const Duration(seconds: 2),
                ),
              );
            }
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
    // Animate to current location after map is ready
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
    
    // Show success message
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✅ Map loaded successfully! Tap anywhere on the map to drop a pin'),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 3),
        ),
      );
    }
  }

  void _onMapTapped(LatLng location) {
    debugPrint('📍 Map tapped at: ${location.latitude}, ${location.longitude}');
    _updateMarker(location);
    // Show feedback
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

  Future<void> _openLocationPicker() async {
    final result = await Navigator.push<Map<String, dynamic>>(
      context,
      MaterialPageRoute(
        builder: (context) => LocationPickerScreen(
          initialLocation: _selectedLocation,
          initialAddress: _addressController.text.isNotEmpty ? _addressController.text : null,
        ),
      ),
    );

    if (result != null && mounted) {
      setState(() {
        _selectedLocation = result['location'] as LatLng;
        if (result['address'] != null) {
          _addressController.text = result['address'] as String;
        }
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

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('✅ Location updated: ${result['address'] ?? '${_selectedLocation.latitude}, ${_selectedLocation.longitude}'}'),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please fill all required fields'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    if (_selectedVehicleTypes.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select at least one vehicle type'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final authProvider = context.read<AuthProvider>();
      final adminProvider = context.read<AdminProvider>();

      final parkingSpot = ParkingSpot(
        id: '', // Will be generated by Firestore
        name: _nameController.text.trim(),
        description: _descriptionController.text.trim(),
        address: _addressController.text.trim(),
        latitude: _selectedLocation.latitude,
        longitude: _selectedLocation.longitude,
        totalSpots: int.parse(_totalSpotsController.text),
        availableSpots: int.parse(_totalSpotsController.text),
        pricePerHour: double.parse(_pricePerHourController.text),
        amenities: _selectedAmenities,
        vehicleTypes: _selectedVehicleTypes,
        status: _status,
        ownerId: authProvider.currentUser?.id ?? '',
        contactPhone: _contactPhoneController.text.trim(),
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        images: [],
        operatingHours: {
          'monday': {'open': '00:00', 'close': '23:59'},
          'tuesday': {'open': '00:00', 'close': '23:59'},
          'wednesday': {'open': '00:00', 'close': '23:59'},
          'thursday': {'open': '00:00', 'close': '23:59'},
          'friday': {'open': '00:00', 'close': '23:59'},
          'saturday': {'open': '00:00', 'close': '23:59'},
          'sunday': {'open': '00:00', 'close': '23:59'},
        },
        rating: 0.0,
        reviewCount: 0,
      );

      await adminProvider.addParkingSpot(parkingSpot);

      if (mounted) {
        Navigator.of(context).pop(true);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Parking spot added successfully!'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      debugPrint('Error adding parking spot: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Error: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Add New Parking Spot'),
        backgroundColor: AppConfig.primaryColor,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          if (_isLoading)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(16.0),
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                ),
              ),
            ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Location Picker Card
              _buildLocationCard(),
              const SizedBox(height: 24),

              // Basic Information
              _buildSectionCard(
                title: 'Basic Information',
                icon: Icons.info_outline,
                children: [
                  _buildTextField(
                    controller: _nameController,
                    label: 'Parking Spot Name *',
                    hint: 'e.g., Downtown Parking Plaza',
                    icon: Icons.business,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter a name';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  _buildTextField(
                    controller: _descriptionController,
                    label: 'Description',
                    hint: 'Brief description of the parking spot',
                    icon: Icons.description,
                    maxLines: 3,
                  ),
                  const SizedBox(height: 16),
                  _buildTextField(
                    controller: _addressController,
                    label: 'Full Address *',
                    hint: 'Street, City, State, ZIP',
                    icon: Icons.location_on,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter an address';
                      }
                      return null;
                    },
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Capacity and Pricing
              _buildSectionCard(
                title: 'Capacity & Pricing',
                icon: Icons.attach_money,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: _buildTextField(
                          controller: _totalSpotsController,
                          label: 'Total Spots *',
                          hint: 'e.g., 50',
                          icon: Icons.local_parking,
                          keyboardType: TextInputType.number,
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Required';
                            }
                            final number = int.tryParse(value);
                            if (number == null || number <= 0) {
                              return 'Invalid';
                            }
                            return null;
                          },
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: _buildTextField(
                          controller: _pricePerHourController,
                          label: 'Price/Hour (₹) *',
                          hint: 'e.g., 100',
                          icon: Icons.currency_rupee,
                          keyboardType: TextInputType.number,
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Required';
                            }
                            final price = double.tryParse(value);
                            if (price == null || price < 0) {
                              return 'Invalid';
                            }
                            return null;
                          },
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Vehicle Types
              _buildSectionCard(
                title: 'Supported Vehicle Types *',
                icon: Icons.directions_car,
                children: [
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _vehicleTypeOptions.map((type) {
                      final isSelected = _selectedVehicleTypes.contains(type);
                      return FilterChip(
                        label: Text(
                          type.toUpperCase(),
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: isSelected ? Colors.white : Colors.black87,
                          ),
                        ),
                        selected: isSelected,
                        selectedColor: AppConfig.primaryColor,
                        checkmarkColor: Colors.white,
                        onSelected: (selected) {
                          setState(() {
                            if (selected) {
                              _selectedVehicleTypes.add(type);
                            } else {
                              if (_selectedVehicleTypes.length > 1) {
                                _selectedVehicleTypes.remove(type);
                              }
                            }
                          });
                        },
                      );
                    }).toList(),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Amenities
              _buildSectionCard(
                title: 'Amenities & Features',
                icon: Icons.star_outline,
                children: [
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _amenityOptions.map((amenity) {
                      final isSelected = _selectedAmenities.contains(amenity);
                      return FilterChip(
                        label: Text(
                          amenity,
                          style: TextStyle(
                            color: isSelected ? Colors.white : Colors.black87,
                          ),
                        ),
                        selected: isSelected,
                        selectedColor: Colors.green.shade600,
                        checkmarkColor: Colors.white,
                        onSelected: (selected) {
                          setState(() {
                            if (selected) {
                              _selectedAmenities.add(amenity);
                            } else {
                              _selectedAmenities.remove(amenity);
                            }
                          });
                        },
                      );
                    }).toList(),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Status and Contact
              _buildSectionCard(
                title: 'Status & Contact',
                icon: Icons.settings,
                children: [
                  DropdownButtonFormField<ParkingSpotStatus>(
                    value: _status,
                    decoration: InputDecoration(
                      labelText: 'Status *',
                      prefixIcon: Icon(
                        _status == ParkingSpotStatus.available
                            ? Icons.check_circle
                            : _status == ParkingSpotStatus.full
                                ? Icons.cancel
                                : Icons.build,
                        color: _status == ParkingSpotStatus.available
                            ? Colors.green
                            : _status == ParkingSpotStatus.full
                                ? Colors.red
                                : Colors.orange,
                      ),
                      border: const OutlineInputBorder(),
                      filled: true,
                      fillColor: Colors.grey.shade50,
                    ),
                    items: ParkingSpotStatus.values.map((status) {
                      return DropdownMenuItem(
                        value: status,
                        child: Row(
                          children: [
                            Icon(
                              status == ParkingSpotStatus.available
                                  ? Icons.check_circle
                                  : status == ParkingSpotStatus.full
                                      ? Icons.cancel
                                      : Icons.build,
                              size: 20,
                              color: status == ParkingSpotStatus.available
                                  ? Colors.green
                                  : status == ParkingSpotStatus.full
                                      ? Colors.red
                                      : Colors.orange,
                            ),
                            const SizedBox(width: 8),
                            Text(status.name.toUpperCase()),
                          ],
                        ),
                      );
                    }).toList(),
                    onChanged: (value) {
                      if (value != null) {
                        setState(() {
                          _status = value;
                        });
                      }
                    },
                  ),
                  const SizedBox(height: 16),
                  _buildTextField(
                    controller: _contactPhoneController,
                    label: 'Contact Phone',
                    hint: '+91 98765 43210',
                    icon: Icons.phone,
                    keyboardType: TextInputType.phone,
                  ),
                ],
              ),
              const SizedBox(height: 32),

              // Submit Button
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton.icon(
                  onPressed: _isLoading ? null : _submitForm,
                  icon: _isLoading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : const Icon(Icons.add_location, size: 24),
                  label: Text(
                    _isLoading ? 'Adding Parking Spot...' : 'Add Parking Spot',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppConfig.primaryColor,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 2,
                  ),
                ),
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLocationCard() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppConfig.primaryColor.withOpacity(0.1),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(12),
                topRight: Radius.circular(12),
              ),
            ),
            child: Row(
              children: [
                Icon(Icons.map, color: AppConfig.primaryColor, size: 28),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Parking Location',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: AppConfig.primaryColor,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Tap on map to select exact location',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade700,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () {
                    setState(() {
                      _showMap = !_showMap;
                      if (_showMap) {
                        _isMapLoading = true;
                        _mapError = null;
                      }
                    });
                  },
                  icon: Icon(
                    _showMap ? Icons.expand_less : Icons.expand_more,
                    color: AppConfig.primaryColor,
                  ),
                  tooltip: _showMap ? 'Hide Map' : 'Show Map',
                ),
              ],
            ),
          ),

          // Location Info
          Container(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.blue.shade50,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.blue.shade200),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(Icons.location_on, color: Colors.blue.shade700, size: 20),
                                const SizedBox(width: 8),
                                Text(
                                  'Selected Coordinates',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.blue.shade900,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Lat: ${_selectedLocation.latitude.toStringAsFixed(6)}',
                              style: TextStyle(
                                color: Colors.blue.shade800,
                                fontSize: 13,
                                fontFamily: 'monospace',
                              ),
                            ),
                            Text(
                              'Lng: ${_selectedLocation.longitude.toStringAsFixed(6)}',
                              style: TextStyle(
                                color: Colors.blue.shade800,
                                fontSize: 13,
                                fontFamily: 'monospace',
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    SizedBox(
                      width: 90,
                      child: ElevatedButton(
                        onPressed: _getCurrentLocation,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue.shade600,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: const Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.my_location, size: 20),
                            SizedBox(height: 4),
                            Text(
                              'Current',
                              style: TextStyle(fontSize: 11),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _openLocationPicker,
                    icon: const Icon(Icons.map, size: 20),
                    label: const Text('Open Map & Search Location'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppConfig.primaryColor,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Map View
          if (_showMap)
            Container(
              height: 400,
              margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade300, width: 2),
              ),
              clipBehavior: Clip.antiAlias,
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
                    indoorViewEnabled: true,
                    onCameraMoveStarted: () {
                      debugPrint('🗺️ Camera move started');
                    },
                    onCameraIdle: () {
                      debugPrint('🗺️ Camera idle');
                    },
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
                  // Error message overlay
                  if (_mapError != null && !_isMapLoading)
                    Positioned(
                      top: 8,
                      left: 8,
                      right: 8,
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.red.shade50,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.red.shade300),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.error_outline, color: Colors.red.shade700, size: 20),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _mapError!,
                                style: TextStyle(
                                  color: Colors.red.shade900,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.close, size: 18),
                              color: Colors.red.shade700,
                              onPressed: () {
                                setState(() {
                                  _mapError = null;
                                });
                              },
                            ),
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
                                'Tap to drop pin • Drag marker to adjust',
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
                  // Custom zoom controls
                  Positioned(
                    right: 16,
                    bottom: 80,
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
                      ],
                    ),
                  ),
                  // My location button
                  Positioned(
                    right: 16,
                    bottom: 16,
                    child: FloatingActionButton.small(
                      heroTag: 'my_location',
                      onPressed: _getCurrentLocation,
                      backgroundColor: Colors.white,
                      child: const Icon(Icons.my_location, color: Colors.blue),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSectionCard({
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: AppConfig.primaryColor, size: 24),
                const SizedBox(width: 12),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppConfig.primaryColor,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    String? hint,
    IconData? icon,
    int maxLines = 1,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: icon != null ? Icon(icon) : null,
        border: const OutlineInputBorder(),
        filled: true,
        fillColor: Colors.grey.shade50,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      ),
      maxLines: maxLines,
      keyboardType: keyboardType,
      validator: validator,
    );
  }
}
