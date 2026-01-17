// lib/screens/parking/add_parking_spot_dialog.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/admin_provider.dart';
import '../../providers/auth_provider.dart';
import '../../models/parking_spot.dart';

class AddParkingSpotDialog extends StatefulWidget {
  const AddParkingSpotDialog({super.key});

  @override
  State<AddParkingSpotDialog> createState() => _AddParkingSpotDialogState();
}

class _AddParkingSpotDialogState extends State<AddParkingSpotDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _latitudeController = TextEditingController();
  final _longitudeController = TextEditingController();
  final _totalSpotsController = TextEditingController(text: '1');
  final _pricePerHourController = TextEditingController(text: '2.00');
  
  bool _isFreeParking = false;
  bool _isVerified = false;

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _latitudeController.dispose();
    _longitudeController.dispose();
    _totalSpotsController.dispose();
    _pricePerHourController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Add Parking Space'),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Name',
                  hintText: 'e.g. My Driveway Parking',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter a name';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _descriptionController,
                decoration: const InputDecoration(
                  labelText: 'Description',
                  hintText: 'e.g. Private parking space available for booking',
                  border: OutlineInputBorder(),
                ),
                maxLines: 2,
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _latitudeController,
                      decoration: const InputDecoration(
                        labelText: 'Latitude',
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.number,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Required';
                        }
                        double? lat = double.tryParse(value);
                        if (lat == null || lat < -90 || lat > 90) {
                          return 'Invalid latitude';
                        }
                        return null;
                      },
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: TextFormField(
                      controller: _longitudeController,
                      decoration: const InputDecoration(
                        labelText: 'Longitude',
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.number,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Required';
                        }
                        double? lng = double.tryParse(value);
                        if (lng == null || lng < -180 || lng > 180) {
                          return 'Invalid longitude';
                        }
                        return null;
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _totalSpotsController,
                      decoration: const InputDecoration(
                        labelText: 'Total Spots',
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.number,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Required';
                        }
                        int? spots = int.tryParse(value);
                        if (spots == null || spots < 1) {
                          return 'Min 1';
                        }
                        return null;
                      },
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Parking Type',
                          style: TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                        const SizedBox(height: 8),
                        DropdownButtonFormField<bool>(
                          value: _isFreeParking,
                          decoration: const InputDecoration(
                            border: OutlineInputBorder(),
                            contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          ),
                          items: const [
                            DropdownMenuItem(
                              value: false,
                              child: Text('Paid Parking'),
                            ),
                            DropdownMenuItem(
                              value: true,
                              child: Text('Free Parking'),
                            ),
                          ],
                          onChanged: (value) {
                            setState(() {
                              _isFreeParking = value ?? false;
                              if (_isFreeParking) {
                                _pricePerHourController.text = '0.00';
                              } else if (_pricePerHourController.text == '0.00') {
                                _pricePerHourController.text = '2.00';
                              }
                            });
                          },
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
                        if (!_isFreeParking) ...[
                          TextFormField(
                            controller: _pricePerHourController,
                            decoration: const InputDecoration(
                              labelText: 'Price/Hour',
                              prefixText: '₹',
                              border: OutlineInputBorder(),
                            ),
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            validator: (value) {
                              if (!_isFreeParking) {
                                if (value == null || value.isEmpty) {
                                  return 'Required';
                                }
                                double? price = double.tryParse(value);
                                if (price == null || price <= 0) {
                                  return 'Invalid';
                                }
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 16),
                        ],              // Admin-only verification checkbox
              Consumer<AuthProvider>(
                builder: (context, authProvider, child) {
                  if (authProvider.isAdmin) {
                    return CheckboxListTile(
                      title: const Text('Verified'),
                      subtitle: const Text('Mark as verified parking spot'),
                      value: _isVerified,
                      onChanged: (value) {
                        setState(() {
                          _isVerified = value ?? false;
                        });
                      },
                      controlAffinity: ListTileControlAffinity.leading,
                    );
                  }
                  return const SizedBox.shrink();
                },
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('CANCEL'),
        ),
        Consumer<AdminProvider>(
          builder: (context, adminProvider, child) {
            return ElevatedButton(
              onPressed: adminProvider.parkingSpotsLoading ? null : _addParkingSpot,
              child: adminProvider.parkingSpotsLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('SAVE'),
            );
          },
        ),
      ],
    );
  }

  Future<void> _addParkingSpot() async {
    if (!_formKey.currentState!.validate()) return;

    final authProvider = context.read<AuthProvider>();
    final adminProvider = context.read<AdminProvider>();

    // Calculate price based on parking type
    final finalPrice = _isFreeParking ? 0.0 : double.parse(_pricePerHourController.text.trim());
    
    // Add parking type to amenities
    final finalAmenities = <String>[];
    if (_isFreeParking) {
      finalAmenities.add('Free Parking');
    }
    
    // Enhanced description with parking type info
    final enhancedDescription = _isFreeParking 
        ? '${_descriptionController.text.trim()}\n\n🎉 FREE PARKING AVAILABLE!'
        : _descriptionController.text.trim().isEmpty
            ? 'Parking space available for booking'
            : _descriptionController.text.trim();

    final parkingSpot = ParkingSpot(
      id: '', // Will be generated by Firestore
      name: _nameController.text.trim(),
      description: enhancedDescription,
      address: '${_latitudeController.text.trim()}, ${_longitudeController.text.trim()}', // Simple address from coordinates
      latitude: double.parse(_latitudeController.text.trim()),
      longitude: double.parse(_longitudeController.text.trim()),
      totalSpots: int.parse(_totalSpotsController.text.trim()),
      availableSpots: int.parse(_totalSpotsController.text.trim()), // Initially all available
      pricePerHour: finalPrice,
      contactPhone: null,
      amenities: finalAmenities,
      vehicleTypes: ['car'], // Default vehicle type
      ownerId: authProvider.currentUser?.id ?? 'admin',
      status: ParkingSpotStatus.available,
      isVerified: _isVerified,
      operatingHours: {
        'monday': {'open': '08:00', 'close': '20:00'},
        'tuesday': {'open': '08:00', 'close': '20:00'},
        'wednesday': {'open': '08:00', 'close': '20:00'},
        'thursday': {'open': '08:00', 'close': '20:00'},
        'friday': {'open': '08:00', 'close': '20:00'},
        'saturday': {'open': '08:00', 'close': '20:00'},
        'sunday': {'open': '08:00', 'close': '20:00'},
      },
      accessibility: {
        'wheelchair': false,
        'elevator': false,
        'ramp': false,
      },
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    try {
      await adminProvider.addParkingSpot(parkingSpot);
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Parking spot added successfully!'),
            backgroundColor: Colors.green,
          ),
        );
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
    }
  }
}
