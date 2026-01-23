// lib/providers/booking_provider.dart - Production-grade booking management
// Transaction-safe with real-time sync and race condition prevention

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../core/database/database_service.dart';
import '../models/booking.dart';
import '../models/parking_spot.dart';
import '../repositories/booking_repository.dart';
import '../services/pdf_manager.dart';
import '../services/notification_service.dart';

class BookingProvider with ChangeNotifier {
  final BookingRepository _bookingRepository;
  
  List<Booking> _bookings = [];
  bool _isLoading = false;
  String? _error;
  Booking? _currentBooking;
  
  // Real-time stream subscription
  StreamSubscription<QuerySnapshot>? _bookingsSubscription;
  
  // Debouncing for notifications
  Timer? _notifyDebounce;
  
  // Prevent notifyListeners during build
  bool _isNotifying = false;

  BookingProvider(this._bookingRepository);
  
  // ═══════════════════════════════════════════════════════════════════════════
  // GETTERS
  // ═══════════════════════════════════════════════════════════════════════════
  
  List<Booking> get bookings => _bookings;
  List<Booking> get activeBookings => _bookings
      .where((b) => b.isActive || b.isConfirmed)
      .toList();
  List<Booking> get bookingHistory => _bookings
      .where((b) => b.isCompleted || b.isCancelled)
      .toList();
  List<Booking> get upcomingBookings => _bookings
      .where((b) => b.isUpcoming && (b.isConfirmed || b.isPending))
      .toList();
  List<Booking> get completedBookings => _bookings
      .where((b) => b.isCompleted)
      .toList();
  List<Booking> get cancelledBookings => _bookings
      .where((b) => b.isCancelled)
      .toList();
  List<Booking> get currentActiveBookings => _bookings
      .where((b) => b.isHappeningNow && b.isActive)
      .toList();
  bool get isLoading => _isLoading;
  String? get error => _error;
  Booking? get currentBooking => _currentBooking;
  
  // ═══════════════════════════════════════════════════════════════════════════
  // LIFECYCLE
  // ═══════════════════════════════════════════════════════════════════════════
  
  @override
  void dispose() {
    _bookingsSubscription?.cancel();
    _notifyDebounce?.cancel();
    super.dispose();
  }
  
  // ═══════════════════════════════════════════════════════════════════════════
  // SAFE NOTIFY LISTENERS (prevents build-time notifications)
  // ═══════════════════════════════════════════════════════════════════════════
  
  void _safeNotifyListeners() {
    if (_isNotifying) return;
    _isNotifying = true;
    
    // Use addPostFrameCallback to defer notifications
    SchedulerBinding.instance.addPostFrameCallback((_) {
      _isNotifying = false;
      notifyListeners();
    });
  }
  
  // ═══════════════════════════════════════════════════════════════════════════
  // REAL-TIME STREAMING
  // ═══════════════════════════════════════════════════════════════════════════
  
  /// Start streaming user's bookings for real-time updates
  void startStreamingBookings(String userId) {
    _bookingsSubscription?.cancel();
    
    _bookingsSubscription = DatabaseService.streamUserBookings(userId)
        .listen(
          (snapshot) {
            _bookings = snapshot.docs
                .map((doc) => Booking.fromFirestore(doc))
                .toList();
            _error = null;
            _notifyListenersDebounced();
          },
          onError: (error) {
            _error = 'Failed to stream bookings: $error';
            _notifyListenersDebounced();
          },
        );
  }
  
  /// Stream for a specific booking (for detail view)
  Stream<Booking?> streamBooking(String bookingId) {
    return DatabaseService.collection('bookings')
        .doc(bookingId)
        .snapshots()
        .map((doc) {
          if (!doc.exists) return null;
          return Booking.fromFirestore(doc);
        });
  }
  
  // ═══════════════════════════════════════════════════════════════════════════
  // LOAD BOOKINGS (One-time fetch for backward compatibility)
  // ═══════════════════════════════════════════════════════════════════════════
  
