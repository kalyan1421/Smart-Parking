// lib/providers/admin_provider.dart
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user.dart';
import '../models/parking_spot.dart';
import '../models/booking.dart';
import '../models/admin_stats.dart';
import '../models/revenue_data.dart';
import '../services/admin_service.dart';

/// Debouncer utility for search/filter operations
class _Debouncer {
  final Duration delay;
  Timer? _timer;

  _Debouncer({required this.delay});

  void run(VoidCallback action) {
    _timer?.cancel();
    _timer = Timer(delay, action);
  }

  void dispose() {
    _timer?.cancel();
  }
}

class AdminProvider with ChangeNotifier {
  final AdminService _adminService = AdminService();
  final _debouncer = _Debouncer(delay: const Duration(milliseconds: 300));

  // Stream subscriptions
  StreamSubscription<List<ParkingSpot>>? _parkingSpotsSubscription;
  StreamSubscription<List<Booking>>? _bookingsSubscription;
  StreamSubscription<List<User>>? _usersSubscription;
  StreamSubscription<AdminStats>? _statsSubscription;

  // Loading states
  bool _isLoading = false;
  bool _usersLoading = false;
  bool _parkingSpotsLoading = false;
  bool _bookingsLoading = false;
  bool _statsLoading = false;
  bool _revenueLoading = false;

  // Users
  List<User> _users = [];
  List<User> _filteredUsers = [];
  DocumentSnapshot? _lastUserDoc;
  bool _hasMoreUsers = true;
  UserRole? _userRoleFilter;
  String _userSearchQuery = '';

  // Parking Spots
  List<ParkingSpot> _parkingSpots = [];
  List<ParkingSpot> _filteredParkingSpots = [];
  DocumentSnapshot? _lastParkingSpotDoc;
  bool _hasMoreParkingSpots = true;
  ParkingSpotStatus? _parkingSpotStatusFilter;
  String _parkingSpotSearchQuery = '';

  // Bookings
  List<Booking> _bookings = [];
  List<Booking> _filteredBookings = [];
  DocumentSnapshot? _lastBookingDoc;
  bool _hasMoreBookings = true;
  BookingStatus? _bookingStatusFilter;
  String _bookingSearchQuery = '';

  // Statistics
  AdminStats? _adminStats;

  // Revenue Data
  AggregatedRevenueData? _revenueData;

  // Error handling
  String? _error;

  // Real-time mode
  bool _isRealTimeEnabled = true;

  // ============ GETTERS ============
  
  bool get isLoading => _isLoading;
  
  List<User> get users => _filteredUsers.isNotEmpty || _userSearchQuery.isNotEmpty 
      ? _filteredUsers 
      : _users;
  bool get usersLoading => _usersLoading;
  bool get hasMoreUsers => _hasMoreUsers;
  UserRole? get userRoleFilter => _userRoleFilter;

  List<ParkingSpot> get parkingSpots => _filteredParkingSpots.isNotEmpty || _parkingSpotSearchQuery.isNotEmpty
      ? _filteredParkingSpots
      : _parkingSpots;
  bool get parkingSpotsLoading => _parkingSpotsLoading;
  bool get hasMoreParkingSpots => _hasMoreParkingSpots;
  ParkingSpotStatus? get parkingSpotStatusFilter => _parkingSpotStatusFilter;

  List<Booking> get bookings => _filteredBookings.isNotEmpty || _bookingSearchQuery.isNotEmpty
      ? _filteredBookings
      : _bookings;
  bool get bookingsLoading => _bookingsLoading;
  bool get hasMoreBookings => _hasMoreBookings;
  BookingStatus? get bookingStatusFilter => _bookingStatusFilter;

  AdminStats? get adminStats => _adminStats;
  bool get statsLoading => _statsLoading;

  AggregatedRevenueData? get revenueData => _revenueData;
  bool get revenueLoading => _revenueLoading;

  String? get error => _error;
  bool get isRealTimeEnabled => _isRealTimeEnabled;

  // ============ INITIALIZATION ============

  AdminProvider() {
    // Start real-time listeners by default
    _initRealTimeListeners();
  }

