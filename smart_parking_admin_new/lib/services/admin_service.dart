// lib/services/admin_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user.dart';
import '../models/parking_spot.dart';
import '../models/booking.dart';
import '../models/revenue_data.dart';
import '../models/admin_stats.dart';

class AdminService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Get all users with pagination
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

  // Get a single user by ID
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

  // Get user statistics
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

  // Get all parking spots
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

  // Get a single parking spot by ID
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

  // Add new parking spot
  Future<String> addParkingSpot(ParkingSpot parkingSpot) async {
    try {
      final docRef = await _firestore.collection('parkingSpots').add(parkingSpot.toMap());
      return docRef.id;
    } catch (e) {
      throw Exception('Failed to add parking spot: $e');
    }
  }

  // Update parking spot
  Future<void> updateParkingSpot(String id, Map<String, dynamic> updates) async {
    try {
      updates['updatedAt'] = Timestamp.fromDate(DateTime.now());
      await _firestore.collection('parkingSpots').doc(id).update(updates);
    } catch (e) {
      throw Exception('Failed to update parking spot: $e');
    }
  }

  // Delete parking spot
  Future<void> deleteParkingSpot(String id) async {
    try {
      await _firestore.collection('parkingSpots').doc(id).delete();
    } catch (e) {
      throw Exception('Failed to delete parking spot: $e');
    }
  }

  // Verify parking spot
  Future<void> verifyParkingSpot(String id, bool isVerified) async {
    try {
      await updateParkingSpot(id, {'isVerified': isVerified});
    } catch (e) {
      throw Exception('Failed to verify parking spot: $e');
    }
  }

  // Get all bookings with filters
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
      
      if (startDate != null) {
        query = query.where('startTime', isGreaterThanOrEqualTo: Timestamp.fromDate(startDate));
      }
      
      if (endDate != null) {
        query = query.where('startTime', isLessThanOrEqualTo: Timestamp.fromDate(endDate));
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

  // Get a single booking by ID
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

  // Process a booking (check-in/check-out)
  Future<String> processBooking(String bookingId) async {
    try {
      final booking = await getBookingById(bookingId);
      final now = DateTime.now();

      if (booking.status == BookingStatus.confirmed) {
        // Check-in
        await updateBookingStatus(bookingId, BookingStatus.active);
        await _firestore.collection('bookings').doc(bookingId).update({'checkedInAt': Timestamp.fromDate(now)});
        return 'Checked in successfully!';
      } else if (booking.status == BookingStatus.active) {
        // Check-out
        await updateBookingStatus(bookingId, BookingStatus.completed);
        await _firestore.collection('bookings').doc(bookingId).update({'checkedOutAt': Timestamp.fromDate(now)});

        // Increment available spots
        final parkingSpotRef = _firestore.collection('parkingSpots').doc(booking.parkingSpotId);
        await _firestore.runTransaction((transaction) async {
          final parkingSpotDoc = await transaction.get(parkingSpotRef);
          if (parkingSpotDoc.exists) {
            final currentSpots = parkingSpotDoc.data()!['availableSpots'] ?? 0;
            transaction.update(parkingSpotRef, {'availableSpots': currentSpots + 1});
          }
        });

        return 'Checked out successfully!';
      } else {
        return 'Invalid booking status: ${booking.status.name}';
      }
    } catch (e) {
      return 'Error processing booking: $e';
    }
  }

  // Get revenue data
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
      
      if (startDate != null) {
        query = query.where('startTime', isGreaterThanOrEqualTo: Timestamp.fromDate(startDate));
      }
      
      if (endDate != null) {
        query = query.where('startTime', isLessThanOrEqualTo: Timestamp.fromDate(endDate));
      }
      
      final querySnapshot = await query.get();
      final bookings = querySnapshot.docs.map((doc) => Booking.fromFirestore(doc)).toList();
      
      double totalRevenue = 0;
      int totalBookings = bookings.length;
      final Map<String, double> dailyRevenue = {};
      final Map<String, int> dailyBookings = {};
      
      for (final booking in bookings) {
        totalRevenue += booking.totalPrice;
        final dateKey = '${booking.startTime.year}-${booking.startTime.month}-${booking.startTime.day}';
        dailyRevenue[dateKey] = (dailyRevenue[dateKey] ?? 0) + booking.totalPrice;
        dailyBookings[dateKey] = (dailyBookings[dateKey] ?? 0) + 1;
      }
      
      final averageBookingValue = totalBookings > 0 ? totalRevenue / totalBookings : 0.0;
      
      return AggregatedRevenueData(
        totalRevenue: totalRevenue,
        totalBookings: totalBookings,
        averageBookingValue: averageBookingValue,
        dailyData: [], // Can be populated from dailyRevenue map
      );
    } catch (e) {
      throw Exception('Failed to fetch revenue data: $e');
    }
  }

  // Get admin dashboard statistics
  Future<AdminStats> getAdminStats() async {
    try {
      // Get counts in parallel
      final futures = await Future.wait([
        _firestore.collection('users').get(),
        _firestore.collection('parkingSpots').get(),
        _firestore.collection('bookings').get(),
      ]);
      
      final usersSnapshot = futures[0];
      final parkingSpotsSnapshot = futures[1];
      final bookingsSnapshot = futures[2];
      
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
      int activeBookings = 0;
      
      for (final doc in bookingsSnapshot.docs) {
        final booking = Booking.fromFirestore(doc);
        bookingsByStatus[booking.status.name] = (bookingsByStatus[booking.status.name] ?? 0) + 1;
        
        if (booking.status == BookingStatus.completed) {
          totalRevenue += booking.totalPrice;
        }
        
        if (booking.status == BookingStatus.active || booking.status == BookingStatus.confirmed) {
          activeBookings++;
        }
      }
      
      final averageRating = ratedSpots > 0 ? totalRating / ratedSpots : 0.0;
      
      return AdminStats(
        totalUsers: usersSnapshot.docs.length,
        totalParkingSpots: parkingSpotsSnapshot.docs.length,
        totalBookings: bookingsSnapshot.docs.length,
        totalRevenue: totalRevenue,
        activeBookings: activeBookings,
        availableParkingSpots: availableParkingSpots,
        averageRating: averageRating,
        usersByRole: usersByRole,
        bookingsByStatus: bookingsByStatus,
        parkingSpotsByStatus: parkingSpotsByStatus,
        lastUpdated: DateTime.now(),
      );
    } catch (e) {
      throw Exception('Failed to fetch admin statistics: $e');
    }
  }

  // Update booking status (admin action)
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

  // Search users by email or name
  Future<List<User>> searchUsers(String searchTerm) async {
    try {
      // Search by email
      final emailQuery = await _firestore
          .collection('users')
          .where('email', isGreaterThanOrEqualTo: searchTerm.toLowerCase())
          .where('email', isLessThanOrEqualTo: '${searchTerm.toLowerCase()}\uf8ff')
          .get();

      // Search by display name
      final nameQuery = await _firestore
          .collection('users')
          .where('displayName', isGreaterThanOrEqualTo: searchTerm)
          .where('displayName', isLessThanOrEqualTo: '$searchTerm\uf8ff')
          .get();

      final users = <String, User>{};
      
      // Combine results and remove duplicates
      for (final doc in [...emailQuery.docs, ...nameQuery.docs]) {
        users[doc.id] = User.fromFirestore(doc);
      }
      
      return users.values.toList();
    } catch (e) {
      throw Exception('Failed to search users: $e');
    }
  }

  // Update user role
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
}
