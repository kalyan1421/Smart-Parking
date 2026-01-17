// lib/providers/parking_provider.dart - Production-grade real-time parking management
// Optimized for 10K+ users with stream-based updates and efficient state management

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geoflutterfire_plus/geoflutterfire_plus.dart';
import 'package:geolocator/geolocator.dart';
import '../core/database/database_service.dart';
import '../models/parking_spot.dart';

/// Production-grade ParkingProvider with:
/// - Real-time streaming from Firestore (instant Admin ↔ Customer sync)
/// - Efficient state management (no rebuild storms)
/// - Smart caching and debouncing
/// - Optimized filtering (server-side when possible)
class ParkingProvider extends ChangeNotifier {
  // ═══════════════════════════════════════════════════════════════════════════
  // STATE
  // ═══════════════════════════════════════════════════════════════════════════
  
  List<ParkingSpot> _allParkingSpots = [];
  List<ParkingSpot> _filteredSpots = [];
  ParkingSpot? _selectedParkingSpot;
  bool _isLoading = false;
  String? _error;
  Position? _currentLocation;
  
  // Stream subscriptions
  StreamSubscription<QuerySnapshot>? _spotsSubscription;
  StreamSubscription<List<DocumentSnapshot>>? _geoSubscription;
  
  // Debouncing
  Timer? _filterDebounce;
  Timer? _notifyDebounce;
  
  // Filter state
  double _maxPrice = 500.0;
  double _minPrice = 0.0;
  List<String> _selectedAmenities = [];
  List<String> _selectedVehicleTypes = [];
  double _searchRadius = 10000; // meters (10km default)
  String _sortBy = 'distance';
  bool _showAvailableOnly = true;
  String _searchQuery = '';
  
  // Last update tracking (for efficient diffing)
  Map<String, ParkingSpot> _spotCache = {};
  DateTime? _lastUpdate;
  
  // ═══════════════════════════════════════════════════════════════════════════
  // GETTERS
  // ═══════════════════════════════════════════════════════════════════════════
  
  List<ParkingSpot> get parkingSpots => _filteredSpots;
  List<ParkingSpot> get nearbyParkingSpots => _filteredSpots;
  List<ParkingSpot> get allParkingSpots => _allParkingSpots;
  ParkingSpot? get selectedParkingSpot => _selectedParkingSpot;
  bool get isLoading => _isLoading;
  String? get error => _error;
  Position? get currentLocation => _currentLocation;
  double get maxPrice => _maxPrice;
  double get minPrice => _minPrice;
  List<String> get selectedAmenities => _selectedAmenities;
  List<String> get selectedVehicleTypes => _selectedVehicleTypes;
  double get searchRadius => _searchRadius;
  String get sortBy => _sortBy;
  bool get showAvailableOnly => _showAvailableOnly;
  int get availableSpotsCount => _filteredSpots.where((s) => s.availableSpots > 0).length;
  
  // ═══════════════════════════════════════════════════════════════════════════
  // LIFECYCLE
  // ═══════════════════════════════════════════════════════════════════════════
  
  @override
  void dispose() {
    _spotsSubscription?.cancel();
    _geoSubscription?.cancel();
    _filterDebounce?.cancel();
    _notifyDebounce?.cancel();
    super.dispose();
  }
  
  // ═══════════════════════════════════════════════════════════════════════════
  // LOCATION
  // ═══════════════════════════════════════════════════════════════════════════
  
