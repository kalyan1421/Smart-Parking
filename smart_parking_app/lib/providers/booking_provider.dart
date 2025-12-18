// lib/providers/booking_provider.dart - Firebase-based booking management
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';
import '../core/database/database_service.dart';
import '../models/booking.dart';
import '../models/parking_spot.dart';
import '../models/vehicle.dart';
import '../repositories/booking_repository.dart';
import '../services/pdf_manager.dart';

class BookingProvider with ChangeNotifier {
  final BookingRepository _bookingRepository;
  
  List<Booking> _bookings = [];
  bool _isLoading = false;
  String? _error;
  Booking? _currentBooking;
  
  final Uuid _uuid = const Uuid();
  
  BookingProvider(this._bookingRepository);
  
  // Getters
  List<Booking> get bookings => _bookings;
  List<Booking> get activeBookings => _bookings.where((b) => b.isActive).toList();
  List<Booking> get bookingHistory => _bookings.where((b) => b.isCompleted || b.isCancelled).toList();
  List<Booking> get upcomingBookings => _bookings.where((b) => b.isUpcoming && (b.isConfirmed || b.isPending)).toList();
  List<Booking> get completedBookings => _bookings.where((b) => b.isCompleted).toList();
  List<Booking> get cancelledBookings => _bookings.where((b) => b.isCancelled).toList();
  List<Booking> get currentActiveBookings => _bookings.where((b) => b.isHappeningNow && b.isActive).toList();
  bool get isLoading => _isLoading;
  String? get error => _error;
  Booking? get currentBooking => _currentBooking;
  
  // Load user bookings
  Future<void> loadUserBookings(String userId) async {
    _setLoading(true);
    try {
      print('🧩 Phase1Audit: Loading bookings for userId=$userId');
      final querySnapshot = await DatabaseService.collection('bookings')
          .where('userId', isEqualTo: userId)
          .orderBy('createdAt', descending: true)
          .get();
      
      _bookings = querySnapshot.docs
          .map((doc) => Booking.fromFirestore(doc))
          .toList();
      
      _error = null;
    } catch (e) {
      _error = 'Failed to load bookings: $e';
      print('🧩 Phase1Audit: Error loadUserBookings -> $e');
    } finally {
      _setLoading(false);
    }
  }

