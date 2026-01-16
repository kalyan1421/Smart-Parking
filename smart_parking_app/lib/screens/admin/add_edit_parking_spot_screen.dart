// lib/screens/admin/add_edit_parking_spot_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:smart_parking_app/models/parking_spot.dart';
import 'package:smart_parking_app/providers/auth_provider.dart';
import 'package:smart_parking_app/providers/parking_provider.dart';
import 'package:smart_parking_app/providers/location_provider.dart';
import 'package:smart_parking_app/config/app_config.dart';

class AddEditParkingSpotScreen extends StatefulWidget {
  final ParkingSpot? parkingSpot;

  const AddEditParkingSpotScreen({Key? key, this.parkingSpot}) : super(key: key);

  @override
  _AddEditParkingSpotScreenState createState() => _AddEditParkingSpotScreenState();
}

class _AddEditParkingSpotScreenState extends State<AddEditParkingSpotScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _addressController;
  late TextEditingController _descriptionController;
  late TextEditingController _priceController;
  late TextEditingController _totalSpotsController;
  late TextEditingController _latController;
  late TextEditingController _lngController;
  
  List<String> _selectedAmenities = [];
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    final spot = widget.parkingSpot;
    _nameController = TextEditingController(text: spot?.name ?? '');
    _addressController = TextEditingController(text: spot?.address ?? '');
    _descriptionController = TextEditingController(text: spot?.description ?? '');
    _priceController = TextEditingController(text: spot?.pricePerHour.toString() ?? '');
    _totalSpotsController = TextEditingController(text: spot?.totalSpots.toString() ?? '');
    _latController = TextEditingController(text: spot?.latitude.toString() ?? '');
    _lngController = TextEditingController(text: spot?.longitude.toString() ?? '');
    _selectedAmenities = spot != null ? List.from(spot.amenities) : [];
    
    if (spot == null) {
      _getCurrentLocation();
    }
  }

  Future<void> _getCurrentLocation() async {
    final locationProvider = Provider.of<LocationProvider>(context, listen: false);
    if (locationProvider.currentLocation != null) {
      _latController.text = locationProvider.currentLocation!.latitude.toString();
      _lngController.text = locationProvider.currentLocation!.longitude.toString();
    } else {
      await locationProvider.getCurrentLocation();
      if (locationProvider.currentLocation != null && mounted) {
        _latController.text = locationProvider.currentLocation!.latitude.toString();
        _lngController.text = locationProvider.currentLocation!.longitude.toString();
      }
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _addressController.dispose();
    _descriptionController.dispose();
    _priceController.dispose();
    _totalSpotsController.dispose();
    _latController.dispose();
    _lngController.dispose();
    super.dispose();
  }

  Future<void> _saveSpot() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final parkingProvider = Provider.of<ParkingProvider>(context, listen: false);
      final currentUser = authProvider.currentUser!;

      final double price = double.parse(_priceController.text);
      final int totalSpots = int.parse(_totalSpotsController.text);
      final double lat = double.parse(_latController.text);
      final double lng = double.parse(_lngController.text);

      final spot = ParkingSpot(
        id: widget.parkingSpot?.id ?? '', // ID handled by provider for new spots
        name: _nameController.text.trim(),
        address: _addressController.text.trim(),
        description: _descriptionController.text.trim(),
        pricePerHour: price,
        totalSpots: totalSpots,
        availableSpots: widget.parkingSpot?.availableSpots ?? totalSpots,
        latitude: lat,
        longitude: lng,
        amenities: _selectedAmenities,
        ownerId: widget.parkingSpot?.ownerId ?? currentUser.id,
        createdAt: widget.parkingSpot?.createdAt ?? DateTime.now(),
        updatedAt: DateTime.now(),
        isVerified: widget.parkingSpot?.isVerified ?? false, // New spots need verification? or auto-verify for admin
      );

      bool success;
      if (widget.parkingSpot == null) {
        success = await parkingProvider.addParkingSpot(spot);
      } else {
        success = await parkingProvider.updateParkingSpot(spot);
      }

      if (success && mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(widget.parkingSpot == null ? 'Spot added successfully' : 'Spot updated successfully')),
        );
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(parkingProvider.error ?? 'Failed to save spot')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.parkingSpot == null ? 'Add Parking Spot' : 'Edit Parking Spot'),
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Basic Info', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              SizedBox(height: 8),
              TextFormField(
                controller: _nameController,
                decoration: InputDecoration(labelText: 'Spot Name', border: OutlineInputBorder()),
                validator: (v) => v?.isEmpty == true ? 'Required' : null,
              ),
              SizedBox(height: 16),
              TextFormField(
                controller: _addressController,
                decoration: InputDecoration(labelText: 'Address', border: OutlineInputBorder()),
                validator: (v) => v?.isEmpty == true ? 'Required' : null,
              ),
              SizedBox(height: 16),
              TextFormField(
                controller: _descriptionController,
                decoration: InputDecoration(labelText: 'Description', border: OutlineInputBorder()),
                maxLines: 3,
              ),
              SizedBox(height: 24),
              
              Text('Details', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _priceController,
                      decoration: InputDecoration(labelText: 'Price/Hr (${AppConfig.currencySymbol})', border: OutlineInputBorder()),
                      keyboardType: TextInputType.number,
                      validator: (v) => v?.isEmpty == true ? 'Required' : null,
                    ),
                  ),
                  SizedBox(width: 16),
                  Expanded(
                    child: TextFormField(
                      controller: _totalSpotsController,
                      decoration: InputDecoration(labelText: 'Total Spots', border: OutlineInputBorder()),
                      keyboardType: TextInputType.number,
                      validator: (v) => v?.isEmpty == true ? 'Required' : null,
                    ),
                  ),
                ],
              ),
              SizedBox(height: 24),
              
              Text('Location', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _latController,
                      decoration: InputDecoration(labelText: 'Latitude', border: OutlineInputBorder()),
                      keyboardType: TextInputType.number,
                      validator: (v) => v?.isEmpty == true ? 'Required' : null,
                    ),
                  ),
                  SizedBox(width: 16),
                  Expanded(
                    child: TextFormField(
                      controller: _lngController,
                      decoration: InputDecoration(labelText: 'Longitude', border: OutlineInputBorder()),
                      keyboardType: TextInputType.number,
                      validator: (v) => v?.isEmpty == true ? 'Required' : null,
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.my_location),
                    onPressed: _getCurrentLocation,
                    tooltip: 'Use Current Location',
                  ),
                ],
              ),
              SizedBox(height: 24),
              
              Text('Amenities', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              Wrap(
                spacing: 8,
                children: AppConfig.parkingAmenities.map((amenity) {
                  return FilterChip(
                    label: Text(amenity.replaceAll('_', ' ').toUpperCase()),
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
              
              SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isSaving ? null : _saveSpot,
                  style: ElevatedButton.styleFrom(padding: EdgeInsets.symmetric(vertical: 16)),
                  child: _isSaving 
                      ? SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2)) 
                      : Text(widget.parkingSpot == null ? 'CREATE SPOT' : 'UPDATE SPOT'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