  Future<void> initializeLocation() async {
    try {
      final permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        final requestPermission = await Geolocator.requestPermission();
        if (requestPermission == LocationPermission.denied) {
          throw Exception('Location permission denied');
        }
      }
      
      _currentLocation = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 10),
        ),
      );
      _notifyListenersDebounced();
    } catch (e) {
      _error = 'Failed to get location: $e';
      _notifyListenersDebounced();
    }
  }
  
  // ═══════════════════════════════════════════════════════════════════════════
  // REAL-TIME STREAMING (Critical for Admin ↔ Customer sync)
  // ═══════════════════════════════════════════════════════════════════════════
  
  /// Start streaming nearby parking spots with real-time updates
  /// This ensures instant sync between Admin and Customer apps
  void startStreamingNearby(double latitude, double longitude, {double? radius}) {
    final searchRadius = radius ?? _searchRadius;
    
    // Cancel existing subscription
    _geoSubscription?.cancel();
    
    _setLoading(true);
    
    try {
      final center = GeoFirePoint(GeoPoint(latitude, longitude));
      final collectionRef = DatabaseService.collection('parkingSpots');
      final geoCollectionReference = GeoCollectionReference(collectionRef);
      
      // Subscribe to geo-query with real-time updates
      _geoSubscription = geoCollectionReference.subscribeWithin(
        center: center,
        radiusInKm: searchRadius / 1000,
        field: 'position',
        geopointFrom: (data) {
          final dataMap = data as Map<String, dynamic>?;
          final position = dataMap?['position'] as Map<String, dynamic>?;
          return position?['geopoint'] as GeoPoint? ?? const GeoPoint(0, 0);
        },
        strictMode: true,
      ).listen(
        (docs) => _handleSpotsUpdate(docs),
        onError: (error) {
          print('⚠️ Geo stream error, falling back: $error');
          _startFallbackStream();
        },
      );
    } catch (e) {
      print('⚠️ Failed to start geo stream: $e');
      _startFallbackStream();
    }
  }
  
  /// Fallback: Stream all parking spots without geo-filtering
  void _startFallbackStream() {
    _spotsSubscription?.cancel();
    
    _spotsSubscription = DatabaseService.collection('parkingSpots')
        .orderBy('createdAt', descending: true)
        .limit(200)
        .snapshots()
        .listen(
          (snapshot) {
            final spots = snapshot.docs
                .map((doc) => ParkingSpot.fromFirestore(doc))
                .toList();
            _processSpotUpdates(spots);
          },
          onError: (error) {
            _error = 'Failed to load parking spots: $error';
            _setLoading(false);
          },
        );
  }
  
  /// Handle updates from geo-query stream
  void _handleSpotsUpdate(List<DocumentSnapshot<Object?>> docs) {
    final spots = docs
        .map((doc) => ParkingSpot.fromFirestore(doc))
        .toList();
    _processSpotUpdates(spots);
  }
  
  /// Process and diff spot updates efficiently
  void _processSpotUpdates(List<ParkingSpot> newSpots) {
    // Build new cache
    final newCache = <String, ParkingSpot>{};
    for (final spot in newSpots) {
      newCache[spot.id] = spot;
    }
    
    // Check for actual changes (avoid unnecessary rebuilds)
    bool hasChanges = newCache.length != _spotCache.length;
    
    if (!hasChanges) {
      for (final spot in newSpots) {
        final cached = _spotCache[spot.id];
        if (cached == null || 
            cached.availableSpots != spot.availableSpots ||
            cached.status != spot.status ||
            cached.pricePerHour != spot.pricePerHour) {
          hasChanges = true;
          break;
        }
      }
    }
    
    if (hasChanges) {
      _spotCache = newCache;
      _allParkingSpots = newSpots;
      _applyFilters();
      _lastUpdate = DateTime.now();
    }
    
    _setLoading(false);
  }
  
  /// Stream a single parking spot for detail view with real-time updates
  Stream<ParkingSpot?> streamParkingSpot(String spotId) {
    return DatabaseService.collection('parkingSpots')
        .doc(spotId)
        .snapshots()
        .map((doc) {
          if (!doc.exists) return null;
          return ParkingSpot.fromFirestore(doc);
        });
  }
  
  // ═══════════════════════════════════════════════════════════════════════════
  // ONE-TIME FETCH (For backward compatibility)
  // ═══════════════════════════════════════════════════════════════════════════
  
  Future<void> findNearbyParkingSpots(
    double latitude, 
    double longitude, 
    {double radius = 1.0}
  ) async {
    await loadParkingSpotsNear(latitude, longitude, radius: radius * 1000);
  }
  
  Future<void> loadParkingSpotsNear(
    double latitude, 
    double longitude, 
    {double? radius}
  ) async {
    // Start streaming instead of one-time fetch for real-time updates
    startStreamingNearby(latitude, longitude, radius: radius);
  }
  
  Future<void> loadAllParkingSpots() async {
    _setLoading(true);
    try {
      final querySnapshot = await DatabaseService.collection('parkingSpots')
          .orderBy('createdAt', descending: true)
          .limit(500)
          .get();
      
      final spots = querySnapshot.docs
          .map((doc) => ParkingSpot.fromFirestore(doc))
          .toList();
      
      _processSpotUpdates(spots);
    } catch (e) {
      _error = 'Failed to load parking spots: $e';
      _allParkingSpots = [];
      _filteredSpots = [];
    } finally {
      _setLoading(false);
    }
  }
  
  // ═══════════════════════════════════════════════════════════════════════════
  // SEARCH
  // ═══════════════════════════════════════════════════════════════════════════
  
  Future<void> searchParkingSpots(String query) async {
    _searchQuery = query.trim().toLowerCase();
    
    if (_searchQuery.isEmpty) {
      _applyFilters();
      return;
    }
    
    _setLoading(true);
    
    try {
      // Server-side prefix search
      final querySnapshot = await DatabaseService.collection('parkingSpots')
          .where('name', isGreaterThanOrEqualTo: query)
          .where('name', isLessThanOrEqualTo: '$query\uf8ff')
          .limit(50)
          .get();
      
      final spots = querySnapshot.docs
          .map((doc) => ParkingSpot.fromFirestore(doc))
          .toList();
      
      _allParkingSpots = spots;
      _applyFilters();
      _error = null;
    } catch (e) {
      _error = 'Search failed: $e';
      // Fall back to client-side search
      _applyFilters();
    } finally {
      _setLoading(false);
    }
  }
  
  // ═══════════════════════════════════════════════════════════════════════════
  // FILTERING (Client-side with debouncing)
  // ═══════════════════════════════════════════════════════════════════════════
  
  void _applyFilters() {
    _filterDebounce?.cancel();
    _filterDebounce = Timer(const Duration(milliseconds: 50), () {
      _doApplyFilters();
    });
  }
  
  void _doApplyFilters() {
    var filtered = _allParkingSpots.where((spot) {
      // Text search
      if (_searchQuery.isNotEmpty) {
        final nameMatch = spot.name.toLowerCase().contains(_searchQuery);
        final addressMatch = spot.address.toLowerCase().contains(_searchQuery);
        if (!nameMatch && !addressMatch) return false;
      }
      
      // Availability filter
      if (_showAvailableOnly && !spot.isAvailableForBooking()) return false;
      
      // Price filter
      if (spot.pricePerHour < _minPrice || spot.pricePerHour > _maxPrice) {
        return false;
      }
      
      // Amenities filter
      if (_selectedAmenities.isNotEmpty) {
        final hasAllAmenities = _selectedAmenities.every(
          (amenity) => spot.amenities.contains(amenity)
        );
        if (!hasAllAmenities) return false;
      }
      
      // Vehicle type filter
      if (_selectedVehicleTypes.isNotEmpty) {
        final supportsVehicle = _selectedVehicleTypes.any(
          (vehicleType) => spot.vehicleTypes.contains(vehicleType)
        );
        if (!supportsVehicle) return false;
      }
      
      return true;
    }).toList();
    
    // Sort
    _sortSpots(filtered);
    
    _filteredSpots = filtered;
    _notifyListenersDebounced();
  }
  
  void _sortSpots(List<ParkingSpot> spots) {
    switch (_sortBy) {
      case 'price':
        spots.sort((a, b) => a.pricePerHour.compareTo(b.pricePerHour));
        break;
      case 'rating':
        spots.sort((a, b) => b.rating.compareTo(a.rating));
        break;
      case 'availability':
        spots.sort((a, b) => b.availableSpots.compareTo(a.availableSpots));
        break;
      case 'distance':
      default:
        if (_currentLocation != null) {
          spots.sort((a, b) {
            final distanceA = Geolocator.distanceBetween(
              _currentLocation!.latitude, _currentLocation!.longitude,
              a.latitude, a.longitude
            );
            final distanceB = Geolocator.distanceBetween(
              _currentLocation!.latitude, _currentLocation!.longitude,
              b.latitude, b.longitude
            );
            return distanceA.compareTo(distanceB);
          });
        }
    }
  }
  
  // ═══════════════════════════════════════════════════════════════════════════
  // FILTER SETTERS
  // ═══════════════════════════════════════════════════════════════════════════
  
  void updatePriceRange(double minPrice, double maxPrice) {
    _minPrice = minPrice;
    _maxPrice = maxPrice;
    _applyFilters();
  }
  
  void updateSelectedAmenities(List<String> amenities) {
    _selectedAmenities = amenities;
    _applyFilters();
  }
  
  void updateSelectedVehicleTypes(List<String> vehicleTypes) {
    _selectedVehicleTypes = vehicleTypes;
    _applyFilters();
  }
  
  void updateSearchRadius(double radius) {
    _searchRadius = radius;
    // Re-stream with new radius if we have location
    if (_currentLocation != null) {
      startStreamingNearby(
        _currentLocation!.latitude, 
        _currentLocation!.longitude,
        radius: radius,
      );
    }
  }
  
  void updateSortBy(String sortBy) {
    _sortBy = sortBy;
    _applyFilters();
  }
  
  void toggleAvailabilityFilter() {
    _showAvailableOnly = !_showAvailableOnly;
    _applyFilters();
  }
  
  void setShowAvailableOnly(bool value) {
    _showAvailableOnly = value;
    _applyFilters();
  }
  
  void clearFilters() {
    _maxPrice = 500.0;
    _minPrice = 0.0;
    _selectedAmenities = [];
    _selectedVehicleTypes = [];
    _showAvailableOnly = true;
    _sortBy = 'distance';
    _searchQuery = '';
    _searchRadius = 10000; // Reset to 10km default
    _applyFilters();
    
    // Re-stream with default radius if we have location
    if (_currentLocation != null) {
      startStreamingNearby(
        _currentLocation!.latitude,
        _currentLocation!.longitude,
        radius: _searchRadius,
      );
    }
  }
  
  // ═══════════════════════════════════════════════════════════════════════════
  // SELECTION
  // ═══════════════════════════════════════════════════════════════════════════
  
  void selectParkingSpot(ParkingSpot spot) {
    _selectedParkingSpot = spot;
    notifyListeners();
  }
  
  void clearSelection() {
    _selectedParkingSpot = null;
    notifyListeners();
  }
  
  // ═══════════════════════════════════════════════════════════════════════════
  // CRUD OPERATIONS
  // ═══════════════════════════════════════════════════════════════════════════
  
  Future<ParkingSpot?> getParkingSpotById(String id) async {
    // Check cache first
    if (_spotCache.containsKey(id)) {
      return _spotCache[id];
    }
    
    try {
      final doc = await DatabaseService.collection('parkingSpots').doc(id).get();
      if (doc.exists) {
        final spot = ParkingSpot.fromFirestore(doc);
        _spotCache[id] = spot;
        return spot;
      }
      return null;
    } catch (e) {
      _error = 'Failed to get parking spot: $e';
      return null;
    }
  }
  
  Future<bool> addParkingSpot(ParkingSpot spot) async {
    _setLoading(true);
    try {
      final docRef = DatabaseService.collection('parkingSpots').doc();
      
      // Create new spot with the Firestore document ID
      final newSpot = ParkingSpot(
        id: docRef.id,
        name: spot.name,
        description: spot.description,
        latitude: spot.latitude,
        longitude: spot.longitude,
        geoPoint: spot.geoPoint,
        totalSpots: spot.totalSpots,
        availableSpots: spot.availableSpots,
        pricePerHour: spot.pricePerHour,
        amenities: spot.amenities,
        vehicleTypes: spot.vehicleTypes,
        ownerId: spot.ownerId,
        status: spot.status,
        operatingHours: spot.operatingHours,
        images: spot.images,
        rating: spot.rating,
        reviewCount: spot.reviewCount,
        isVerified: spot.isVerified,
        createdAt: spot.createdAt,
        updatedAt: DateTime.now(),
        weatherData: spot.weatherData,
        address: spot.address,
        contactPhone: spot.contactPhone,
        accessibility: spot.accessibility,
      );
      
      await docRef.set(newSpot.toMap());
      
      _error = null;
      return true;
    } catch (e) {
      _error = 'Failed to add parking spot: $e';
      return false;
    } finally {
      _setLoading(false);
    }
  }
  
  Future<bool> updateParkingSpot(ParkingSpot spot) async {
    _setLoading(true);
    try {
      await DatabaseService.collection('parkingSpots')
          .doc(spot.id)
          .update(spot.toMap());
      
      // Update cache
      _spotCache[spot.id] = spot;
      
      _error = null;
      return true;
    } catch (e) {
      _error = 'Failed to update parking spot: $e';
      return false;
    } finally {
      _setLoading(false);
    }
  }
  
  Future<bool> deleteParkingSpot(String spotId) async {
    _setLoading(true);
    try {
      await DatabaseService.collection('parkingSpots').doc(spotId).delete();
      
      _spotCache.remove(spotId);
      _allParkingSpots.removeWhere((s) => s.id == spotId);
      _applyFilters();
      
      _error = null;
      return true;
    } catch (e) {
      _error = 'Failed to delete parking spot: $e';
      return false;
    } finally {
      _setLoading(false);
    }
  }
  
  Future<bool> updateSpotAvailability(String spotId, int availableSpots) async {
    try {
      await DatabaseService.collection('parkingSpots').doc(spotId).update({
        'availableSpots': availableSpots,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      
      // Update cache
      if (_spotCache.containsKey(spotId)) {
        _spotCache[spotId] = _spotCache[spotId]!.copyWith(
          availableSpots: availableSpots,
          updatedAt: DateTime.now(),
        );
      }
      
      return true;
    } catch (e) {
      _error = 'Failed to update availability: $e';
      return false;
    }
  }
  
  // ═══════════════════════════════════════════════════════════════════════════
  // USER-OWNED SPOTS
  // ═══════════════════════════════════════════════════════════════════════════
  
  Future<void> loadUserOwnedSpots(String userId) async {
    _setLoading(true);
    try {
      final querySnapshot = await DatabaseService.collection('parkingSpots')
          .where('ownerId', isEqualTo: userId)
          .orderBy('createdAt', descending: true)
          .get();
      
      final spots = querySnapshot.docs
          .map((doc) => ParkingSpot.fromFirestore(doc))
          .toList();
      
      _allParkingSpots = spots;
      _applyFilters();
      _error = null;
    } catch (e) {
      _error = 'Failed to load owned spots: $e';
      _allParkingSpots = [];
      _filteredSpots = [];
    } finally {
      _setLoading(false);
    }
  }
  
  // ═══════════════════════════════════════════════════════════════════════════
  // UTILITIES
  // ═══════════════════════════════════════════════════════════════════════════
  
  double? getDistanceToSpot(ParkingSpot spot) {
    if (_currentLocation == null) return null;
    
    return Geolocator.distanceBetween(
      _currentLocation!.latitude,
      _currentLocation!.longitude,
      spot.latitude,
      spot.longitude,
    );
  }
  
  String formatDistance(double meters) {
    if (meters < 1000) {
      return '${meters.round()} m';
    } else {
      return '${(meters / 1000).toStringAsFixed(1)} km';
    }
  }
  
  /// Get real-time stream for map markers
  Stream<List<ParkingSpot>> streamParkingSpotsNear(double latitude, double longitude) {
    final center = GeoFirePoint(GeoPoint(latitude, longitude));
    final collectionRef = DatabaseService.collection('parkingSpots');
    final geoCollectionReference = GeoCollectionReference(collectionRef);
    
    return geoCollectionReference.subscribeWithin(
      center: center,
      radiusInKm: _searchRadius / 1000,
      field: 'position',
      geopointFrom: (data) {
        final dataMap = data as Map<String, dynamic>?;
        final position = dataMap?['position'] as Map<String, dynamic>?;
        return position?['geopoint'] as GeoPoint? ?? const GeoPoint(0, 0);
      },
    ).map((querySnapshot) => querySnapshot
        .map((doc) => ParkingSpot.fromFirestore(doc))
        .toList());
  }
  
  // Backward compatibility
  Future<bool> bookParkingSpot(ParkingSpot spot, DateTime startTime, DateTime endTime) async {
    return true;
  }
  
  Future<bool> cancelBooking(String bookingId) async {
    return true;
  }
  
  // ═══════════════════════════════════════════════════════════════════════════
  // PRIVATE HELPERS
  // ═══════════════════════════════════════════════════════════════════════════
  
  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }
  
  void _notifyListenersDebounced() {
    _notifyDebounce?.cancel();
    _notifyDebounce = Timer(const Duration(milliseconds: 16), () {
      notifyListeners();
    });
  }
  
  void clearError() {
    _error = null;
    notifyListeners();
  }
  
  /// Force refresh from server
  Future<void> refresh() async {
    if (_currentLocation != null) {
      startStreamingNearby(
        _currentLocation!.latitude,
        _currentLocation!.longitude,
      );
    } else {
      await loadAllParkingSpots();
    }
  }
}
