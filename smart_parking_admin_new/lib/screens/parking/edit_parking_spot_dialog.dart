// lib/screens/parking/edit_parking_spot_dialog.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/admin_provider.dart';
import '../../providers/auth_provider.dart';
import '../../models/parking_spot.dart';
import '../../config/app_config.dart';

class EditParkingSpotDialog extends StatefulWidget {
  final ParkingSpot parkingSpot;
  
  const EditParkingSpotDialog({super.key, required this.parkingSpot});

  @override
  State<EditParkingSpotDialog> createState() => _EditParkingSpotDialogState();
}

class _EditParkingSpotDialogState extends State<EditParkingSpotDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _descriptionController;
  late final TextEditingController _addressController;
  late final TextEditingController _totalSpotsController;
  late final TextEditingController _availableSpotsController;
  late final TextEditingController _pricePerHourController;
  late final TextEditingController _contactPhoneController;

  late List<String> _selectedAmenities;
  late List<String> _selectedVehicleTypes;
  late ParkingSpotStatus _status;
  late bool _isVerified;

  final List<String> _availableAmenities = [
    'WiFi',
    'Security Camera',
    'Covered Parking',
    'Electric Vehicle Charging',
    'Restroom',
    '24/7 Access',
    'Valet Service',
    'Car Wash',
    'Wheelchair Accessible',
    'Lighting',
  ];

  final List<String> _availableVehicleTypes = [
    'car',
    'motorcycle',
    'bicycle',
    'truck',
    'van',
  ];

  @override
  void initState() {
    super.initState();
    _initializeControllers();
  }

  void _initializeControllers() {
    final spot = widget.parkingSpot;
    
    _nameController = TextEditingController(text: spot.name);
    _descriptionController = TextEditingController(text: spot.description);
    _addressController = TextEditingController(text: spot.address);
    _totalSpotsController = TextEditingController(text: spot.totalSpots.toString());
    _availableSpotsController = TextEditingController(text: spot.availableSpots.toString());
    _pricePerHourController = TextEditingController(text: spot.pricePerHour.toString());
    _contactPhoneController = TextEditingController(text: spot.contactPhone ?? '');
    
    _selectedAmenities = List.from(spot.amenities);
    _selectedVehicleTypes = List.from(spot.vehicleTypes);
    _status = spot.status;
    _isVerified = spot.isVerified;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _addressController.dispose();
    _totalSpotsController.dispose();
    _availableSpotsController.dispose();
    _pricePerHourController.dispose();
    _contactPhoneController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: Container(
        width: 600,
        constraints: const BoxConstraints(maxHeight: 700),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Color(AppConfig.colors['primary']),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(12),
                  topRight: Radius.circular(12),
                ),
              ),
              child: Row(
                children: [
                  const Icon(Icons.edit_location, color: Colors.white, size: 24),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Edit ${widget.parkingSpot.name}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close, color: Colors.white),
                  ),
                ],
              ),
            ),
            
            // Form
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Basic Information
                      Text(
                        'Basic Information',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 16),
                      
                      TextFormField(
                        controller: _nameController,
                        decoration: const InputDecoration(
                          labelText: 'Parking Spot Name *',
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please enter a name';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      
                      TextFormField(
                        controller: _descriptionController,
                        decoration: const InputDecoration(
                          labelText: 'Description *',
                        ),
                        maxLines: 3,
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please enter a description';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      
                      TextFormField(
                        controller: _addressController,
                        decoration: const InputDecoration(
                          labelText: 'Address *',
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please enter an address';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 24),
                      
                      // Capacity and Pricing
                      Text(
                        'Capacity & Pricing',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 16),
                      
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: _totalSpotsController,
                              decoration: const InputDecoration(
                                labelText: 'Total Spots *',
                              ),
                              keyboardType: TextInputType.number,
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'Required';
                                }
                                final spots = int.tryParse(value);
                                if (spots == null || spots <= 0) {
                                  return 'Invalid number';
                                }
                                return null;
                              },
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: TextFormField(
                              controller: _availableSpotsController,
                              decoration: const InputDecoration(
                                labelText: 'Available Spots *',
                              ),
                              keyboardType: TextInputType.number,
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'Required';
                                }
                                final available = int.tryParse(value);
                                final total = int.tryParse(_totalSpotsController.text);
                                if (available == null || available < 0) {
                                  return 'Invalid number';
                                }
                                if (total != null && available > total) {
                                  return 'Cannot exceed total';
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
                              controller: _pricePerHourController,
                              decoration: const InputDecoration(
                                labelText: 'Price per Hour (\$) *',
                              ),
                              keyboardType: TextInputType.number,
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'Required';
                                }
                                final price = double.tryParse(value);
                                if (price == null || price < 0) {
                                  return 'Invalid price';
                                }
                                return null;
                              },
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: TextFormField(
                              controller: _contactPhoneController,
                              decoration: const InputDecoration(
                                labelText: 'Contact Phone',
                              ),
                              keyboardType: TextInputType.phone,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      
                      // Vehicle Types
                      Text(
                        'Supported Vehicle Types',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 16),
                      
                      Wrap(
                        spacing: 8,
                        children: _availableVehicleTypes.map((type) {
                          final isSelected = _selectedVehicleTypes.contains(type);
                          return FilterChip(
                            label: Text(type.toUpperCase()),
                            selected: isSelected,
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
                      Text(
                        'Amenities',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 16),
                      
                      Wrap(
                        spacing: 8,
                        children: _availableAmenities.map((amenity) {
                          final isSelected = _selectedAmenities.contains(amenity);
                          return FilterChip(
                            label: Text(amenity),
                            selected: isSelected,
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
                      
                      // Status and Verification
                      Text(
                        'Status & Settings',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 16),
                      
                      DropdownButtonFormField<ParkingSpotStatus>(
                        value: _status,
                        decoration: const InputDecoration(
                          labelText: 'Status',
                        ),
                        items: ParkingSpotStatus.values.map((status) {
                          return DropdownMenuItem(
                            value: status,
                            child: Text(status.name.toUpperCase()),
                          );
                        }).toList(),
                        onChanged: (value) {
                          setState(() {
                            _status = value!;
                          });
                        },
                      ),
                      const SizedBox(height: 16),
                      
                      Consumer<AuthProvider>(
                        builder: (context, authProvider, child) {
                          // Only admin can change verified status
                          if (authProvider.isAdmin) {
                            return CheckboxListTile(
                              title: const Text('Verified'),
                              subtitle: const Text('Mark this parking spot as verified'),
                              value: _isVerified,
                              onChanged: (value) {
                                setState(() {
                                  _isVerified = value ?? false;
                                });
                              },
                            );
                          }
                          return const SizedBox.shrink();
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ),
            
            // Actions
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(12),
                  bottomRight: Radius.circular(12),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Cancel'),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Consumer<AdminProvider>(
                      builder: (context, adminProvider, child) {
                        return ElevatedButton(
                          onPressed: adminProvider.parkingSpotsLoading 
                              ? null 
                              : _updateParkingSpot,
                          child: adminProvider.parkingSpotsLoading
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                )
                              : const Text('Update Parking Spot'),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _updateParkingSpot() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedVehicleTypes.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select at least one vehicle type')),
      );
      return;
    }

    final adminProvider = context.read<AdminProvider>();

    final updates = <String, dynamic>{
      'name': _nameController.text.trim(),
      'description': _descriptionController.text.trim(),
      'address': _addressController.text.trim(),
      'totalSpots': int.parse(_totalSpotsController.text.trim()),
      'availableSpots': int.parse(_availableSpotsController.text.trim()),
      'pricePerHour': double.parse(_pricePerHourController.text.trim()),
      'contactPhone': _contactPhoneController.text.trim().isEmpty 
          ? null 
          : _contactPhoneController.text.trim(),
      'amenities': _selectedAmenities,
      'vehicleTypes': _selectedVehicleTypes,
      'status': _status.name,
      'isVerified': _isVerified,
    };

    try {
      await adminProvider.updateParkingSpot(widget.parkingSpot.id, updates);
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Parking spot updated successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error updating parking spot: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}
