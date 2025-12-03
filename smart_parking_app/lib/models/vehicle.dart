// lib/models/vehicle.dart
import 'package:cloud_firestore/cloud_firestore.dart';

enum VehicleType {
  car,
  motorcycle,
  bicycle,
  electricCar,
  truck,
  van,
  suv
}

class Vehicle {
  final String id;
  final String userId;
  final String licensePlate; 
  final String make;
  final String model;
  final int year;
  final VehicleType type;
  final String color;
  final bool isElectric;
  final bool isDefault;
  final String? imageUrl;
  final Map<String, dynamic> specifications; // length, width, height in meters
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool isVerified; // Verified by admin or document upload
  
  Vehicle({
    required this.id,
    required this.userId,
    required this.licensePlate,
    required this.make,
    required this.model,
    required this.year,
    required this.type,
    required this.color,
    this.isElectric = false,
    this.isDefault = false,
    this.imageUrl,
    this.specifications = const {},
    required this.createdAt,
    required this.updatedAt,
    this.isVerified = false,
  });
  
  // Factory constructor from Firestore document
  factory Vehicle.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    
    return Vehicle(
      id: doc.id,
      userId: data['userId'] ?? '',
      licensePlate: data['licensePlate'] ?? '',
      make: data['make'] ?? '',
      model: data['model'] ?? '',
      year: data['year'] ?? DateTime.now().year,
      type: _parseVehicleType(data['type']),
      color: data['color'] ?? '',
      isElectric: data['isElectric'] ?? false,
      isDefault: data['isDefault'] ?? false,
      imageUrl: data['imageUrl'],
      specifications: Map<String, dynamic>.from(data['specifications'] ?? {}),
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      isVerified: data['isVerified'] ?? false,
    );
  }

  // Factory constructor from Map
  factory Vehicle.fromMap(Map<String, dynamic> data, String id) {
    return Vehicle(
      id: id,
      userId: data['userId'] ?? '',
      licensePlate: data['licensePlate'] ?? '',
      make: data['make'] ?? '',
      model: data['model'] ?? '',
      year: data['year'] ?? DateTime.now().year,
      type: _parseVehicleType(data['type']),
      color: data['color'] ?? '',
      isElectric: data['isElectric'] ?? false,
      isDefault: data['isDefault'] ?? false,
      imageUrl: data['imageUrl'],
      specifications: Map<String, dynamic>.from(data['specifications'] ?? {}),
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      isVerified: data['isVerified'] ?? false,
    );
  }
  
  // Convert to Map for Firestore
  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'licensePlate': licensePlate,
      'make': make,
      'model': model,
      'year': year,
      'type': type.name,
      'color': color,
      'isElectric': isElectric,
      'isDefault': isDefault,
      'imageUrl': imageUrl,
      'specifications': specifications,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
      'isVerified': isVerified,
    };
  }

  // Helper method to parse vehicle type from string
  static VehicleType _parseVehicleType(String? typeString) {
    switch (typeString) {
      case 'motorcycle':
        return VehicleType.motorcycle;
      case 'bicycle':
        return VehicleType.bicycle;
      case 'electricCar':
        return VehicleType.electricCar;
      case 'truck':
        return VehicleType.truck;
      case 'van':
        return VehicleType.van;
      case 'suv':
        return VehicleType.suv;
      default:
        return VehicleType.car;
    }
  }
  
  // Create a copy with updated fields
  Vehicle copyWith({
    String? userId,
    String? licensePlate,
    String? make,
    String? model,
    int? year,
    VehicleType? type,
    String? color,
    bool? isElectric,
    bool? isDefault,
    String? imageUrl,
    Map<String, dynamic>? specifications,
    DateTime? updatedAt,
    bool? isVerified,
  }) {
    return Vehicle(
      id: id,
      userId: userId ?? this.userId,
      licensePlate: licensePlate ?? this.licensePlate,
      make: make ?? this.make,
      model: model ?? this.model,
      year: year ?? this.year,
      type: type ?? this.type,
      color: color ?? this.color,
      isElectric: isElectric ?? this.isElectric,
      isDefault: isDefault ?? this.isDefault,
      imageUrl: imageUrl ?? this.imageUrl,
      specifications: specifications ?? this.specifications,
      createdAt: createdAt,
      updatedAt: updatedAt ?? DateTime.now(),
      isVerified: isVerified ?? this.isVerified,
    );
  }
  
  // Formatted display of vehicle info
  String get displayName {
    return '$color $year $make $model';
  }

  // Short display name with license plate
  String get shortDisplayName {
    return '${licensePlate.toUpperCase()} - $make $model';
  }

  // Get vehicle type display name
  String get typeDisplayName {
    switch (type) {
      case VehicleType.car:
        return 'Car';
      case VehicleType.motorcycle:
        return 'Motorcycle';
      case VehicleType.bicycle:
        return 'Bicycle';
      case VehicleType.electricCar:
        return 'Electric Car';
      case VehicleType.truck:
        return 'Truck';
      case VehicleType.van:
        return 'Van';
      case VehicleType.suv:
        return 'SUV';
    }
  }

  // Check if vehicle is compatible with parking spot
  bool isCompatibleWith(List<String> supportedVehicleTypes) {
    return supportedVehicleTypes.contains(type.name) || 
           supportedVehicleTypes.contains('all');
  }

  // Get estimated parking space needed (in square meters)
  double get estimatedParkingSpace {
    switch (type) {
      case VehicleType.bicycle:
        return 2.0;
      case VehicleType.motorcycle:
        return 4.0;
      case VehicleType.car:
      case VehicleType.electricCar:
        return 12.0;
      case VehicleType.van:
        return 15.0;
      case VehicleType.suv:
        return 14.0;
      case VehicleType.truck:
        return 25.0;
    }
  }

  @override
  String toString() {
    return 'Vehicle{id: $id, licensePlate: $licensePlate, displayName: $displayName}';
  }
}