  void _initRealTimeListeners() {
    if (!_isRealTimeEnabled) return;
    
    // Listen to admin stats in real-time
    _statsSubscription?.cancel();
    _statsSubscription = _adminService.adminStatsStream.listen(
      (stats) {
        _adminStats = stats;
        _statsLoading = false;
        notifyListeners();
      },
      onError: (e) {
        print('📊 AdminStats stream error: $e');
        _setError('Failed to load stats: $e');
      },
    );
  }

  /// Toggle real-time mode
  void toggleRealTimeMode(bool enabled) {
    _isRealTimeEnabled = enabled;
    if (enabled) {
      _initRealTimeListeners();
      startParkingSpotsRealTime();
      startBookingsRealTime();
      startUsersRealTime();
    } else {
      _cancelAllSubscriptions();
    }
    notifyListeners();
  }

  void _cancelAllSubscriptions() {
    _parkingSpotsSubscription?.cancel();
    _bookingsSubscription?.cancel();
    _usersSubscription?.cancel();
    _statsSubscription?.cancel();
  }

  @override
  void dispose() {
    _debouncer.dispose();
    _cancelAllSubscriptions();
    super.dispose();
  }

  // ============ PARKING SPOTS ============

  /// Start real-time parking spots stream
  void startParkingSpotsRealTime({ParkingSpotStatus? statusFilter}) {
    _parkingSpotsLoading = true;
    _parkingSpotStatusFilter = statusFilter;
    notifyListeners();

    _parkingSpotsSubscription?.cancel();
    _parkingSpotsSubscription = _adminService
        .parkingSpotsStreamWithFilter(statusFilter)
        .listen(
      (spots) {
        _parkingSpots = spots;
        _applyParkingSpotFilters();
        _parkingSpotsLoading = false;
        _hasMoreParkingSpots = false; // Real-time has all data
        notifyListeners();
      },
      onError: (e) {
        print('🅿️ ParkingSpots stream error: $e');
        _setError('Failed to load parking spots: $e');
        _parkingSpotsLoading = false;
        notifyListeners();
      },
    );
  }

