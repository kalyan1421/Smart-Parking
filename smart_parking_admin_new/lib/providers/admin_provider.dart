// lib/providers/admin_provider.dart
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user.dart';
import '../models/parking_spot.dart';
import '../models/booking.dart';
import '../models/admin_stats.dart';
import '../models/revenue_data.dart';
import '../services/admin_service.dart';

class AdminProvider with ChangeNotifier {
  final AdminService _adminService = AdminService();

  // Loading state
  bool _isLoading = false;
  
  // Users
  List<User> _users = [];
  bool _usersLoading = false;
  DocumentSnapshot? _lastUserDoc;
  bool _hasMoreUsers = true;

  // Parking Spots
  List<ParkingSpot> _parkingSpots = [];
  bool _parkingSpotsLoading = false;
  DocumentSnapshot? _lastParkingSpotDoc;
  bool _hasMoreParkingSpots = true;

  // Bookings
  List<Booking> _bookings = [];
  bool _bookingsLoading = false;
  DocumentSnapshot? _lastBookingDoc;
  bool _hasMoreBookings = true;

  // Statistics
  AdminStats? _adminStats;
  bool _statsLoading = false;

  // Revenue Data
  AggregatedRevenueData? _revenueData;
  bool _revenueLoading = false;

  // Error handling
  String? _error;

  // Getters
  bool get isLoading => _isLoading;
  
  List<User> get users => _users;
  bool get usersLoading => _usersLoading;
  bool get hasMoreUsers => _hasMoreUsers;

  List<ParkingSpot> get parkingSpots => _parkingSpots;
  bool get parkingSpotsLoading => _parkingSpotsLoading;
  bool get hasMoreParkingSpots => _hasMoreParkingSpots;

  List<Booking> get bookings => _bookings;
  bool get bookingsLoading => _bookingsLoading;
  bool get hasMoreBookings => _hasMoreBookings;

  AdminStats? get adminStats => _adminStats;
  bool get statsLoading => _statsLoading;

  AggregatedRevenueData? get revenueData => _revenueData;
  bool get revenueLoading => _revenueLoading;

  String? get error => _error;

  // Load users with pagination
  Future<void> loadUsers({bool refresh = false, UserRole? roleFilter}) async {
    if (refresh) {
      _users.clear();
      _lastUserDoc = null;
      _hasMoreUsers = true;
    }

    if (!_hasMoreUsers || _usersLoading) return;

    _usersLoading = true;
    _clearError();
    notifyListeners();

    try {
      final newUsers = await _adminService.getAllUsers(
        startAfter: _lastUserDoc,
        roleFilter: roleFilter,
      );

      if (newUsers.isNotEmpty) {
        _users.addAll(newUsers);
        _lastUserDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(newUsers.last.id)
            .get();
        _hasMoreUsers = newUsers.length == 50; // Check if we got a full page
      } else {
        _hasMoreUsers = false;
      }
    } catch (e) {
      _setError(e.toString());
    } finally {
      _usersLoading = false;
      notifyListeners();
    }
  }

  // Load parking spots with pagination
  Future<void> loadParkingSpots({
    bool refresh = false,
    ParkingSpotStatus? statusFilter,
  }) async {
    if (refresh) {
      _parkingSpots.clear();
      _lastParkingSpotDoc = null;
      _hasMoreParkingSpots = true;
    }

    if (!_hasMoreParkingSpots || _parkingSpotsLoading) return;

    _parkingSpotsLoading = true;
    _clearError();
    notifyListeners();

    try {
      final newSpots = await _adminService.getAllParkingSpots(
        startAfter: _lastParkingSpotDoc,
        statusFilter: statusFilter,
      );

      if (newSpots.isNotEmpty) {
        _parkingSpots.addAll(newSpots);
        _lastParkingSpotDoc = await FirebaseFirestore.instance
            .collection('parkingSpots')
            .doc(newSpots.last.id)
            .get();
        _hasMoreParkingSpots = newSpots.length == 50;
      } else {
        _hasMoreParkingSpots = false;
      }
    } catch (e) {
      _setError(e.toString());
    } finally {
      _parkingSpotsLoading = false;
      notifyListeners();
    }
  }

  // Add parking spot
  Future<void> addParkingSpot(ParkingSpot parkingSpot) async {
    _clearError();
    try {
      await _adminService.addParkingSpot(parkingSpot);
      final newSpot = parkingSpot.copyWith();
      _parkingSpots.insert(0, newSpot);
      notifyListeners();
    } catch (e) {
      _setError(e.toString());
    }
  }