  Future<void> loadUserBookings(String userId) async {
    _isLoading = true;
    // Don't notify immediately - use debounced approach
    _notifyListenersDebounced();
    
    try {
      final querySnapshot = await DatabaseService.collection('bookings')
          .where('userId', isEqualTo: userId)
          .orderBy('createdAt', descending: true)
          .limit(100)
          .get();
      
      _bookings = querySnapshot.docs
          .map((doc) => Booking.fromFirestore(doc))
          .toList();
      
      _error = null;
    } catch (e) {
      _error = 'Failed to load bookings: $e';
      debugPrint('❌ Error loadUserBookings: $e');
    } finally {
      _isLoading = false;
      _notifyListenersDebounced();
    }
  }
  
  // ═══════════════════════════════════════════════════════════════════════════
  // CREATE BOOKING (Transaction-safe, prevents double booking)
  // ═══════════════════════════════════════════════════════════════════════════
  
  /// Create a new booking using atomic transaction
  /// Prevents double-booking and ensures slot count consistency
  Future<Booking?> createBooking(
    String userId,
    ParkingSpot parkingSpot,
    DateTime startTime,
    DateTime endTime,
    double totalPrice,
    String paymentMethod, {
    String? vehicleId,
    String? notes,
  }) async {
    _isLoading = true;
    _safeNotifyListeners();
    
    try {
      // Use atomic booking creation from DatabaseService
      final result = await DatabaseService.createBookingAtomic(
        userId: userId,
        parkingSpotId: parkingSpot.id,
        vehicleId: vehicleId ?? '',
        startTime: startTime,
        endTime: endTime,
        pricePerHour: parkingSpot.pricePerHour,
        paymentMethod: paymentMethod,
        notes: notes,
      );
      
      if (!result.isSuccess) {
        _error = result.error;
        _isLoading = false;
        _safeNotifyListeners();
        return null;
      }
      
      // Fetch the created booking
      final bookingDoc = await DatabaseService.collection('bookings')
          .doc(result.bookingId)
          .get();
      
      if (!bookingDoc.exists) {
        _error = 'Booking created but not found';
        _isLoading = false;
        _safeNotifyListeners();
        return null;
      }
      
      final createdBooking = Booking.fromFirestore(bookingDoc);
      
      // Add to local list
      _bookings.insert(0, createdBooking);
      _currentBooking = createdBooking;
      
      // Show confirmation notification
      await _showBookingNotification(createdBooking, parkingSpot.name);
      
      _error = null;
      _isLoading = false;
      _safeNotifyListeners();
      
      return createdBooking;
      
    } catch (e) {
      _error = 'Failed to create booking: $e';
      debugPrint('❌ Error createBooking: $e');
      _isLoading = false;
      _safeNotifyListeners();
      return null;
    }
  }
  
  Future<void> _showBookingNotification(Booking booking, String spotName) async {
    try {
      // Show confirmation notification
      await NotificationService().showNotification(
        id: booking.startTime.millisecondsSinceEpoch ~/ 1000,
        title: 'Booking Confirmed',
        body: 'Your parking at $spotName is confirmed.',
      );
      
      // Schedule expiry reminder (15 mins before end)
      final reminderTime = booking.endTime.subtract(const Duration(minutes: 15));
      if (reminderTime.isAfter(DateTime.now())) {
        await NotificationService().scheduleNotification(
          id: (booking.endTime.millisecondsSinceEpoch ~/ 1000) + 1,
          title: 'Parking Expiring Soon',
          body: 'Your parking session at $spotName expires in 15 minutes.',
          scheduledTime: reminderTime,
        );
      }
    } catch (e) {
      debugPrint('⚠️ Failed to show notification: $e');
    }
  }
  
  // ═══════════════════════════════════════════════════════════════════════════
  // CANCEL BOOKING (Transaction-safe with slot release)
  // ═══════════════════════════════════════════════════════════════════════════
  