  // Create a new booking with Firestore transaction
  Future<Booking?> createBooking(
    String userId,
    ParkingSpot parkingSpot,
    DateTime startTime,
    DateTime endTime,
    double totalPrice, {
    String? vehicleId,
    String? notes,
  }) async {
    _setLoading(true);
    try {
      // Check for conflicting bookings before transaction
      // Only check for active/confirmed bookings that haven't ended yet
      final now = DateTime.now();
      final conflictingBookings = await DatabaseService.collection('bookings')
          .where('parkingSpotId', isEqualTo: parkingSpot.id)
          .where('status', whereIn: ['confirmed', 'active'])
          .limit(100)
          .get();
      
      print('🧩 DEBUG: Checking conflicts for spot ${parkingSpot.id}');
      print('🧩 DEBUG: New booking time: $startTime to $endTime');
      print('🧩 DEBUG: Found ${conflictingBookings.docs.length} potential conflicting bookings');
      
      bool hasConflict = false;
      Booking? conflictingBooking;
      for (var doc in conflictingBookings.docs) {
        final booking = Booking.fromFirestore(doc);
        
        // Skip if booking has already ended (past bookings don't block new ones)
        if (booking.endTime.isBefore(now)) {
          print('🧩 DEBUG: Skipping past booking ${booking.id} (ended: ${booking.endTime}, now: $now)');
          continue;
        }
        
        // Skip if booking is cancelled, completed, or expired
        if (booking.isCancelled || booking.isCompleted || booking.isExpired) {
          print('🧩 DEBUG: Skipping ${booking.status} booking ${booking.id}');
          continue;
        }
        
        // Check for time overlap
        if (_isTimeConflict(startTime, endTime, booking.startTime, booking.endTime)) {
          hasConflict = true;
          conflictingBooking = booking;
          print('🧩 DEBUG: ⚠️ Conflict found with booking ${booking.id}');
          print('🧩 DEBUG: Conflicting booking time: ${booking.startTime} to ${booking.endTime}');
          print('🧩 DEBUG: Conflicting booking status: ${booking.status}');
          break;
        } else {
          print('🧩 DEBUG: No conflict with booking ${booking.id} (${booking.startTime} to ${booking.endTime})');
        }
      }
      
      if (hasConflict) {
        final conflictMsg = conflictingBooking != null
            ? 'Time slot conflicts with existing booking (${conflictingBooking.startTime} - ${conflictingBooking.endTime})'
            : 'Time slot is already booked';
        print('🧩 DEBUG: ❌ Booking rejected: $conflictMsg');
        throw Exception(conflictMsg);
      }
      
      print('🧩 DEBUG: ✅ No conflicts found, proceeding with booking creation');
      
      // Use Firestore transaction to ensure data consistency
      final bookingId = _uuid.v4();
      Booking? createdBooking;
      
      await DatabaseService.runTransaction((transaction) async {
        // Get parking spot details
        final spotDoc = await transaction.get(
          DatabaseService.collection('parkingSpots').doc(parkingSpot.id)
        );
        
        if (!spotDoc.exists) {
          throw Exception('Parking spot not found');
        }
        
        final spot = ParkingSpot.fromFirestore(spotDoc);
        
        // Check availability
        if (spot.availableSpots <= 0) {
          throw Exception('No available spots');
        }
        
        // Calculate total price
        final duration = endTime.difference(startTime);
        final hours = duration.inMinutes / 60.0;
        final calculatedPrice = hours * spot.pricePerHour;
        
        // Create booking
        final booking = Booking(
          id: bookingId,
          userId: userId,
          parkingSpotId: parkingSpot.id,
          parkingSpotName: spot.name,
          vehicleId: vehicleId ?? '',
          latitude: spot.latitude,
          longitude: spot.longitude,
          startTime: startTime,
          endTime: endTime,
          pricePerHour: spot.pricePerHour,
          totalPrice: calculatedPrice,
          status: BookingStatus.confirmed,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
          notes: notes,
        );
        
        // DEBUG: Log booking data before saving
        final bookingMap = booking.toMap();
        print('🧩 DEBUG: Creating booking with data:');
        print('  - userId: ${bookingMap['userId']}');
        print('  - parkingSpotId: ${bookingMap['parkingSpotId']}');
        print('  - status: ${bookingMap['status']}');
        print('  - totalPrice: ${bookingMap['totalPrice']}');
        print('  - startTime: ${bookingMap['startTime']}');
        print('  - endTime: ${bookingMap['endTime']}');
        print('  - createdAt: ${bookingMap['createdAt']}');
        print('  - updatedAt: ${bookingMap['updatedAt']}');
        print('  - All keys: ${bookingMap.keys.toList()}');
        
        // Save booking
        transaction.set(
          DatabaseService.collection('bookings').doc(bookingId),
          bookingMap
        );
        
        // Update parking spot availability
        transaction.update(
          DatabaseService.collection('parkingSpots').doc(parkingSpot.id),
          {
            'availableSpots': spot.availableSpots - 1,
            'updatedAt': FieldValue.serverTimestamp(),
          }
        );
        
        createdBooking = booking;
      });
      
      if (createdBooking != null) {
        // Add booking to local list
        _bookings.insert(0, createdBooking!);
        _currentBooking = createdBooking;
        _error = null;
        notifyListeners();
        
        // Note: PDF generation will be handled by the UI layer
        // after successful booking creation to access BuildContext
        
        return createdBooking;
      }
      return null;
    } catch (e) {
      _error = 'Failed to create booking: $e';
      print('🧩 Phase1Audit: Error createBooking -> $e');
      notifyListeners();
      return null;
    } finally {
      _setLoading(false);
    }
  }
  
