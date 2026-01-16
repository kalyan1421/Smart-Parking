// lib/screens/profile/vehicles/add_vehicle_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../models/vehicle.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/vehicle_provider.dart';

class AddVehicleScreen extends StatefulWidget {
  final Vehicle? vehicle; // For editing

  AddVehicleScreen({this.vehicle});

  @override
  _AddVehicleScreenState createState() => _AddVehicleScreenState();
}

class _AddVehicleScreenState extends State<AddVehicleScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _licensePlateController;
  late TextEditingController _makeController;
  late TextEditingController _modelController;
  late TextEditingController _colorController;
  VehicleType _selectedType = VehicleType.car;
  bool _isDefault = false;

  @override
  void initState() {
    super.initState();
    _licensePlateController = TextEditingController(text: widget.vehicle?.licensePlate ?? '');
    _makeController = TextEditingController(text: widget.vehicle?.make ?? '');
    _modelController = TextEditingController(text: widget.vehicle?.model ?? '');
    _colorController = TextEditingController(text: widget.vehicle?.color ?? '');
    _selectedType = widget.vehicle?.type ?? VehicleType.car;
    _isDefault = widget.vehicle?.isDefault ?? false;
  }

  @override
  void dispose() {
    _licensePlateController.dispose();
    _makeController.dispose();
    _modelController.dispose();
    _colorController.dispose();
    super.dispose();
  }

  Future<void> _saveVehicle() async {
    if (!_formKey.currentState!.validate()) return;

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final vehicleProvider = Provider.of<VehicleProvider>(context, listen: false);

    final vehicle = Vehicle(
      id: widget.vehicle?.id ?? '',
      userId: authProvider.currentUser!.id,
      licensePlate: _licensePlateController.text.trim().toUpperCase(),
      make: _makeController.text.trim(),
      model: _modelController.text.trim(),
      year: DateTime.now().year,
      type: _selectedType,
      color: _colorController.text.trim(),
      isDefault: _isDefault,
      createdAt: widget.vehicle?.createdAt ?? DateTime.now(),
      updatedAt: DateTime.now(),
    );

    bool success;
    if (widget.vehicle == null) {
      success = await vehicleProvider.addVehicle(vehicle);
    } else {
      success = await vehicleProvider.updateVehicle(vehicle);
    }

    if (success && mounted) {
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.vehicle == null ? 'Add Vehicle' : 'Edit Vehicle'),
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                controller: _licensePlateController,
                decoration: InputDecoration(labelText: 'License Plate (e.g. TS09EA1234)', border: OutlineInputBorder()),
                textCapitalization: TextCapitalization.characters,
                validator: (value) => value == null || value.isEmpty ? 'Enter license plate' : null,
              ),
              SizedBox(height: 16),
              DropdownButtonFormField<VehicleType>(
                value: _selectedType,
                decoration: InputDecoration(labelText: 'Vehicle Type', border: OutlineInputBorder()),
                items: VehicleType.values.map((type) {
                  return DropdownMenuItem(
                    value: type,
                    child: Text(type.name.toUpperCase()),
                  );
                }).toList(),
                onChanged: (value) => setState(() => _selectedType = value!),
              ),
              SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _makeController,
                      decoration: InputDecoration(labelText: 'Make (e.g. Toyota)', border: OutlineInputBorder()),
                      validator: (value) => value == null || value.isEmpty ? 'Enter make' : null,
                    ),
                  ),
                  SizedBox(width: 16),
                  Expanded(
                    child: TextFormField(
                      controller: _modelController,
                      decoration: InputDecoration(labelText: 'Model (e.g. Camry)', border: OutlineInputBorder()),
                      validator: (value) => value == null || value.isEmpty ? 'Enter model' : null,
                    ),
                  ),
                ],
              ),
              SizedBox(height: 16),
              TextFormField(
                controller: _colorController,
                decoration: InputDecoration(labelText: 'Color', border: OutlineInputBorder()),
              ),
              SizedBox(height: 16),
              SwitchListTile(
                title: Text('Set as Default Vehicle'),
                value: _isDefault,
                onChanged: (value) => setState(() => _isDefault = value),
              ),
              SizedBox(height: 32),
              ElevatedButton(
                onPressed: _saveVehicle,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Text(widget.vehicle == null ? 'ADD VEHICLE' : 'SAVE CHANGES'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
