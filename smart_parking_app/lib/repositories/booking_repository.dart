// lib/repositories/booking_repository.dart - Firebase-based booking repository
import 'package:cloud_firestore/cloud_firestore.dart';
import '../core/database/database_service.dart';
import '../models/booking.dart';
import '../models/parking_spot.dart';

class BookingRepository {
  final CollectionReference _collection = DatabaseService.collection('bookings');
  final CollectionReference _usersCollection = DatabaseService.collection('users');

  // Create a new booking
  Future<Booking> createBooking(
    String userId,
    ParkingSpot parkingSpot,
    DateTime startTime,
    DateTime endTime,
    double totalPrice
  ) async {
    // This method is now handled by BookingProvider with transactions
    // Keeping for backward compatibility
    throw UnimplementedError('Use BookingProvider.createBooking() instead');
  }
  
  // Get all bookings for a user
  Future<List<Booking>> getUserBookings(String userId) async {
    final querySnapshot = await _collection
        .where('userId', isEqualTo: userId)
        .orderBy('createdAt', descending: true)
        .get();
    
    return querySnapshot.docs
        .map((doc) => Booking.fromFirestore(doc))
        .toList();
  }
  
  // Get a specific booking by ID
  Future<Booking?> getBookingById(String bookingId) async {
    final doc = await _collection.doc(bookingId).get();
    
    if (!doc.exists) {
      return null;
    }
    
    return Booking.fromFirestore(doc);
  }
  
  // Cancel a booking
  Future<bool> cancelBooking(String bookingId) async {
    try {
      await _collection.doc(bookingId).update({
        'status': 'cancelled',
        'updatedAt': FieldValue.serverTimestamp(),
      });
      return true;
    } catch (e) {
      return false;
    }
  }
  
  // Mark a booking as completed
  Future<bool> completeBooking(String bookingId) async {
    try {
      await _collection.doc(bookingId).update({
        'status': 'completed',
        'updatedAt': FieldValue.serverTimestamp(),
      });
      return true;
    } catch (e) {
      return false;
    }
  }
  
  // Get active bookings for a user
  Future<List<Booking>> getActiveBookings(String userId) async {
    final querySnapshot = await _collection
        .where('userId', isEqualTo: userId)
        .where('status', isEqualTo: 'active')
        .orderBy('startTime')
        .get();
    
    return querySnapshot.docs
        .map((doc) => Booking.fromFirestore(doc))
        .toList();
  }
  
  // Get booking history for a user (completed and cancelled bookings)
  Future<List<Booking>> getBookingHistory(String userId) async {
    final querySnapshot = await _collection
        .where('userId', isEqualTo: userId)
        .where('status', whereIn: ['completed', 'cancelled'])
        .orderBy('updatedAt', descending: true)
        .get();
    
    return querySnapshot.docs
        .map((doc) => Booking.fromFirestore(doc))
        .toList();
  }
}