  /// Cancel a booking using atomic transaction
  /// Ensures slot count is properly released
  Future<bool> cancelBooking(String bookingId) async {
    _isLoading = true;
    _safeNotifyListeners();
    
    try {
      final result = await DatabaseService.cancelBookingAtomic(
        bookingId: bookingId,
        reason: 'Cancelled by user',
      );
      
      if (!result.isSuccess) {
        _error = result.error;
        _isLoading = false;
        _safeNotifyListeners();
        return false;
      }
      
      // Update local booking
      final index = _bookings.indexWhere((b) => b.id == bookingId);
      if (index != -1) {
        _bookings[index] = _bookings[index].copyWith(
          status: BookingStatus.cancelled,
          cancellationFee: _bookings[index].totalPrice - (result.refundAmount ?? 0),
          updatedAt: DateTime.now(),
        );
      }
      
      _error = null;
      _isLoading = false;
      _safeNotifyListeners();
      return true;
      
    } catch (e) {
      _error = 'Failed to cancel booking: $e';
      debugPrint('❌ Error cancelBooking: $e');
      _isLoading = false;
      _safeNotifyListeners();
      return false;
    }
  }
  
  // ═══════════════════════════════════════════════════════════════════════════
  // CHECK-IN / CHECK-OUT
  // ═══════════════════════════════════════════════════════════════════════════

  /// Check-in by QR Code scan
  Future<bool> checkInByQrCode(String qrCode) async {
    try {
      // Find booking by QR code
      final querySnapshot = await DatabaseService.collection('bookings')
          .where('qrCode', isEqualTo: qrCode)
          .where('status', whereIn: ['confirmed', 'pending'])
          .limit(1)
          .get();
      
      if (querySnapshot.docs.isEmpty) {
        _error = 'No booking found for this QR code';
        _safeNotifyListeners();
        return false;
      }
      
      final bookingDoc = querySnapshot.docs.first;
      return await checkIn(bookingDoc.id, method: CheckInMethod.qrCode);
    } catch (e) {
      _error = 'Failed to check in by QR: $e';
      debugPrint('❌ Error checkInByQrCode: $e');
      _safeNotifyListeners();
      return false;
    }
  }
  
