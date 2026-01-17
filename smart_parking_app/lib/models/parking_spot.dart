// lib/models/parking_spot.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geoflutterfire_plus/geoflutterfire_plus.dart';

enum ParkingSpotStatus { available, occupied, maintenance, reserved }

class ParkingSpot {
  final String id;
  final String name;
  final String description;
  final double latitude;
  final double longitude;
  final GeoFirePoint? geoPoint; // For GeoFlutterFire+ queries
  final int totalSpots;
  final int availableSpots;
  final double pricePerHour;
  final List<String> amenities;
  final List<String> vehicleTypes; // car, motorcycle, bicycle, etc.
  final String ownerId; // User ID of the parking spot owner/operator
  final ParkingSpotStatus status;
  final Map<String, dynamic> operatingHours; // {monday: {open: "08:00", close: "20:00"}, ...}
  final List<String> images; // URLs to parking spot images
  final double rating;
  final int reviewCount;
  final bool isVerified;
  final DateTime createdAt;
  final DateTime updatedAt;
  final Map<String, dynamic>? weatherData; // Current weather conditions
  final String address;
  final String? contactPhone;
  final Map<String, dynamic> accessibility; // wheelchair, elevator, etc.

  ParkingSpot({
    required this.id,
    required this.name,
    required this.description,
    required this.latitude,
    required this.longitude,
    this.geoPoint,
    required this.totalSpots,
    required this.availableSpots,
    required this.pricePerHour,
    this.amenities = const [],
    this.vehicleTypes = const ['car'],
    required this.ownerId,
    this.status = ParkingSpotStatus.available,
    this.operatingHours = const {},
    this.images = const [],
    this.rating = 0.0,
    this.reviewCount = 0,
    this.isVerified = false,
    required this.createdAt,
    required this.updatedAt,
    this.weatherData,
    required this.address,
    this.contactPhone,
    this.accessibility = const {},
  });

