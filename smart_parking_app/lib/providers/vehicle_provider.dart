// lib/providers/vehicle_provider.dart
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../core/database/database_service.dart';
import '../models/vehicle.dart';

class VehicleProvider with ChangeNotifier {
  List<Vehicle> _vehicles = [];
  bool _isLoading = false;
  String? _error;

  // Getters
  List<Vehicle> get vehicles => _vehicles;
  bool get isLoading => _isLoading;
  String? get error => _error;

  // Load user vehicles
  Future<void> loadUserVehicles(String userId) async {
    _setLoading(true);
    try {
      final querySnapshot = await DatabaseService.collection('vehicles')
          .where('userId', isEqualTo: userId)
          .orderBy('createdAt', descending: true)
          .get();
      
      _vehicles = querySnapshot.docs
          .map((doc) => Vehicle.fromFirestore(doc))
          .toList();
      
      _error = null;
    } catch (e) {
      _error = 'Failed to load vehicles: $e';
    } finally {
      _setLoading(false);
    }
  }

  // Add a new vehicle
  Future<bool> addVehicle(Vehicle vehicle) async {
    _setLoading(true);
    try {
      final docRef = DatabaseService.collection('vehicles').doc();
      final newVehicle = vehicle.copyWith(updatedAt: DateTime.now());
      
      await docRef.set(newVehicle.toMap());
      
      // If it's set as default, unset others
      if (newVehicle.isDefault) {
        await _handleDefaultVehicle(newVehicle.userId, docRef.id);
      }
      
      final createdVehicle = Vehicle.fromMap(newVehicle.toMap(), docRef.id);
      _vehicles.insert(0, createdVehicle);
      
      _error = null;
      notifyListeners();
      return true;
    } catch (e) {
      _error = 'Failed to add vehicle: $e';
      return false;
    } finally {
      _setLoading(false);
    }
  }

  // Update a vehicle
  Future<bool> updateVehicle(Vehicle vehicle) async {
    _setLoading(true);
    try {
      await DatabaseService.collection('vehicles').doc(vehicle.id).update(vehicle.toMap());
      
      if (vehicle.isDefault) {
        await _handleDefaultVehicle(vehicle.userId, vehicle.id);
      }
      
      final index = _vehicles.indexWhere((v) => v.id == vehicle.id);
      if (index != -1) {
        _vehicles[index] = vehicle;
      }
      
      _error = null;
      notifyListeners();
      return true;
    } catch (e) {
      _error = 'Failed to update vehicle: $e';
      return false;
    } finally {
      _setLoading(false);
    }
  }

  // Delete a vehicle
  Future<bool> deleteVehicle(String vehicleId) async {
    _setLoading(true);
    try {
      await DatabaseService.collection('vehicles').doc(vehicleId).delete();
      _vehicles.removeWhere((v) => v.id == vehicleId);
      _error = null;
      notifyListeners();
      return true;
    } catch (e) {
      _error = 'Failed to delete vehicle: $e';
      return false;
    } finally {
      _setLoading(false);
    }
  }

  // Set default vehicle
  Future<void> _handleDefaultVehicle(String userId, String defaultVehicleId) async {
    final batch = DatabaseService.batch();
    
    // Find other default vehicles and unset them
    final otherDefaults = _vehicles.where((v) => v.isDefault && v.id != defaultVehicleId).toList();
    
    for (var v in otherDefaults) {
      batch.update(DatabaseService.collection('vehicles').doc(v.id), {'isDefault': false});
      final index = _vehicles.indexWhere((veh) => veh.id == v.id);
      if (index != -1) {
        _vehicles[index] = _vehicles[index].copyWith(isDefault: false);
      }
    }
    
    await batch.commit();
  }

  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }
}