  /// Load parking spots with pagination (non-real-time)
  Future<void> loadParkingSpots({
    bool refresh = false,
    ParkingSpotStatus? statusFilter,
  }) async {
    if (refresh) {
      _parkingSpots.clear();
      _filteredParkingSpots.clear();
      _lastParkingSpotDoc = null;
      _hasMoreParkingSpots = true;
    }

    if (!_hasMoreParkingSpots || _parkingSpotsLoading) return;

    _parkingSpotsLoading = true;
    _parkingSpotStatusFilter = statusFilter;
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
        _applyParkingSpotFilters();
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

  /// Search parking spots with debounce
  void searchParkingSpots(String query) {
    _parkingSpotSearchQuery = query;
    _debouncer.run(() {
      _applyParkingSpotFilters();
      notifyListeners();
    });
  }

  void _applyParkingSpotFilters() {
    if (_parkingSpotSearchQuery.isEmpty) {
      _filteredParkingSpots = [];
      return;
    }

    final searchLower = _parkingSpotSearchQuery.toLowerCase();
    _filteredParkingSpots = _parkingSpots.where((spot) {
      return spot.name.toLowerCase().contains(searchLower) ||
             spot.address.toLowerCase().contains(searchLower) ||
             spot.id.toLowerCase().contains(searchLower);
    }).toList();
  }

  /// Set parking spot status filter
  void setParkingSpotStatusFilter(ParkingSpotStatus? status) {
    _parkingSpotStatusFilter = status;
    if (_isRealTimeEnabled) {
      startParkingSpotsRealTime(statusFilter: status);
    } else {
      loadParkingSpots(refresh: true, statusFilter: status);
    }
  }

  /// Add parking spot
  Future<bool> addParkingSpot(ParkingSpot parkingSpot) async {
    _clearError();
    try {
      await _adminService.addParkingSpot(parkingSpot);
      // Real-time stream will update the list automatically
      return true;
    } catch (e) {
      _setError(e.toString());
      return false;
    }
  }

  /// Update parking spot
  Future<bool> updateParkingSpot(String id, Map<String, dynamic> updates) async {
    _clearError();
    try {
      await _adminService.updateParkingSpot(id, updates);
      
      // Optimistically update local list
      final index = _parkingSpots.indexWhere((spot) => spot.id == id);
      if (index != -1) {
        final updatedSpot = _parkingSpots[index];
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
      return true;
    } catch (e) {
      _setError(e.toString());
      return false;
    }
  }

  /// Delete parking spot
  Future<bool> deleteParkingSpot(String id) async {
    _clearError();
    try {
      await _adminService.deleteParkingSpot(id);
      // Real-time stream will update the list automatically
      // Optimistic removal
      _parkingSpots.removeWhere((spot) => spot.id == id);
      _filteredParkingSpots.removeWhere((spot) => spot.id == id);
      notifyListeners();
      return true;
    } catch (e) {
      _setError(e.toString());
      return false;
    }
  }

  /// Verify parking spot
  Future<bool> verifyParkingSpot(String id, bool isVerified) async {
    _clearError();
    try {
      await _adminService.verifyParkingSpot(id, isVerified);
      
      final index = _parkingSpots.indexWhere((spot) => spot.id == id);
      if (index != -1) {
        _parkingSpots[index] = _parkingSpots[index].copyWith(isVerified: isVerified);
        notifyListeners();
      }
      return true;
    } catch (e) {
      _setError(e.toString());
      return false;
    }
  }

  // ============ BOOKINGS ============

  /// Start real-time bookings stream
  void startBookingsRealTime({
    BookingStatus? statusFilter,
    String? parkingSpotId,
    String? userId,
  }) {
    _bookingsLoading = true;
    _bookingStatusFilter = statusFilter;
    notifyListeners();

    _bookingsSubscription?.cancel();
    _bookingsSubscription = _adminService
        .bookingsStreamWithFilter(
          status: statusFilter,
          parkingSpotId: parkingSpotId,
          userId: userId,
        )
        .listen(
      (bookingsList) {
        _bookings = bookingsList;
        _applyBookingFilters();
        _bookingsLoading = false;
        _hasMoreBookings = false;
        notifyListeners();
      },
      onError: (e) {
        print('📅 Bookings stream error: $e');
        _setError('Failed to load bookings: $e');
        _bookingsLoading = false;
        notifyListeners();
      },
    );
  }

  /// Load bookings with filters (non-real-time)
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
      _filteredBookings.clear();
      _lastBookingDoc = null;
      _hasMoreBookings = true;
    }

    if (!_hasMoreBookings || _bookingsLoading) return;

    _bookingsLoading = true;
    _bookingStatusFilter = statusFilter;
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
        _applyBookingFilters();
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

  /// Search bookings with debounce
  void searchBookings(String query) {
    _bookingSearchQuery = query;
    _debouncer.run(() {
      _applyBookingFilters();
      notifyListeners();
    });
  }

  void _applyBookingFilters() {
    if (_bookingSearchQuery.isEmpty) {
      _filteredBookings = [];
      return;
    }

    final searchLower = _bookingSearchQuery.toLowerCase();
    _filteredBookings = _bookings.where((booking) {
      return booking.id.toLowerCase().contains(searchLower) ||
             booking.parkingSpotName.toLowerCase().contains(searchLower) ||
             booking.userId.toLowerCase().contains(searchLower);
    }).toList();
  }

  /// Set booking status filter
  void setBookingStatusFilter(BookingStatus? status) {
    _bookingStatusFilter = status;
    if (_isRealTimeEnabled) {
      startBookingsRealTime(statusFilter: status);
    } else {
      loadBookings(refresh: true, statusFilter: status);
    }
  }

  /// Update booking status (with atomic transaction)
  Future<bool> updateBookingStatus(String bookingId, BookingStatus newStatus) async {
    _clearError();
    try {
      await _adminService.updateBookingStatusAtomic(bookingId, newStatus);
      
      // Optimistically update local list
      final index = _bookings.indexWhere((booking) => booking.id == bookingId);
      if (index != -1) {
        _bookings[index] = _bookings[index].copyWith(
          status: newStatus,
          updatedAt: DateTime.now(),
        );
        notifyListeners();
      }
      return true;
    } catch (e) {
      _setError(e.toString());
      return false;
    }
  }

  /// Process booking (check-in/check-out)
  Future<String> processBooking(String bookingId) async {
    _clearError();
    try {
      return await _adminService.processBookingAtomic(bookingId);
    } catch (e) {
      _setError(e.toString());
      return 'Error: $e';
    }
  }

  // ============ USERS ============

  /// Start real-time users stream
  void startUsersRealTime({UserRole? roleFilter}) {
    _usersLoading = true;
    _userRoleFilter = roleFilter;
    notifyListeners();

    _usersSubscription?.cancel();
    _usersSubscription = _adminService
        .usersStreamWithFilter(roleFilter)
        .listen(
      (usersList) {
        _users = usersList;
        _applyUserFilters();
        _usersLoading = false;
        _hasMoreUsers = false;
        notifyListeners();
      },
      onError: (e) {
        print('👥 Users stream error: $e');
        _setError('Failed to load users: $e');
        _usersLoading = false;
        notifyListeners();
      },
    );
  }

  /// Load users with pagination
  Future<void> loadUsers({bool refresh = false, UserRole? roleFilter}) async {
    if (refresh) {
      _users.clear();
      _filteredUsers.clear();
      _lastUserDoc = null;
      _hasMoreUsers = true;
    }

    if (!_hasMoreUsers || _usersLoading) return;

    _usersLoading = true;
    _userRoleFilter = roleFilter;
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
        _hasMoreUsers = newUsers.length == 50;
        _applyUserFilters();
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

  /// Search users with debounce (updates filtered list)
  void searchUsers(String query) {
    _userSearchQuery = query;
    _debouncer.run(() {
      _applyUserFilters();
      notifyListeners();
    });
  }

  /// Search users async - returns list of matching users
  Future<List<User>> searchUsersAsync(String query) async {
    try {
      return await _adminService.searchUsers(query);
    } catch (e) {
      _setError(e.toString());
      return [];
    }
  }

  void _applyUserFilters() {
    if (_userSearchQuery.isEmpty) {
      _filteredUsers = [];
      return;
    }

    final searchLower = _userSearchQuery.toLowerCase();
    _filteredUsers = _users.where((user) {
      return user.email.toLowerCase().contains(searchLower) ||
             user.displayName.toLowerCase().contains(searchLower) ||
             (user.phoneNumber?.contains(_userSearchQuery) ?? false);
    }).toList();
  }

  /// Set user role filter
  void setUserRoleFilter(UserRole? role) {
    _userRoleFilter = role;
    if (_isRealTimeEnabled) {
      startUsersRealTime(roleFilter: role);
    } else {
      loadUsers(refresh: true, roleFilter: role);
    }
  }

  /// Update user role
  Future<bool> updateUserRole(String userId, UserRole newRole) async {
    _clearError();
    try {
      await _adminService.updateUserRole(userId, newRole);
      
      final index = _users.indexWhere((user) => user.id == userId);
      if (index != -1) {
        _users[index] = _users[index].copyWith(role: newRole);
        notifyListeners();
      }
      return true;
    } catch (e) {
      _setError(e.toString());
      return false;
    }
  }

  // ============ STATS & REVENUE ============

  /// Load admin statistics
  Future<void> loadAdminStats() async {
    if (_isRealTimeEnabled) {
      // Stats already loaded via stream
      return;
    }

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

  /// Load revenue data
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

  // ============ ERROR HANDLING ============

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

  // ============ REFRESH ALL ============

  Future<void> refreshAll() async {
    if (_isRealTimeEnabled) {
      _initRealTimeListeners();
      startParkingSpotsRealTime(statusFilter: _parkingSpotStatusFilter);
      startBookingsRealTime(statusFilter: _bookingStatusFilter);
      startUsersRealTime(roleFilter: _userRoleFilter);
    } else {
      await Future.wait([
        loadAdminStats(),
        loadParkingSpots(refresh: true, statusFilter: _parkingSpotStatusFilter),
        loadBookings(refresh: true, statusFilter: _bookingStatusFilter),
        loadUsers(refresh: true, roleFilter: _userRoleFilter),
        loadRevenueData(),
      ]);
    }
  }
}
