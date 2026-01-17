// lib/services/admin_service.dart
import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user.dart';
import '../models/parking_spot.dart';
import '../models/booking.dart';
import '../models/revenue_data.dart';
import '../models/admin_stats.dart';

class AdminService {
  static final AdminService _instance = AdminService._internal();
  factory AdminService() => _instance;
  AdminService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // ============ REAL-TIME STREAMS ============

  /// Real-time stream of all parking spots
  Stream<List<ParkingSpot>> get parkingSpotsStream {
    return _firestore
        .collection('parkingSpots')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => ParkingSpot.fromFirestore(doc))
            .toList());
  }

  /// Real-time stream of parking spots with status filter
  Stream<List<ParkingSpot>> parkingSpotsStreamWithFilter(ParkingSpotStatus? status) {
    Query query = _firestore.collection('parkingSpots').orderBy('createdAt', descending: true);
    
    if (status != null) {
      query = query.where('status', isEqualTo: status.name);
    }
    
    return query.snapshots().map((snapshot) =>
        snapshot.docs.map((doc) => ParkingSpot.fromFirestore(doc)).toList());
  }

  /// Real-time stream of all bookings
  Stream<List<Booking>> get bookingsStream {
    return _firestore
        .collection('bookings')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => Booking.fromFirestore(doc))
            .toList());
  }

  /// Real-time stream of bookings with filters
  Stream<List<Booking>> bookingsStreamWithFilter({
    BookingStatus? status,
    String? parkingSpotId,
    String? userId,
  }) {
    Query query = _firestore.collection('bookings').orderBy('createdAt', descending: true);
    
    if (status != null) {
      query = query.where('status', isEqualTo: status.name);
    }
    if (parkingSpotId != null) {
      query = query.where('parkingSpotId', isEqualTo: parkingSpotId);
    }
    if (userId != null) {
      query = query.where('userId', isEqualTo: userId);
    }
    
    return query.snapshots().map((snapshot) =>
        snapshot.docs.map((doc) => Booking.fromFirestore(doc)).toList());
  }

  /// Real-time stream of all users
  Stream<List<User>> get usersStream {
    return _firestore
        .collection('users')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => User.fromFirestore(doc))
            .toList());
  }

  /// Real-time stream of users with role filter
  Stream<List<User>> usersStreamWithFilter(UserRole? role) {
    Query query = _firestore.collection('users').orderBy('createdAt', descending: true);
    
    if (role != null) {
      query = query.where('role', isEqualTo: role.name);
    }
    
    return query.snapshots().map((snapshot) =>
        snapshot.docs.map((doc) => User.fromFirestore(doc)).toList());
  }

  /// Real-time stream of admin stats
  Stream<AdminStats> get adminStatsStream {
    // Combine multiple streams for real-time stats
    return Rx.combineLatest3(
      _firestore.collection('users').snapshots(),
      _firestore.collection('parkingSpots').snapshots(),
      _firestore.collection('bookings').snapshots(),
      (QuerySnapshot usersSnapshot, QuerySnapshot parkingSpotsSnapshot, QuerySnapshot bookingsSnapshot) {
        return _calculateStats(usersSnapshot, parkingSpotsSnapshot, bookingsSnapshot);
      },
    );
  }

  AdminStats _calculateStats(
    QuerySnapshot usersSnapshot,
    QuerySnapshot parkingSpotsSnapshot,
    QuerySnapshot bookingsSnapshot,
  ) {
    // Calculate user statistics
    final usersByRole = <String, int>{'user': 0, 'parkingOperator': 0, 'admin': 0};
    for (final doc in usersSnapshot.docs) {
      final user = User.fromFirestore(doc);
      usersByRole[user.role.name] = (usersByRole[user.role.name] ?? 0) + 1;
    }

    // Calculate parking spot statistics
    final parkingSpotsByStatus = <String, int>{};
    int availableParkingSpots = 0;
    double totalRating = 0;
    int ratedSpots = 0;

    for (final doc in parkingSpotsSnapshot.docs) {
      final spot = ParkingSpot.fromFirestore(doc);
      parkingSpotsByStatus[spot.status.name] = (parkingSpotsByStatus[spot.status.name] ?? 0) + 1;
      
      if (spot.status == ParkingSpotStatus.available) {
        availableParkingSpots += spot.availableSpots;
      }
      
      if (spot.rating > 0) {
        totalRating += spot.rating;
        ratedSpots++;
      }
    }

    // Calculate booking statistics
    final bookingsByStatus = <String, int>{};
    double totalRevenue = 0;
    double todayRevenue = 0;
    int activeBookings = 0;
    int todayBookings = 0;
    final today = DateTime.now();

    for (final doc in bookingsSnapshot.docs) {
      final booking = Booking.fromFirestore(doc);
      bookingsByStatus[booking.status.name] = (bookingsByStatus[booking.status.name] ?? 0) + 1;
      
      if (booking.status == BookingStatus.completed) {
        totalRevenue += booking.totalPrice;
        
        // Check if completed today
        if (booking.endTime.year == today.year &&
            booking.endTime.month == today.month &&
            booking.endTime.day == today.day) {
          todayRevenue += booking.totalPrice;
        }
      }
      
      if (booking.status == BookingStatus.active || booking.status == BookingStatus.confirmed) {
        activeBookings++;
      }
      
      // Count today's bookings
      if (booking.createdAt.year == today.year &&
          booking.createdAt.month == today.month &&
          booking.createdAt.day == today.day) {
        todayBookings++;
      }
    }

    final averageRating = ratedSpots > 0 ? totalRating / ratedSpots : 0.0;

    return AdminStats(
      totalUsers: usersSnapshot.docs.length,
      totalParkingSpots: parkingSpotsSnapshot.docs.length,
      totalBookings: bookingsSnapshot.docs.length,
      totalRevenue: totalRevenue,
      todayRevenue: todayRevenue,
      todayBookings: todayBookings,
      activeBookings: activeBookings,
      availableParkingSpots: availableParkingSpots,
      averageRating: averageRating,
      usersByRole: usersByRole,
      bookingsByStatus: bookingsByStatus,
      parkingSpotsByStatus: parkingSpotsByStatus,
      lastUpdated: DateTime.now(),
    );
  }

  // ============ PAGINATION METHODS ============

  /// Get all users with pagination
  Future<List<User>> getAllUsers({
    int limit = 50,
    DocumentSnapshot? startAfter,
    UserRole? roleFilter,
  }) async {
    try {
      Query query = _firestore.collection('users').orderBy('createdAt', descending: true);
      
      if (roleFilter != null) {
        query = query.where('role', isEqualTo: roleFilter.name);
      }
      
      if (startAfter != null) {
        query = query.startAfterDocument(startAfter);
      }
      
      query = query.limit(limit);
      
      final querySnapshot = await query.get();
      return querySnapshot.docs.map((doc) => User.fromFirestore(doc)).toList();
    } catch (e) {
      throw Exception('Failed to fetch users: $e');
    }
  }

  /// Get a single user by ID
  Future<User> getUserById(String userId) async {
    try {
      final doc = await _firestore.collection('users').doc(userId).get();
      if (!doc.exists) {
        throw Exception('User not found');
      }
      return User.fromFirestore(doc);
    } catch (e) {
      throw Exception('Failed to get user: $e');
    }
  }

  /// Get all parking spots with pagination
  Future<List<ParkingSpot>> getAllParkingSpots({
    int limit = 50,
    DocumentSnapshot? startAfter,
    ParkingSpotStatus? statusFilter,
  }) async {
    try {
      Query query = _firestore.collection('parkingSpots').orderBy('createdAt', descending: true);
      
      if (statusFilter != null) {
        query = query.where('status', isEqualTo: statusFilter.name);
      }
      
      if (startAfter != null) {
        query = query.startAfterDocument(startAfter);
      }
      
      query = query.limit(limit);
      
      final querySnapshot = await query.get();
      return querySnapshot.docs.map((doc) => ParkingSpot.fromFirestore(doc)).toList();
    } catch (e) {
      throw Exception('Failed to fetch parking spots: $e');
    }
  }

  /// Get a single parking spot by ID
  Future<ParkingSpot> getParkingSpotById(String parkingSpotId) async {
    try {
      final doc = await _firestore.collection('parkingSpots').doc(parkingSpotId).get();
      if (!doc.exists) {
        throw Exception('Parking spot not found');
      }
      return ParkingSpot.fromFirestore(doc);
    } catch (e) {
      throw Exception('Failed to get parking spot: $e');
    }
  }

  // ============ ATOMIC TRANSACTION METHODS ============

  /// Add new parking spot with atomic ID generation
  Future<ParkingSpot> addParkingSpot(ParkingSpot parkingSpot) async {
    return await _firestore.runTransaction<ParkingSpot>((transaction) async {
      final counterRef = _firestore.collection('counters').doc('parkingSpots');
      final counterDoc = await transaction.get(counterRef);
      
      int newNumber;
      if (!counterDoc.exists) {
        newNumber = 1;
      } else {
        newNumber = (counterDoc.data()!['lastId'] as int) + 1;
      }
      
      final newId = 'QP${newNumber.toString().padLeft(6, '0')}';
      
      final newParkingSpot = parkingSpot.copyWith(
        id: newId,
        updatedAt: DateTime.now(),
      );
      
      transaction.set(counterRef, {'lastId': newNumber});
      transaction.set(_firestore.collection('parkingSpots').doc(newId), newParkingSpot.toMap());
      
      return newParkingSpot;
    });
  }

  /// Update parking spot
  Future<void> updateParkingSpot(String id, Map<String, dynamic> updates) async {
    try {
      updates['updatedAt'] = Timestamp.fromDate(DateTime.now());
      await _firestore.collection('parkingSpots').doc(id).update(updates);
    } catch (e) {
      throw Exception('Failed to update parking spot: $e');
    }
  }

  /// Delete parking spot
  Future<void> deleteParkingSpot(String id) async {
    try {
      await _firestore.collection('parkingSpots').doc(id).delete();
    } catch (e) {
      throw Exception('Failed to delete parking spot: $e');
    }
  }

  /// Verify parking spot
  Future<void> verifyParkingSpot(String id, bool isVerified) async {
    try {
      await updateParkingSpot(id, {'isVerified': isVerified});
    } catch (e) {
      throw Exception('Failed to verify parking spot: $e');
    }
  }

  /// Update available spots atomically
  Future<void> updateAvailableSpotsAtomic(String parkingSpotId, int delta) async {
    final spotRef = _firestore.collection('parkingSpots').doc(parkingSpotId);
    
    await _firestore.runTransaction((transaction) async {
      final spotDoc = await transaction.get(spotRef);
      if (!spotDoc.exists) {
        throw Exception('Parking spot not found');
      }
      
      final currentSpots = spotDoc.data()!['availableSpots'] ?? 0;
      final totalSpots = spotDoc.data()!['totalSpots'] ?? 0;
      final newSpots = (currentSpots + delta).clamp(0, totalSpots);
      
      transaction.update(spotRef, {
        'availableSpots': newSpots,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    });
  }

  // ============ BOOKING METHODS ============

  /// Get all bookings with filters
  Future<List<Booking>> getAllBookings({
    int limit = 50,
    DocumentSnapshot? startAfter,
    BookingStatus? statusFilter,
    DateTime? startDate,
    DateTime? endDate,
    String? parkingSpotId,
    String? userId,
  }) async {
    try {
      Query query = _firestore.collection('bookings').orderBy('createdAt', descending: true);
      
      if (statusFilter != null) {
        query = query.where('status', isEqualTo: statusFilter.name);
      }
      
      if (parkingSpotId != null) {
        query = query.where('parkingSpotId', isEqualTo: parkingSpotId);
      }
      
      if (userId != null) {
        query = query.where('userId', isEqualTo: userId);
      }
      
      if (startAfter != null) {
        query = query.startAfterDocument(startAfter);
      }
      
      query = query.limit(limit);
      
      final querySnapshot = await query.get();
      return querySnapshot.docs.map((doc) => Booking.fromFirestore(doc)).toList();
    } catch (e) {
      throw Exception('Failed to fetch bookings: $e');
    }
  }

  /// Get a single booking by ID
  Future<Booking> getBookingById(String bookingId) async {
    try {
      final doc = await _firestore.collection('bookings').doc(bookingId).get();
      if (!doc.exists) {
        throw Exception('Booking not found');
      }
      return Booking.fromFirestore(doc);
    } catch (e) {
      throw Exception('Failed to get booking: $e');
    }
  }

  /// Process a booking (check-in/check-out) with atomic transaction
  Future<String> processBookingAtomic(String bookingId) async {
    return await _firestore.runTransaction<String>((transaction) async {
      final bookingRef = _firestore.collection('bookings').doc(bookingId);
      final bookingDoc = await transaction.get(bookingRef);
      
      if (!bookingDoc.exists) {
        throw Exception('Booking not found');
      }
      
      final booking = Booking.fromFirestore(bookingDoc);
      final now = DateTime.now();

      if (booking.status == BookingStatus.confirmed) {
        // Check-in
        transaction.update(bookingRef, {
          'status': BookingStatus.active.name,
          'checkedInAt': Timestamp.fromDate(now),
          'updatedAt': Timestamp.fromDate(now),
        });
        return 'Checked in successfully!';
        
      } else if (booking.status == BookingStatus.active) {
        // Check-out - also release the parking spot
        final parkingSpotRef = _firestore.collection('parkingSpots').doc(booking.parkingSpotId);
          final parkingSpotDoc = await transaction.get(parkingSpotRef);
        
        transaction.update(bookingRef, {
          'status': BookingStatus.completed.name,
          'checkedOutAt': Timestamp.fromDate(now),
          'updatedAt': Timestamp.fromDate(now),
        });
        
        if (parkingSpotDoc.exists) {
          final currentSpots = parkingSpotDoc.data()!['availableSpots'] ?? 0;
          final totalSpots = parkingSpotDoc.data()!['totalSpots'] ?? 0;
          transaction.update(parkingSpotRef, {
            'availableSpots': (currentSpots + 1).clamp(0, totalSpots),
            'updatedAt': FieldValue.serverTimestamp(),
          });
        }

        return 'Checked out successfully!';
      } else {
        return 'Invalid booking status: ${booking.status.name}';
      }
    });
  }

  /// Update booking status with atomic transaction
  Future<void> updateBookingStatusAtomic(String bookingId, BookingStatus newStatus) async {
    await _firestore.runTransaction((transaction) async {
      final bookingRef = _firestore.collection('bookings').doc(bookingId);
      final bookingDoc = await transaction.get(bookingRef);
      
      if (!bookingDoc.exists) {
        throw Exception('Booking not found');
      }
      
      final booking = Booking.fromFirestore(bookingDoc);
      
      // If cancelling, release the spot
      if (newStatus == BookingStatus.cancelled && 
          (booking.status == BookingStatus.confirmed || booking.status == BookingStatus.active)) {
        final parkingSpotRef = _firestore.collection('parkingSpots').doc(booking.parkingSpotId);
        final parkingSpotDoc = await transaction.get(parkingSpotRef);
        
        if (parkingSpotDoc.exists) {
          final currentSpots = parkingSpotDoc.data()!['availableSpots'] ?? 0;
          final totalSpots = parkingSpotDoc.data()!['totalSpots'] ?? 0;
          transaction.update(parkingSpotRef, {
            'availableSpots': (currentSpots + 1).clamp(0, totalSpots),
            'updatedAt': FieldValue.serverTimestamp(),
          });
        }
      }
      
      transaction.update(bookingRef, {
        'status': newStatus.name,
        'updatedAt': Timestamp.fromDate(DateTime.now()),
      });
    });
  }

  /// Update booking status (non-atomic version for simple updates)
  Future<void> updateBookingStatus(String bookingId, BookingStatus newStatus) async {
    try {
      await _firestore.collection('bookings').doc(bookingId).update({
        'status': newStatus.name,
        'updatedAt': Timestamp.fromDate(DateTime.now()),
      });
    } catch (e) {
      throw Exception('Failed to update booking status: $e');
    }
  }

  // ============ REVENUE & ANALYTICS ============

  /// Get revenue data
  Future<AggregatedRevenueData> getRevenueData({
    DateTime? startDate,
    DateTime? endDate,
    String? parkingSpotId,
  }) async {
    try {
      Query query = _firestore.collection('bookings').where('status', isEqualTo: 'completed');
      
      if (parkingSpotId != null) {
        query = query.where('parkingSpotId', isEqualTo: parkingSpotId);
      }
      
      final querySnapshot = await query.get();
      final bookings = querySnapshot.docs.map((doc) => Booking.fromFirestore(doc)).toList();
      
      // Filter by date in memory (Firestore limitation with multiple inequality filters)
      final filteredBookings = bookings.where((booking) {
        if (startDate != null && booking.startTime.isBefore(startDate)) return false;
        if (endDate != null && booking.startTime.isAfter(endDate)) return false;
        return true;
      }).toList();
      
      double totalRevenue = 0;
      int totalBookings = filteredBookings.length;
      final Map<String, double> dailyRevenue = {};
      final Map<String, int> dailyBookings = {};
      
      for (final booking in filteredBookings) {
        totalRevenue += booking.totalPrice;
        final dateKey = '${booking.startTime.year}-${booking.startTime.month.toString().padLeft(2, '0')}-${booking.startTime.day.toString().padLeft(2, '0')}';
        dailyRevenue[dateKey] = (dailyRevenue[dateKey] ?? 0) + booking.totalPrice;
        dailyBookings[dateKey] = (dailyBookings[dateKey] ?? 0) + 1;
      }
      
      final averageBookingValue = totalBookings > 0 ? totalRevenue / totalBookings : 0.0;
      
      // Build daily data list
      final dailyData = dailyRevenue.entries.map((entry) => DailyRevenueData(
        date: DateTime.parse(entry.key),
        revenue: entry.value,
        bookings: dailyBookings[entry.key] ?? 0,
      )).toList();
      
      dailyData.sort((a, b) => a.date.compareTo(b.date));
      
      return AggregatedRevenueData(
        totalRevenue: totalRevenue,
        totalBookings: totalBookings,
        averageBookingValue: averageBookingValue,
        dailyData: dailyData,
      );
    } catch (e) {
      throw Exception('Failed to fetch revenue data: $e');
    }
  }

  /// Get admin dashboard statistics (one-time fetch)
  Future<AdminStats> getAdminStats() async {
    try {
      final futures = await Future.wait([
        _firestore.collection('users').get(),
        _firestore.collection('parkingSpots').get(),
        _firestore.collection('bookings').get(),
      ]);
      
      return _calculateStats(futures[0], futures[1], futures[2]);
    } catch (e) {
      throw Exception('Failed to fetch admin statistics: $e');
    }
  }

  // ============ SEARCH METHODS ============

  /// Search users by email or name
  Future<List<User>> searchUsers(String searchTerm) async {
    try {
      final searchLower = searchTerm.toLowerCase();
      
      // Get all users and filter in memory for flexible search
      final snapshot = await _firestore.collection('users').get();
      final allUsers = snapshot.docs.map((doc) => User.fromFirestore(doc)).toList();
      
      return allUsers.where((user) {
        return user.email.toLowerCase().contains(searchLower) ||
               user.displayName.toLowerCase().contains(searchLower) ||
               (user.phoneNumber?.contains(searchTerm) ?? false);
      }).toList();
    } catch (e) {
      throw Exception('Failed to search users: $e');
    }
  }

  /// Search parking spots by name or address
  Future<List<ParkingSpot>> searchParkingSpots(String searchTerm) async {
    try {
      final searchLower = searchTerm.toLowerCase();
      
      final snapshot = await _firestore.collection('parkingSpots').get();
      final allSpots = snapshot.docs.map((doc) => ParkingSpot.fromFirestore(doc)).toList();
      
      return allSpots.where((spot) {
        return spot.name.toLowerCase().contains(searchLower) ||
               spot.address.toLowerCase().contains(searchLower) ||
               spot.id.toLowerCase().contains(searchLower);
      }).toList();
    } catch (e) {
      throw Exception('Failed to search parking spots: $e');
    }
  }

  /// Search bookings by ID or parking spot name
  Future<List<Booking>> searchBookings(String searchTerm) async {
    try {
      final searchLower = searchTerm.toLowerCase();
      
      final snapshot = await _firestore.collection('bookings').get();
      final allBookings = snapshot.docs.map((doc) => Booking.fromFirestore(doc)).toList();
      
      return allBookings.where((booking) {
        return booking.id.toLowerCase().contains(searchLower) ||
               booking.parkingSpotName.toLowerCase().contains(searchLower) ||
               booking.userId.toLowerCase().contains(searchLower);
      }).toList();
    } catch (e) {
      throw Exception('Failed to search bookings: $e');
    }
  }

  // ============ USER MANAGEMENT ============

  /// Update user role
  Future<void> updateUserRole(String userId, UserRole newRole) async {
    try {
      await _firestore.collection('users').doc(userId).update({
        'role': newRole.name,
        'updatedAt': Timestamp.fromDate(DateTime.now()),
      });
    } catch (e) {
      throw Exception('Failed to update user role: $e');
    }
  }

  /// Get user statistics
  Future<Map<String, int>> getUserStatistics() async {
    try {
      final usersSnapshot = await _firestore.collection('users').get();
      final stats = <String, int>{
        'total': usersSnapshot.docs.length,
        'user': 0,
        'parkingOperator': 0,
        'admin': 0,
      };

      for (final doc in usersSnapshot.docs) {
        final user = User.fromFirestore(doc);
        stats[user.role.name] = (stats[user.role.name] ?? 0) + 1;
      }

      return stats;
    } catch (e) {
      throw Exception('Failed to fetch user statistics: $e');
    }
  }
}

/// Simple RxDart-like combineLatest3 implementation
class Rx {
  static Stream<T> combineLatest3<A, B, C, T>(
    Stream<A> streamA,
    Stream<B> streamB,
    Stream<C> streamC,
    T Function(A a, B b, C c) combiner,
  ) {
    A? latestA;
    B? latestB;
    C? latestC;
    bool hasA = false, hasB = false, hasC = false;

    final controller = StreamController<T>.broadcast();
    
    void tryEmit() {
      if (hasA && hasB && hasC) {
        controller.add(combiner(latestA as A, latestB as B, latestC as C));
      }
    }

    StreamSubscription<A>? subA;
    StreamSubscription<B>? subB;
    StreamSubscription<C>? subC;

    controller.onListen = () {
      subA = streamA.listen((a) {
        latestA = a;
        hasA = true;
        tryEmit();
      });
      subB = streamB.listen((b) {
        latestB = b;
        hasB = true;
        tryEmit();
      });
      subC = streamC.listen((c) {
        latestC = c;
        hasC = true;
        tryEmit();
      });
    };

    controller.onCancel = () {
      subA?.cancel();
      subB?.cancel();
      subC?.cancel();
    };

    return controller.stream;
  }
}
