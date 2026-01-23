// lib/models/booking.dart
import 'package:cloud_firestore/cloud_firestore.dart';

enum BookingStatus { pending, confirmed, active, completed, cancelled, expired }

/// Check-in method used for the booking
enum CheckInMethod { qrCode, numberPlate, manual }

class Booking {
  final String id;
  final String userId;
  final String parkingSpotId;
  final String parkingSpotName;
  final String vehicleId;
  final String? vehicleNumberPlate; // Vehicle number plate for ANPR check-in/out
  final double latitude;
  final double longitude;
  final DateTime startTime;
  final DateTime endTime;
  final double pricePerHour;
  final double totalPrice;
  final double? cancellationFee;
  final double? overtimeFee; // Extra fee if user exceeds booked time
  final BookingStatus status;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? qrCode; // QR code for entry/exit
  final Map<String, dynamic> paymentInfo;
  final String? paymentMethod;
  final String? notes;
  final List<String> notifications; // Notification IDs sent for this booking
  final DateTime? checkedInAt;
  final DateTime? checkedOutAt;
  final CheckInMethod? checkInMethod; // How the user checked in
  final CheckInMethod? checkOutMethod; // How the user checked out
  final Map<String, dynamic>? feedback; // User rating and review
  final bool autoCompleteEnabled; // Auto-complete booking when time expires

  Booking({
    required this.id,
    required this.userId,
    required this.parkingSpotId,
    required this.parkingSpotName,
    required this.vehicleId,
    this.vehicleNumberPlate,
    required this.latitude,
    required this.longitude,
    required this.startTime,
    required this.endTime,
    required this.pricePerHour,
    required this.totalPrice,
    this.cancellationFee,
    this.overtimeFee,
    this.status = BookingStatus.pending,
    required this.createdAt,
    required this.updatedAt,
    this.qrCode,
    this.paymentInfo = const {},
    this.paymentMethod,
    this.notes,
    this.notifications = const [],
    this.checkedInAt,
    this.checkedOutAt,
    this.checkInMethod,
    this.checkOutMethod,
    this.feedback,
    this.autoCompleteEnabled = true,
  });