  // Update parking spot
  Future<void> updateParkingSpot(String id, Map<String, dynamic> updates) async {
    _clearError();
    try {
      await _adminService.updateParkingSpot(id, updates);
      
      // Update local list
      final index = _parkingSpots.indexWhere((spot) => spot.id == id);
      if (index != -1) {
        final updatedSpot = _parkingSpots[index];
        // Create updated spot with new values
        _parkingSpots[index] = updatedSpot.copyWith(
          name: updates['name'] ?? updatedSpot.name,
          description: updates['description'] ?? updatedSpot.description,
          pricePerHour: updates['pricePerHour']?.toDouble() ?? updatedSpot.pricePerHour,
          totalSpots: updates['totalSpots'] ?? updatedSpot.totalSpots,
          availableSpots: updates['availableSpots'] ?? updatedSpot.availableSpots,
          status: updates['status'] != null 
              ? ParkingSpotStatus.values.firstWhere((s) => s.name == updates['status'])
              : updatedSpot.status,
          isVerified: updates['isVerified'] ?? updatedSpot.isVerified,
          updatedAt: DateTime.now(),
        );
        notifyListeners();
      }
    } catch (e) {
      _setError(e.toString());
    }
  }

  // Delete parking spot
  Future<void> deleteParkingSpot(String id) async {
    _clearError();
    try {
      await _adminService.deleteParkingSpot(id);
      _parkingSpots.removeWhere((spot) => spot.id == id);
      notifyListeners();
    } catch (e) {
      _setError(e.toString());
    }
  }

  // Verify parking spot
  Future<void> verifyParkingSpot(String id, bool isVerified) async {
    _clearError();
    try {
      await _adminService.verifyParkingSpot(id, isVerified);
      
      final index = _parkingSpots.indexWhere((spot) => spot.id == id);
      if (index != -1) {
        _parkingSpots[index] = _parkingSpots[index].copyWith(isVerified: isVerified);
        notifyListeners();
      }
    } catch (e) {
      _setError(e.toString());
    }
  }

  // Load bookings with filters
  Future<void> loadBookings({
    bool refresh = false,
    BookingStatus? statusFilter,
    DateTime? startDate,
    DateTime? endDate,
    String? parkingSpotId,
    String? userId,
  }) async {
    if (refresh) {
      _bookings.clear();
      _lastBookingDoc = null;
      _hasMoreBookings = true;
    }

    if (!_hasMoreBookings || _bookingsLoading) return;

    _bookingsLoading = true;
    _clearError();
    notifyListeners();

    try {
      final newBookings = await _adminService.getAllBookings(
        startAfter: _lastBookingDoc,
        statusFilter: statusFilter,
        startDate: startDate,
        endDate: endDate,
        parkingSpotId: parkingSpotId,
        userId: userId,
      );

      if (newBookings.isNotEmpty) {
        _bookings.addAll(newBookings);
        _lastBookingDoc = await FirebaseFirestore.instance
            .collection('bookings')
            .doc(newBookings.last.id)
            .get();
        _hasMoreBookings = newBookings.length == 50;
      } else {
        _hasMoreBookings = false;
      }
    } catch (e) {
      _setError(e.toString());
    } finally {
      _bookingsLoading = false;
      notifyListeners();
    }
  }

  // Load admin statistics
  Future<void> loadAdminStats() async {
    _statsLoading = true;
    _clearError();
    notifyListeners();

    try {
      _adminStats = await _adminService.getAdminStats();
    } catch (e) {
      _setError(e.toString());
    } finally {
      _statsLoading = false;
      notifyListeners();
    }
  }

  // Load revenue data
  Future<void> loadRevenueData({
    DateTime? startDate,
    DateTime? endDate,
    String? parkingSpotId,
  }) async {
    _revenueLoading = true;
    _clearError();
    notifyListeners();

    try {
      _revenueData = await _adminService.getRevenueData(
        startDate: startDate,
        endDate: endDate,
        parkingSpotId: parkingSpotId,
      );
    } catch (e) {
      _setError(e.toString());
    } finally {
      _revenueLoading = false;
      notifyListeners();
    }
  }

  // Update booking status
  Future<void> updateBookingStatus(String bookingId, BookingStatus newStatus) async {
    _clearError();
    try {
      await _adminService.updateBookingStatus(bookingId, newStatus);
      
      final index = _bookings.indexWhere((booking) => booking.id == bookingId);
      if (index != -1) {
        _bookings[index] = _bookings[index].copyWith(
          status: newStatus,
          updatedAt: DateTime.now(),
        );
        notifyListeners();
      }
    } catch (e) {
      _setError(e.toString());
    }
  }

  // Search users
  Future<List<User>> searchUsers(String searchTerm) async {
    try {
      return await _adminService.searchUsers(searchTerm);
    } catch (e) {
      _setError(e.toString());
      return [];
    }
  }

  void _setError(String error) {
    _error = error;
    notifyListeners();
  }

  void _clearError() {
    _error = null;
  }

  void clearError() {
    _clearError();
    notifyListeners();
  }
}