  /// Check-in by vehicle number plate (ANPR)
  Future<bool> checkInByNumberPlate(String numberPlate) async {
    try {
      // Normalize plate number
      final normalizedPlate = numberPlate.toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]'), '');
      
      // Find booking by number plate
      final querySnapshot = await DatabaseService.collection('bookings')
          .where('vehicleNumberPlate', isEqualTo: normalizedPlate)
          .where('status', whereIn: ['confirmed', 'pending'])
          .limit(1)
          .get();
      
      if (querySnapshot.docs.isEmpty) {
        _error = 'No booking found for plate: $numberPlate';
        _safeNotifyListeners();
        return false;
      }
      
      final bookingDoc = querySnapshot.docs.first;
      final booking = Booking.fromFirestore(bookingDoc);
      
      // Verify booking time (allow 15 min early check-in)
      final now = DateTime.now();
      final allowedStart = booking.startTime.subtract(const Duration(minutes: 15));
      
      if (now.isBefore(allowedStart)) {
        _error = 'Too early for check-in. Booking starts at ${booking.startTime}';
        _safeNotifyListeners();
        return false;
      }
      
      if (now.isAfter(booking.endTime)) {
        _error = 'Booking has expired';
        _safeNotifyListeners();
        return false;
      }
      
      return await checkIn(bookingDoc.id, method: CheckInMethod.numberPlate);
    } catch (e) {
      _error = 'Failed to check in by plate: $e';
      debugPrint('❌ Error checkInByNumberPlate: $e');
      _safeNotifyListeners();
      return false;
    }
  }
  
  /// Generic check-in method
  Future<bool> checkIn(String bookingId, {CheckInMethod method = CheckInMethod.manual}) async {
    try {
      await DatabaseService.collection('bookings').doc(bookingId).update({
        'status': BookingStatus.active.name,
        'checkedInAt': FieldValue.serverTimestamp(),
        'checkInMethod': method.name,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      
      // Update local booking
      final index = _bookings.indexWhere((b) => b.id == bookingId);
      if (index != -1) {
        _bookings[index] = _bookings[index].copyWith(
          status: BookingStatus.active,
          checkedInAt: DateTime.now(),
          checkInMethod: method,
          updatedAt: DateTime.now(),
        );
      }
      
      _safeNotifyListeners();
      return true;
    } catch (e) {
      _error = 'Failed to check in: $e';
      debugPrint('❌ Error checkIn: $e');
      _safeNotifyListeners();
      return false;
    }
  }
  
  /// Check-out by vehicle number plate (ANPR)
  Future<bool> checkOutByNumberPlate(String numberPlate) async {
    try {
      final normalizedPlate = numberPlate.toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]'), '');
      
      final querySnapshot = await DatabaseService.collection('bookings')
          .where('vehicleNumberPlate', isEqualTo: normalizedPlate)
          .where('status', isEqualTo: 'active')
          .limit(1)
          .get();
      
      if (querySnapshot.docs.isEmpty) {
        _error = 'No active booking found for plate: $numberPlate';
        _safeNotifyListeners();
        return false;
      }
      
      return await checkOut(querySnapshot.docs.first.id, method: CheckInMethod.numberPlate);
    } catch (e) {
      _error = 'Failed to check out by plate: $e';
      debugPrint('❌ Error checkOutByNumberPlate: $e');
      _safeNotifyListeners();
      return false;
    }
  }
  
  /// Check out using atomic transaction (releases slot)
  Future<bool> checkOut(String bookingId, {CheckInMethod method = CheckInMethod.manual}) async {
    try {
      // Get booking to calculate overtime if any
      final bookingDoc = await DatabaseService.collection('bookings').doc(bookingId).get();
      if (!bookingDoc.exists) {
        _error = 'Booking not found';
        return false;
      }
      
      final booking = Booking.fromFirestore(bookingDoc);
      final now = DateTime.now();
      
      // Calculate overtime fee
      double overtimeFee = 0;
      if (now.isAfter(booking.endTime)) {
        final overtimeMinutes = now.difference(booking.endTime).inMinutes;
        final overtimeHours = (overtimeMinutes / 60).ceil();
        overtimeFee = overtimeHours * booking.pricePerHour * 1.5; // 1.5x rate for overtime
      }
      
      final success = await DatabaseService.checkOutAtomic(bookingId);
      
      if (success) {
        // Update with checkout details
        await DatabaseService.collection('bookings').doc(bookingId).update({
          'checkOutMethod': method.name,
          'overtimeFee': overtimeFee > 0 ? overtimeFee : null,
        });
        
        // Update local booking
        final index = _bookings.indexWhere((b) => b.id == bookingId);
        if (index != -1) {
          _bookings[index] = _bookings[index].copyWith(
            status: BookingStatus.completed,
            checkedOutAt: now,
            checkOutMethod: method,
            overtimeFee: overtimeFee > 0 ? overtimeFee : null,
            updatedAt: now,
          );
        }
        _safeNotifyListeners();
      } else {
        _error = 'Failed to check out';
      }
      
      return success;
    } catch (e) {
      _error = 'Failed to check out: $e';
      debugPrint('❌ Error checkOut: $e');
      _safeNotifyListeners();
      return false;
    }
  }
  
  /// Auto-complete expired bookings (call periodically)
  Future<void> autoCompleteExpiredBookings(String userId) async {
    try {
      final now = DateTime.now();
      
      // Find active bookings that have passed their end time
      final expiredBookings = _bookings.where((b) => 
        b.userId == userId &&
        b.isActive &&
        now.isAfter(b.endTime) &&
        b.autoCompleteEnabled
      ).toList();
      
      for (final booking in expiredBookings) {
        await checkOut(booking.id, method: CheckInMethod.manual);
        debugPrint('Auto-completed booking: ${booking.id}');
      }
    } catch (e) {
      debugPrint('❌ Error autoCompleteExpiredBookings: $e');
    }
  }
  
  Future<bool> completeBooking(String bookingId) async {
    return await checkOut(bookingId);
  }
  
  // ═══════════════════════════════════════════════════════════════════════════
  // BOOKING QUERIES
  // ═══════════════════════════════════════════════════════════════════════════
  
  Future<Booking?> getBookingById(String bookingId) async {
    try {
      // Check local first
      final localBooking = _bookings.where((b) => b.id == bookingId).firstOrNull;
      if (localBooking != null) return localBooking;
      
      // Fetch from Firestore
      final doc = await DatabaseService.collection('bookings').doc(bookingId).get();
      if (doc.exists) {
        return Booking.fromFirestore(doc);
      }
      return null;
    } catch (e) {
      _error = 'Failed to get booking: $e';
      debugPrint('❌ Error getBookingById: $e');
      return null;
    }
  }
  
  /// Check if a time slot is available (capacity-aware)
  Future<bool> isTimeSlotAvailable(
    String spotId, 
    DateTime startTime, 
    DateTime endTime,
  ) async {
    try {
      // Get parking spot to know capacity
      final spotDoc = await DatabaseService.collection('parkingSpots').doc(spotId).get();
      if (!spotDoc.exists) return false;
      
      final spotData = spotDoc.data() as Map<String, dynamic>;
      final totalSpots = spotData['totalSpots'] as int? ?? 0;
      
      // Get overlapping bookings
      final querySnapshot = await DatabaseService.collection('bookings')
          .where('parkingSpotId', isEqualTo: spotId)
          .where('status', whereIn: ['confirmed', 'active', 'pending'])
          .get();
      
      int overlappingCount = 0;
      for (var doc in querySnapshot.docs) {
        final booking = Booking.fromFirestore(doc);
        if (_isTimeConflict(startTime, endTime, booking.startTime, booking.endTime)) {
          overlappingCount++;
        }
      }
      
      // Available if overlapping bookings < total spots
      return overlappingCount < totalSpots;
    } catch (e) {
      debugPrint('❌ Error checking availability: $e');
      return false;
    }
  }
  
  bool _isTimeConflict(DateTime start1, DateTime end1, DateTime start2, DateTime end2) {
    return start1.isBefore(end2) && end1.isAfter(start2);
  }
  
  // ═══════════════════════════════════════════════════════════════════════════
  // FEEDBACK
  // ═══════════════════════════════════════════════════════════════════════════
  
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
      
      _safeNotifyListeners();
      return true;
    } catch (e) {
      _error = 'Failed to add feedback: $e';
      debugPrint('❌ Error addFeedback: $e');
      _safeNotifyListeners();
      return false;
    }
  }
  
  // ═══════════════════════════════════════════════════════════════════════════
  // PDF GENERATION
  // ═══════════════════════════════════════════════════════════════════════════
  
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
      _safeNotifyListeners();
    }
  }

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
      _safeNotifyListeners();
    }
  }

  Future<void> cancelBookingWithReceipt(
    BuildContext context, 
    String bookingId, {
    String refundReason = 'Booking cancelled by user',
  }) async {
    try {
      final booking = _bookings.firstWhere((b) => b.id == bookingId);
      final refundAmount = _calculateRefundAmount(booking);
      
      final success = await cancelBooking(bookingId);
      
      if (success) {
        await PdfManager.handleBookingCancellation(
          context: context,
          booking: booking,
          refundAmount: refundAmount,
          refundReason: refundReason,
        );
      }
    } catch (e) {
      _error = 'Failed to cancel booking with receipt: $e';
      _safeNotifyListeners();
    }
  }

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
      _safeNotifyListeners();
    }
  }

  double _calculateRefundAmount(Booking booking) {
    final now = DateTime.now();
    final hoursUntilStart = booking.startTime.difference(now).inHours;
    
    if (hoursUntilStart > 24) {
      return booking.totalPrice * 0.9; // 90% refund
    } else if (hoursUntilStart > 2) {
      return booking.totalPrice * 0.5; // 50% refund
    } else {
      return 0.0; // No refund
    }
  }
  
  // ═══════════════════════════════════════════════════════════════════════════
  // HELPERS
  // ═══════════════════════════════════════════════════════════════════════════
  
  void _notifyListenersDebounced() {
    _notifyDebounce?.cancel();
    _notifyDebounce = Timer(const Duration(milliseconds: 50), () {
      _safeNotifyListeners();
    });
  }
  
  void clearError() {
    _error = null;
    _safeNotifyListeners();
  }

  void setCurrentBooking(Booking? booking) {
    _currentBooking = booking;
    _safeNotifyListeners();
  }
  
  // Backward compatibility
  Future<void> loadActiveBookings(String userId) async {
    await loadUserBookings(userId);
  }

  Future<void> loadBookingHistory(String userId) async {
    await loadUserBookings(userId);
  }
  
  Stream<List<Booking>> streamUserBookings(String userId) {
    return DatabaseService.collection('bookings')
        .where('userId', isEqualTo: userId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => Booking.fromFirestore(doc))
            .toList());
  }
}