  // Stream user bookings in real-time
  Stream<List<Booking>> streamUserBookings(String userId) {
    print('🧩 Phase1Audit: Subscribing to bookings stream for userId=$userId');
    return DatabaseService.collection('bookings')
        .where('userId', isEqualTo: userId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => Booking.fromFirestore(doc))
            .toList());
  }

  // Check for time conflicts
  bool _isTimeConflict(DateTime start1, DateTime end1, DateTime start2, DateTime end2) {
    return start1.isBefore(end2) && end1.isAfter(start2);
  }
  
  // Cancel a booking with refund calculation
  Future<bool> cancelBooking(String bookingId) async {
    _setLoading(true);
    try {
      bool success = false;
      
      await DatabaseService.runTransaction((transaction) async {
        // Get booking details
        final bookingDoc = await transaction.get(
          DatabaseService.collection('bookings').doc(bookingId)
        );
        
        if (!bookingDoc.exists) {
          throw Exception('Booking not found');
        }
        
        final booking = Booking.fromFirestore(bookingDoc);
        
        // Check if booking can be cancelled
        if (!booking.canBeCancelled()) {
          throw Exception('Booking cannot be cancelled');
        }
        
        // Calculate refund
        final refundAmount = booking.getRefundAmount();
        final cancellationFee = booking.totalPrice - refundAmount;
        
        // Update booking status
        transaction.update(
          DatabaseService.collection('bookings').doc(bookingId),
          {
            'status': BookingStatus.cancelled.name,
            'cancellationFee': cancellationFee,
            'updatedAt': FieldValue.serverTimestamp(),
          }
        );
        
        // Update parking spot availability
        final spotDoc = await transaction.get(
          DatabaseService.collection('parking_spots').doc(booking.parkingSpotId)
        );
        
        if (spotDoc.exists) {
          final spot = ParkingSpot.fromFirestore(spotDoc);
          transaction.update(
            DatabaseService.collection('parking_spots').doc(booking.parkingSpotId),
            {
              'availableSpots': spot.availableSpots + 1,
              'updatedAt': FieldValue.serverTimestamp(),
            }
          );
        }
        
        // Update local booking
        final index = _bookings.indexWhere((b) => b.id == bookingId);
        if (index != -1) {
          _bookings[index] = booking.copyWith(
            status: BookingStatus.cancelled,
            cancellationFee: cancellationFee,
            updatedAt: DateTime.now(),
          );
        }
        
        success = true;
      });
      
      if (success) {
        _error = null;
        notifyListeners();
        return true;
      }
      return false;
    } catch (e) {
      _error = 'Failed to cancel booking: $e';
      notifyListeners();
      return false;
    } finally {
      _setLoading(false);
    }
  }
  
  // Check in to parking spot
  Future<bool> checkIn(String bookingId) async {
    try {
      await DatabaseService.collection('bookings').doc(bookingId).update({
        'status': BookingStatus.active.name,
        'checkedInAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      
      // Update local booking
      final index = _bookings.indexWhere((b) => b.id == bookingId);
      if (index != -1) {
        _bookings[index] = _bookings[index].copyWith(
          status: BookingStatus.active,
          checkedInAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );
      }
      
      notifyListeners();
      return true;
    } catch (e) {
      _error = 'Failed to check in: $e';
      print('🧩 Phase1Audit: Error checkIn -> $e');
      notifyListeners();
      return false;
    }
  }
  
  // Check out from parking spot
  Future<bool> checkOut(String bookingId) async {
    try {
      await DatabaseService.collection('bookings').doc(bookingId).update({
        'status': BookingStatus.completed.name,
        'checkedOutAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      
      // Update local booking
      final index = _bookings.indexWhere((b) => b.id == bookingId);
      if (index != -1) {
        _bookings[index] = _bookings[index].copyWith(
          status: BookingStatus.completed,
          checkedOutAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );
      }
      
      notifyListeners();
      return true;
    } catch (e) {
      _error = 'Failed to check out: $e';
      print('🧩 Phase1Audit: Error checkOut -> $e');
      notifyListeners();
      return false;
    }
  }

  // Complete a booking (backward compatibility)
  Future<bool> completeBooking(String bookingId) async {
    return await checkOut(bookingId);
  }
  
  // Get a booking by ID
  Future<Booking?> getBookingById(String bookingId) async {
    try {
      // First check if it's in our loaded bookings
      final localBooking = _bookings.where((b) => b.id == bookingId).firstOrNull;
      if (localBooking != null) return localBooking;
      
      // If not found locally, fetch from Firestore
      final doc = await DatabaseService.collection('bookings').doc(bookingId).get();
      if (doc.exists) {
        return Booking.fromFirestore(doc);
      }
      return null;
    } catch (e) {
      _error = 'Failed to get booking: $e';
      print('🧩 Phase1Audit: Error getBookingById -> $e');
      notifyListeners();
      return null;
    }
  }

  // Add feedback to completed booking
  Future<bool> addFeedback(String bookingId, double rating, String? review) async {
    try {
      final feedback = {
        'rating': rating,
        'review': review,
        'createdAt': FieldValue.serverTimestamp(),
      };
      
      await DatabaseService.collection('bookings').doc(bookingId).update({
        'feedback': feedback,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      
      // Update local booking
      final index = _bookings.indexWhere((b) => b.id == bookingId);
      if (index != -1) {
        _bookings[index] = _bookings[index].copyWith(
          feedback: {
            'rating': rating,
            'review': review,
            'createdAt': DateTime.now().toIso8601String(),
          },
          updatedAt: DateTime.now(),
        );
      }
      
      notifyListeners();
      return true;
    } catch (e) {
      _error = 'Failed to add feedback: $e';
      print('🧩 Phase1Audit: Error addFeedback -> $e');
      notifyListeners();
      return false;
    }
  }

  // Check availability for a time slot
  Future<bool> isTimeSlotAvailable(String spotId, DateTime startTime, DateTime endTime) async {
    try {
      final querySnapshot = await DatabaseService.collection('bookings')
          .where('parkingSpotId', isEqualTo: spotId)
          .where('status', whereIn: ['confirmed', 'active'])
          .get();
      
      for (var doc in querySnapshot.docs) {
        final booking = Booking.fromFirestore(doc);
        if (_isTimeConflict(startTime, endTime, booking.startTime, booking.endTime)) {
          return false;
        }
      }
      
      return true;
    } catch (e) {
      return false;
    }
  }
  
  // Error and loading helpers
  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }
  
  void _setError(String errorMessage) {
    _error = errorMessage;
    notifyListeners();
  }
  
  void clearError() {
    _error = null;
    notifyListeners();
  }

  void setCurrentBooking(Booking? booking) {
    _currentBooking = booking;
    notifyListeners();
  }

  // PDF Receipt Generation Methods
  
  // Generate PDF receipt for booking
  Future<void> generateBookingReceipt(
    BuildContext context, 
    Booking booking, {
    String? transactionId,
    String? paymentMethod,
  }) async {
    try {
      await PdfManager.generateBookingReceipt(
        context: context,
        booking: booking,
        transactionId: transactionId,
        paymentMethod: paymentMethod,
      );
    } catch (e) {
      _error = 'Failed to generate receipt: $e';
      notifyListeners();
    }
  }

  // Handle booking completion with PDF generation
  Future<void> completeBookingWithReceipt(
    BuildContext context, 
    Booking booking, {
    String? transactionId,
    String? paymentMethod,
  }) async {
    try {
      await PdfManager.handleBookingCompletion(
        context: context,
        booking: booking,
        transactionId: transactionId,
        paymentMethod: paymentMethod,
      );
    } catch (e) {
      _error = 'Failed to complete booking with receipt: $e';
      notifyListeners();
    }
  }

  // Handle booking cancellation with refund receipt
  Future<void> cancelBookingWithReceipt(
    BuildContext context, 
    String bookingId, {
    String refundReason = 'Booking cancelled by user',
  }) async {
    try {
      final booking = _bookings.firstWhere((b) => b.id == bookingId);
      final refundAmount = _calculateRefundAmount(booking);
      
      await cancelBooking(bookingId);
      // Assume cancellation was successful if no exception was thrown
      
      await PdfManager.handleBookingCancellation(
          context: context,
          booking: booking,
          refundAmount: refundAmount,
          refundReason: refundReason,
        );
    } catch (e) {
      _error = 'Failed to cancel booking with receipt: $e';
      notifyListeners();
    }
  }

  // Generate batch receipts for multiple bookings
  Future<void> generateBatchReceipts(
    BuildContext context, 
    List<Booking> bookings,
  ) async {
    try {
      await PdfManager.generateBatchReceipts(
        context: context,
        bookings: bookings,
      );
    } catch (e) {
      _error = 'Failed to generate batch receipts: $e';
      notifyListeners();
    }
  }

  // Calculate refund amount based on cancellation policy
  double _calculateRefundAmount(Booking booking) {
    final now = DateTime.now();
    final hoursUntilStart = booking.startTime.difference(now).inHours;
    
    // Refund policy:
    // - More than 24 hours: 90% refund
    // - 2-24 hours: 50% refund
    // - Less than 2 hours: No refund
    if (hoursUntilStart > 24) {
      return booking.totalPrice * 0.9; // 90% refund
    } else if (hoursUntilStart > 2) {
      return booking.totalPrice * 0.5; // 50% refund
    } else {
      return 0.0; // No refund
    }
  }

  // Backward compatibility methods
  Future<void> loadActiveBookings(String userId) async {
    await loadUserBookings(userId);
  }

  Future<void> loadBookingHistory(String userId) async {
    await loadUserBookings(userId);
  }
  
  // Additional methods for booking history are already defined above
}