  // Factory constructor from Firestore document
  factory Booking.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    
    return Booking(
      id: doc.id,
      userId: data['userId'] ?? '',
      parkingSpotId: data['parkingSpotId'] ?? '',
      parkingSpotName: data['parkingSpotName'] ?? '',
      vehicleId: data['vehicleId'] ?? '',
      vehicleNumberPlate: data['vehicleNumberPlate'],
      latitude: data['latitude']?.toDouble() ?? 0.0,
      longitude: data['longitude']?.toDouble() ?? 0.0,
      startTime: (data['startTime'] as Timestamp?)?.toDate() ?? DateTime.now(),
      endTime: (data['endTime'] as Timestamp?)?.toDate() ?? DateTime.now(),
      pricePerHour: data['pricePerHour']?.toDouble() ?? 0.0,
      totalPrice: data['totalPrice']?.toDouble() ?? 0.0,
      cancellationFee: data['cancellationFee']?.toDouble(),
      overtimeFee: data['overtimeFee']?.toDouble(),
      status: _parseStatus(data['status']),
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      qrCode: data['qrCode'],
      paymentInfo: Map<String, dynamic>.from(data['paymentInfo'] ?? {}),
      paymentMethod: data['paymentMethod'],
      notes: data['notes'],
      notifications: _parseStringList(data['notifications']),
      checkedInAt: (data['checkedInAt'] as Timestamp?)?.toDate(),
      checkedOutAt: (data['checkedOutAt'] as Timestamp?)?.toDate(),
      checkInMethod: _parseCheckInMethod(data['checkInMethod']),
      checkOutMethod: _parseCheckInMethod(data['checkOutMethod']),
      feedback: data['feedback'] != null 
          ? Map<String, dynamic>.from(data['feedback']) 
          : null,
      autoCompleteEnabled: data['autoCompleteEnabled'] ?? true,
    );
  }

  // Factory constructor from Map
  factory Booking.fromMap(Map<String, dynamic> data, String id) {
    return Booking(
      id: id,
      userId: data['userId'] ?? '',
      parkingSpotId: data['parkingSpotId'] ?? '',
      parkingSpotName: data['parkingSpotName'] ?? '',
      vehicleId: data['vehicleId'] ?? '',
      vehicleNumberPlate: data['vehicleNumberPlate'],
      latitude: data['latitude']?.toDouble() ?? 0.0,
      longitude: data['longitude']?.toDouble() ?? 0.0,
      startTime: (data['startTime'] as Timestamp?)?.toDate() ?? DateTime.now(),
      endTime: (data['endTime'] as Timestamp?)?.toDate() ?? DateTime.now(),
      pricePerHour: data['pricePerHour']?.toDouble() ?? 0.0,
      totalPrice: data['totalPrice']?.toDouble() ?? 0.0,
      cancellationFee: data['cancellationFee']?.toDouble(),
      overtimeFee: data['overtimeFee']?.toDouble(),
      status: _parseStatus(data['status']),
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      qrCode: data['qrCode'],
      paymentInfo: Map<String, dynamic>.from(data['paymentInfo'] ?? {}),
      paymentMethod: data['paymentMethod'],
      notes: data['notes'],
      notifications: _parseStringList(data['notifications']),
      checkedInAt: (data['checkedInAt'] as Timestamp?)?.toDate(),
      checkedOutAt: (data['checkedOutAt'] as Timestamp?)?.toDate(),
      checkInMethod: _parseCheckInMethod(data['checkInMethod']),
      checkOutMethod: _parseCheckInMethod(data['checkOutMethod']),
      feedback: data['feedback'] != null 
          ? Map<String, dynamic>.from(data['feedback']) 
          : null,
      autoCompleteEnabled: data['autoCompleteEnabled'] ?? true,
    );
  }

  // Convert to Map for Firestore
  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'parkingSpotId': parkingSpotId,
      'parkingSpotName': parkingSpotName,
      'vehicleId': vehicleId,
      'vehicleNumberPlate': vehicleNumberPlate,
      'latitude': latitude,
      'longitude': longitude,
      'startTime': Timestamp.fromDate(startTime),
      'endTime': Timestamp.fromDate(endTime),
      'pricePerHour': pricePerHour,
      'totalPrice': totalPrice,
      'cancellationFee': cancellationFee,
      'overtimeFee': overtimeFee,
      'status': status.name,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
      'qrCode': qrCode,
      'paymentInfo': paymentInfo,
      'paymentMethod': paymentMethod,
      'notes': notes,
      'notifications': notifications,
      'checkedInAt': checkedInAt != null ? Timestamp.fromDate(checkedInAt!) : null,
      'checkedOutAt': checkedOutAt != null ? Timestamp.fromDate(checkedOutAt!) : null,
      'checkInMethod': checkInMethod?.name,
      'checkOutMethod': checkOutMethod?.name,
      'feedback': feedback,
      'autoCompleteEnabled': autoCompleteEnabled,
    };
  }

  // Helper method to parse status from string
  static BookingStatus _parseStatus(String? statusString) {
    switch (statusString) {
      case 'confirmed':
        return BookingStatus.confirmed;
      case 'active':
        return BookingStatus.active;
      case 'completed':
        return BookingStatus.completed;
      case 'cancelled':
        return BookingStatus.cancelled;
      case 'expired':
        return BookingStatus.expired;
      default:
        return BookingStatus.pending;
    }
  }
  
  // Helper method to parse check-in method from string
  static CheckInMethod? _parseCheckInMethod(String? methodString) {
    switch (methodString) {
      case 'qrCode':
        return CheckInMethod.qrCode;
      case 'numberPlate':
        return CheckInMethod.numberPlate;
      case 'manual':
        return CheckInMethod.manual;
      default:
        return null;
    }
  }

  // Helper method to safely parse List<String> from dynamic data
  static List<String> _parseStringList(dynamic data) {
    if (data == null) return [];
    if (data is List) {
      return data.map((e) => e?.toString() ?? '').where((s) => s.isNotEmpty).toList();
    }
    return [];
  }

  // Copy with method for updates
  Booking copyWith({
    String? userId,
    String? parkingSpotId,
    String? parkingSpotName,
    String? vehicleId,
    String? vehicleNumberPlate,
    double? latitude,
    double? longitude,
    DateTime? startTime,
    DateTime? endTime,
    double? pricePerHour,
    double? totalPrice,
    double? cancellationFee,
    double? overtimeFee,
    BookingStatus? status,
    DateTime? updatedAt,
    String? qrCode,
    Map<String, dynamic>? paymentInfo,
    String? paymentMethod,
    String? notes,
    List<String>? notifications,
    DateTime? checkedInAt,
    DateTime? checkedOutAt,
    CheckInMethod? checkInMethod,
    CheckInMethod? checkOutMethod,
    Map<String, dynamic>? feedback,
    bool? autoCompleteEnabled,
  }) {
    return Booking(
      id: id,
      userId: userId ?? this.userId,
      parkingSpotId: parkingSpotId ?? this.parkingSpotId,
      parkingSpotName: parkingSpotName ?? this.parkingSpotName,
      vehicleId: vehicleId ?? this.vehicleId,
      vehicleNumberPlate: vehicleNumberPlate ?? this.vehicleNumberPlate,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      pricePerHour: pricePerHour ?? this.pricePerHour,
      totalPrice: totalPrice ?? this.totalPrice,
      cancellationFee: cancellationFee ?? this.cancellationFee,
      overtimeFee: overtimeFee ?? this.overtimeFee,
      status: status ?? this.status,
      createdAt: createdAt,
      updatedAt: updatedAt ?? DateTime.now(),
      qrCode: qrCode ?? this.qrCode,
      paymentInfo: paymentInfo ?? this.paymentInfo,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      notes: notes ?? this.notes,
      notifications: notifications ?? this.notifications,
      checkedInAt: checkedInAt ?? this.checkedInAt,
      checkedOutAt: checkedOutAt ?? this.checkedOutAt,
      checkInMethod: checkInMethod ?? this.checkInMethod,
      checkOutMethod: checkOutMethod ?? this.checkOutMethod,
      feedback: feedback ?? this.feedback,
      autoCompleteEnabled: autoCompleteEnabled ?? this.autoCompleteEnabled,
    );
  }

  // Get duration in hours and minutes
  String get durationText {
    final durationMinutes = endTime.difference(startTime).inMinutes;
    final hours = durationMinutes ~/ 60;
    final minutes = durationMinutes % 60;
    
    if (hours > 0) {
      return '${hours}h ${minutes > 0 ? '${minutes}m' : ''}';
    } else {
      return '${minutes}m';
    }
  }
  
  // Get formatted date
  String get dateText {
    return '${startTime.day}/${startTime.month}/${startTime.year}';
  }
  
  // Get formatted time range
  String get timeText {
    return '${startTime.hour.toString().padLeft(2, '0')}:${startTime.minute.toString().padLeft(2, '0')} - '
           '${endTime.hour.toString().padLeft(2, '0')}:${endTime.minute.toString().padLeft(2, '0')}';
  }
  
  // Status check methods
  bool get isPending => status == BookingStatus.pending;
  bool get isConfirmed => status == BookingStatus.confirmed;
  bool get isActive => status == BookingStatus.active;
  bool get isCompleted => status == BookingStatus.completed;
  bool get isCancelled => status == BookingStatus.cancelled;
  bool get isExpired => status == BookingStatus.expired;
  
  // Check if booking can be cancelled
  bool canBeCancelled() {
    if (isCancelled || isCompleted || isExpired) return false;
    
    final now = DateTime.now();
    final timeDifference = startTime.difference(now).inMinutes;
    
    // Can cancel if more than 60 minutes before start time
    return timeDifference > 60;
  }
  
  // Check if booking can be modified
  bool canBeModified() {
    if (isCancelled || isCompleted || isExpired || isActive) return false;
    
    final now = DateTime.now();
    final timeDifference = startTime.difference(now).inHours;
    
    // Can modify if more than 2 hours before start time
    return timeDifference > 2;
  }
  
  // Calculate refund amount
  double getRefundAmount() {
    if (!canBeCancelled()) return 0.0;
    
    final now = DateTime.now();
    final hoursUntilStart = startTime.difference(now).inHours;
    
    if (hoursUntilStart > 24) {
      return totalPrice; // Full refund
    } else if (hoursUntilStart > 2) {
      return totalPrice * 0.8; // 80% refund
    } else {
      return totalPrice * 0.5; // 50% refund
    }
  }
  
  // Check if booking is happening now
  bool get isHappeningNow {
    final now = DateTime.now();
    return now.isAfter(startTime) && now.isBefore(endTime);
  }
  
  // Check if booking is upcoming
  bool get isUpcoming {
    final now = DateTime.now();
    return now.isBefore(startTime);
  }
  
  // Check if booking is past
  bool get isPast {
    final now = DateTime.now();
    return now.isAfter(endTime);
  }

  @override
  String toString() {
    return 'Booking{id: $id, parkingSpot: $parkingSpotName, status: $status, startTime: $startTime}';
  }
}