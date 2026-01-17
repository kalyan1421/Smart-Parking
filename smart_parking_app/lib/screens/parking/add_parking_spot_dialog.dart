// lib/screens/parking/add_parking_spot_dialog.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'dart:async';

import '../../providers/parking_provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/location_provider.dart';
import '../../models/parking_spot.dart';
import '../../config/app_config.dart';
import '../../config/theme.dart';
import '../../widgets/common/loading_indicator.dart';

class AddParkingSpotDialog extends StatefulWidget {
  const AddParkingSpotDialog({super.key});

  @override
  State<AddParkingSpotDialog> createState() => _AddParkingSpotDialogState();
}

class _AddParkingSpotDialogState extends State<AddParkingSpotDialog> with TickerProviderStateMixin {
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
  bool _isMapReady = false;
  late TabController _tabController;

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
  ];

  final List<String> _vehicleTypeOptions = [
    'car',
    'motorcycle',
    'bicycle',
    'truck',
    'rv',
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _getCurrentLocation();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _addressController.dispose();
    _totalSpotsController.dispose();
    _pricePerHourController.dispose();
    _contactPhoneController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _getCurrentLocation() async {
    try {
      final locationProvider = Provider.of<LocationProvider>(context, listen: false);
      if (locationProvider.hasLocation && locationProvider.currentLocation != null) {
        final position = locationProvider.currentLocation!;
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
      } else {
        // Fallback to geolocator
        bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
        if (!serviceEnabled) {
          return;
        }

        LocationPermission permission = await Geolocator.checkPermission();
        if (permission == LocationPermission.denied) {
          permission = await Geolocator.requestPermission();
          if (permission == LocationPermission.denied) {
            return;
          }
        }

        if (permission == LocationPermission.deniedForever) {
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
      }
    } catch (e) {
      debugPrint('Error getting location: $e');
    }
  }

  void _updateMarker(LatLng location) {
    setState(() {
      _selectedLocation = location;
      _markers = {
        Marker(
          markerId: const MarkerId('selected_location'),
          position: location,
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
          infoWindow: const InfoWindow(
            title: 'Selected Parking Location',
            snippet: 'Tap to confirm this location',
          ),
        ),
      };
    });
  }

  void _onMapCreated(GoogleMapController controller) {
    _mapController = controller;
    setState(() {
      _isMapReady = true;
    });
    _updateMarker(_selectedLocation);
  }

  void _onMapTapped(LatLng location) {
    _updateMarker(location);
  }

  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final authProvider = context.read<AuthProvider>();
      final parkingProvider = context.read<ParkingProvider>();

      if (authProvider.currentUser == null) {
        throw Exception('User not logged in');
      }

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
        ownerId: authProvider.currentUser!.id,
        contactPhone: _contactPhoneController.text.trim().isEmpty 
            ? null 
            : _contactPhoneController.text.trim(),
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        images: [], // Can be added later
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

      final success = await parkingProvider.addParkingSpot(parkingSpot);

      if (mounted) {
        if (success) {
          Navigator.of(context).pop(true);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Parking spot added successfully!'),
              backgroundColor: Colors.green,
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error: ${parkingProvider.error ?? "Failed to add parking spot"}'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error adding parking spot: $e'),
            backgroundColor: Colors.red,
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
    return Dialog(
      child: Container(
        width: MediaQuery.of(context).size.width * 0.9,
        height: MediaQuery.of(context).size.height * 0.9,
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Add New Parking Spot',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).primaryColor,
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            const SizedBox(height: 16),
            
            // Tab Bar
            TabBar(
              controller: _tabController,
              tabs: const [
                Tab(icon: Icon(Icons.info), text: 'Details'),
                Tab(icon: Icon(Icons.map), text: 'Location'),
              ],
            ),
            const SizedBox(height: 16),
            
            // Tab Views
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildDetailsTab(),
                  _buildMapTab(),
                ],
              ),
            ),
            
            const SizedBox(height: 16),
            
            // Action Buttons
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: _isLoading ? null : () => Navigator.of(context).pop(),
                  child: const Text('Cancel'),
                ),
                const SizedBox(width: 16),
                ElevatedButton(
                  onPressed: _isLoading ? null : _submitForm,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).primaryColor,
                    foregroundColor: Colors.white,
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : const Text('Add Parking Spot'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailsTab() {
    return SingleChildScrollView(
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Basic Information
            _buildSectionTitle('Basic Information'),
            const SizedBox(height: 12),
            _buildTextField(
              controller: _nameController,
              label: 'Parking Spot Name',
              hint: 'e.g., Downtown Parking Plaza',
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
              maxLines: 3,
            ),
            const SizedBox(height: 16),
            _buildTextField(
              controller: _addressController,
              label: 'Address',
              hint: 'Full address of the parking spot',
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter an address';
                }
                return null;
              },
            ),
            const SizedBox(height: 24),

            // Capacity and Pricing
            _buildSectionTitle('Capacity & Pricing'),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _buildTextField(
                    controller: _totalSpotsController,
                    label: 'Total Spots',
                    hint: 'Number of parking spots',
                    keyboardType: TextInputType.number,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Required';
                      }
                      final number = int.tryParse(value);
                      if (number == null || number <= 0) {
                        return 'Enter valid number';
                      }
                      return null;
                    },
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildTextField(
                    controller: _pricePerHourController,
                    label: 'Price per Hour (${AppConfig.currencySymbol})',
                    hint: '0.00',
                    keyboardType: TextInputType.number,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Required';
                      }
                      final price = double.tryParse(value);
                      if (price == null || price < 0) {
                        return 'Enter valid price';
                      }
                      return null;
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Vehicle Types
            _buildSectionTitle('Supported Vehicle Types'),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _vehicleTypeOptions.map((type) {
                return FilterChip(
                  label: Text(type.toUpperCase()),
                  selected: _selectedVehicleTypes.contains(type),
                  onSelected: (selected) {
                    setState(() {
                      if (selected) {
                        _selectedVehicleTypes.add(type);
                      } else {
                        _selectedVehicleTypes.remove(type);
                      }
                    });
                  },
                );
              }).toList(),
            ),
            const SizedBox(height: 24),

            // Amenities
            _buildSectionTitle('Amenities'),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _amenityOptions.map((amenity) {
                return FilterChip(
                  label: Text(amenity),
                  selected: _selectedAmenities.contains(amenity),
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
            const SizedBox(height: 24),

            // Status and Contact
            _buildSectionTitle('Status & Contact'),
            const SizedBox(height: 12),
            DropdownButtonFormField<ParkingSpotStatus>(
              value: _status,
              decoration: const InputDecoration(
                labelText: 'Status',
                border: OutlineInputBorder(),
              ),
              items: ParkingSpotStatus.values.map((status) {
                return DropdownMenuItem(
                  value: status,
                  child: Text(status.name.toUpperCase()),
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
              label: 'Contact Phone (Optional)',
              hint: '+91 1234567890',
              keyboardType: TextInputType.phone,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMapTab() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Select Parking Location',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Tap on the map to select the exact location of your parking spot.',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: Colors.grey[600],
          ),
        ),
        const SizedBox(height: 16),
        
        // Location Info
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.blue.shade50,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.blue.shade200),
          ),
          child: Row(
            children: [
              Icon(Icons.location_on, color: Colors.blue.shade600),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Selected Location:',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.blue.shade800,
                      ),
                    ),
                    Text(
                      'Lat: ${_selectedLocation.latitude.toStringAsFixed(6)}',
                      style: TextStyle(color: Colors.blue.shade700),
                    ),
                    Text(
                      'Lng: ${_selectedLocation.longitude.toStringAsFixed(6)}',
                      style: TextStyle(color: Colors.blue.shade700),
                    ),
                  ],
                ),
              ),
              ElevatedButton.icon(
                onPressed: _getCurrentLocation,
                icon: const Icon(Icons.my_location, size: 16),
                label: const Text('Current'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue.shade600,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        
        // Map
        Expanded(
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade300),
            ),
            clipBehavior: Clip.antiAlias,
            child: GoogleMap(
              onMapCreated: _onMapCreated,
              initialCameraPosition: CameraPosition(
                target: _selectedLocation,
                zoom: 15.0,
              ),
              markers: _markers,
              onTap: _onMapTapped,
              myLocationEnabled: true,
              myLocationButtonEnabled: true,
              mapType: MapType.normal,
              zoomControlsEnabled: true,
              compassEnabled: true,
              scrollGesturesEnabled: true,
              zoomGesturesEnabled: true,
              rotateGesturesEnabled: true,
              tiltGesturesEnabled: false,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: Theme.of(context).textTheme.titleMedium?.copyWith(
        fontWeight: FontWeight.bold,
        color: Theme.of(context).primaryColor,
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    String? hint,
    int maxLines = 1,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        border: const OutlineInputBorder(),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      ),
      maxLines: maxLines,
      keyboardType: keyboardType,
      validator: validator,
    );
  }
}
