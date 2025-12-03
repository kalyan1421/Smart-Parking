// lib/providers/location_provider.dart - Location state provider
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:smart_parking_app/config/constants.dart';
import 'package:smart_parking_app/core/location/location_service.dart';

class LocationProvider with ChangeNotifier {
  Position? _currentPosition;
  bool _isLoading = false;
  String? _error;
  
  // Getters
  Position? get currentPosition => _currentPosition;
  // Adding currentLocation getter to match usage in other files
  Position? get currentLocation => _currentPosition;
  double get latitude => _currentPosition?.latitude ?? 37.7749;
  double get longitude => _currentPosition?.longitude ?? -122.4194;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get hasLocation => _currentPosition != null;
  
  // Initialize location
  Future<void> initialize() async {
    print('🧩 Phase1Audit: Location initialize()');
    await getCurrentLocation();
  }
  
  // Get current location
  Future<void> getCurrentLocation() async {
    _setLoading(true);
    try {
      print('🧩 Phase1Audit: Requesting current location');
      _currentPosition = await LocationService.getCurrentLocation();
      if (_currentPosition != null) {
        print('🧩 Phase1Audit: Current location lat=${_currentPosition!.latitude}, lng=${_currentPosition!.longitude}');
      }
      _error = null;
      notifyListeners();
    } catch (e) {
      print('🧩 Phase1Audit: Error getCurrentLocation -> $e');
      _error = e.toString();
      notifyListeners();
    } finally {
      _setLoading(false);
    }
  }
  
  // Calculate distance to a point
  double calculateDistanceTo(double lat, double lng) {
    if (_currentPosition == null) return 0;
    
    return LocationService.calculateDistance(
      _currentPosition!.latitude,
      _currentPosition!.longitude,
      lat,
      lng
    );
  }
  
  // Helper to set loading state
  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }
  
  // Clear error
  void clearError() {
    _error = null;
    notifyListeners();
  }
}