  // Factory constructor from Firestore document
  factory ParkingSpot.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    
    return ParkingSpot(
      id: doc.id,
      name: data['name'] ?? '',
      description: data['description'] ?? '',
      latitude: data['latitude']?.toDouble() ?? 0.0,
      longitude: data['longitude']?.toDouble() ?? 0.0,
      geoPoint: GeoFirePoint(GeoPoint(
        data['latitude']?.toDouble() ?? 0.0,
        data['longitude']?.toDouble() ?? 0.0,
      )),
      totalSpots: data['totalSpots'] ?? 1,
      availableSpots: data['availableSpots'] ?? 1,
      pricePerHour: data['pricePerHour']?.toDouble() ?? 0.0,
      amenities: _parseStringList(data['amenities']),
      vehicleTypes: _parseStringList(data['vehicleTypes']).isNotEmpty ? _parseStringList(data['vehicleTypes']) : ['car'],
      ownerId: data['ownerId'] ?? '',
      status: _parseStatus(data['status']),
      operatingHours: Map<String, dynamic>.from(data['operatingHours'] ?? {}),
      images: _parseStringList(data['images']),
      rating: data['rating']?.toDouble() ?? 0.0,
      reviewCount: data['reviewCount'] ?? 0,
      isVerified: data['isVerified'] ?? false,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      weatherData: data['weatherData'],
      address: data['address'] ?? '',
      contactPhone: data['contactPhone'],
      accessibility: Map<String, dynamic>.from(data['accessibility'] ?? {}),
    );
  }

  // Factory constructor from Map
  factory ParkingSpot.fromMap(Map<String, dynamic> data, String id) {
    
    return ParkingSpot(
      id: id,
      name: data['name'] ?? '',
      description: data['description'] ?? '',
      latitude: data['latitude']?.toDouble() ?? 0.0,
      longitude: data['longitude']?.toDouble() ?? 0.0,
      geoPoint: GeoFirePoint(GeoPoint(
        data['latitude']?.toDouble() ?? 0.0,
        data['longitude']?.toDouble() ?? 0.0,
      )),
      totalSpots: data['totalSpots'] ?? 1,
      availableSpots: data['availableSpots'] ?? 1,
      pricePerHour: data['pricePerHour']?.toDouble() ?? 0.0,
      amenities: _parseStringList(data['amenities']),
      vehicleTypes: _parseStringList(data['vehicleTypes']).isNotEmpty ? _parseStringList(data['vehicleTypes']) : ['car'],
      ownerId: data['ownerId'] ?? '',
      status: _parseStatus(data['status']),
      operatingHours: Map<String, dynamic>.from(data['operatingHours'] ?? {}),
      images: _parseStringList(data['images']),
      rating: data['rating']?.toDouble() ?? 0.0,
      reviewCount: data['reviewCount'] ?? 0,
      isVerified: data['isVerified'] ?? false,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      weatherData: data['weatherData'],
      address: data['address'] ?? '',
      contactPhone: data['contactPhone'],
      accessibility: Map<String, dynamic>.from(data['accessibility'] ?? {}),
    );
  }

  // Convert to Map for Firestore
  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'description': description,
      'latitude': latitude,
      'longitude': longitude,
      'position': geoPoint?.data, // GeoFlutterFire position data
      'totalSpots': totalSpots,
      'availableSpots': availableSpots,
      'pricePerHour': pricePerHour,
      'amenities': amenities,
      'vehicleTypes': vehicleTypes,
      'ownerId': ownerId,
      'status': status.name,
      'operatingHours': operatingHours,
      'images': images,
      'rating': rating,
      'reviewCount': reviewCount,
      'isVerified': isVerified,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
      'weatherData': weatherData,
      'address': address,
      'contactPhone': contactPhone,
      'accessibility': accessibility,
    };
  }

  // Helper method to parse status from string
  static ParkingSpotStatus _parseStatus(String? statusString) {
    switch (statusString) {
      case 'occupied':
        return ParkingSpotStatus.occupied;
      case 'maintenance':
        return ParkingSpotStatus.maintenance;
      case 'reserved':
        return ParkingSpotStatus.reserved;
      default:
        return ParkingSpotStatus.available;
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
  ParkingSpot copyWith({
    String? name,
    String? description,
    double? latitude,
    double? longitude,
    int? totalSpots,
    int? availableSpots,
    double? pricePerHour,
    List<String>? amenities,
    List<String>? vehicleTypes,
    String? ownerId,
    ParkingSpotStatus? status,
    Map<String, dynamic>? operatingHours,
    List<String>? images,
    double? rating,
    int? reviewCount,
    bool? isVerified,
    DateTime? updatedAt,
    Map<String, dynamic>? weatherData,
    String? address,
    String? contactPhone,
    Map<String, dynamic>? accessibility,
  }) {
    final newLat = latitude ?? this.latitude;
    final newLng = longitude ?? this.longitude;
    
    return ParkingSpot(
      id: id,
      name: name ?? this.name,
      description: description ?? this.description,
      latitude: newLat,
      longitude: newLng,
      geoPoint: GeoFirePoint(GeoPoint(newLat, newLng)),
      totalSpots: totalSpots ?? this.totalSpots,
      availableSpots: availableSpots ?? this.availableSpots,
      pricePerHour: pricePerHour ?? this.pricePerHour,
      amenities: amenities ?? this.amenities,
      vehicleTypes: vehicleTypes ?? this.vehicleTypes,
      ownerId: ownerId ?? this.ownerId,
      status: status ?? this.status,
      operatingHours: operatingHours ?? this.operatingHours,
      images: images ?? this.images,
      rating: rating ?? this.rating,
      reviewCount: reviewCount ?? this.reviewCount,
      isVerified: isVerified ?? this.isVerified,
      createdAt: createdAt,
      updatedAt: updatedAt ?? DateTime.now(),
      weatherData: weatherData ?? this.weatherData,
      address: address ?? this.address,
      contactPhone: contactPhone ?? this.contactPhone,
      accessibility: accessibility ?? this.accessibility,
    );
  }

  // Check if spot is available for booking
  bool isAvailableForBooking() {
    return status == ParkingSpotStatus.available && availableSpots > 0;
  }

  // Check if spot is open at specific time
  bool isOpenAt(DateTime dateTime) {
    final dayName = _getDayName(dateTime.weekday);
    final hours = operatingHours[dayName];
    
    if (hours == null) return true; // Assume 24/7 if no hours specified
    
    final openTime = _parseTime(hours['open']);
    final closeTime = _parseTime(hours['close']);
    final currentTime = ParkingTimeOfDay.fromDateTime(dateTime);
    
    return _isTimeBetween(currentTime, openTime, closeTime);
  }

  String _getDayName(int weekday) {
    const days = ['monday', 'tuesday', 'wednesday', 'thursday', 'friday', 'saturday', 'sunday'];
    return days[weekday - 1];
  }

  ParkingTimeOfDay _parseTime(String timeString) {
    final parts = timeString.split(':');
    return ParkingTimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1]));
  }

  bool _isTimeBetween(ParkingTimeOfDay current, ParkingTimeOfDay start, ParkingTimeOfDay end) {
    final currentMinutes = current.hour * 60 + current.minute;
    final startMinutes = start.hour * 60 + start.minute;
    final endMinutes = end.hour * 60 + end.minute;
    
    if (startMinutes <= endMinutes) {
      return currentMinutes >= startMinutes && currentMinutes <= endMinutes;
    } else {
      // Handle overnight hours
      return currentMinutes >= startMinutes || currentMinutes <= endMinutes;
    }
  }

  @override
  String toString() {
    return 'ParkingSpot{id: $id, name: $name, availableSpots: $availableSpots/$totalSpots, price: ₹${pricePerHour.toStringAsFixed(2)}/hr}';
  }
}

class ParkingTimeOfDay {
  final int hour;
  final int minute;

  const ParkingTimeOfDay({required this.hour, required this.minute});

  factory ParkingTimeOfDay.fromDateTime(DateTime dateTime) {
    return ParkingTimeOfDay(hour: dateTime.hour, minute: dateTime.minute);
  }
}