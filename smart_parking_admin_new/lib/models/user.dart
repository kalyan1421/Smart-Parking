// lib/models/user.dart
import 'package:cloud_firestore/cloud_firestore.dart';

enum UserRole { user, parkingOperator, admin }

class User {
  final String id;
  final String email;
  final String? phoneNumber;
  final String displayName;
  final String? photoURL;
  final UserRole role;
  final List<String> vehicleIds;
  final List<String> bookingIds;
  final Map<String, dynamic> preferences;
  final bool isEmailVerified;
  final bool isPhoneVerified;
  final DateTime createdAt;
  final DateTime updatedAt;
  final Map<String, double>? location; // {lat: 0.0, lng: 0.0}

  User({
    required this.id,
    required this.email,
    this.phoneNumber,
    required this.displayName,
    this.photoURL,
    this.role = UserRole.user,
    this.vehicleIds = const [],
    this.bookingIds = const [],
    this.preferences = const {},
    this.isEmailVerified = false,
    this.isPhoneVerified = false,
    required this.createdAt,
    required this.updatedAt,
    this.location,
  });

  // Factory constructor to create User from Firestore document
  factory User.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    
    return User(
      id: doc.id,
      email: data['email'] ?? '',
      phoneNumber: data['phoneNumber'],
      displayName: data['displayName'] ?? '',
      photoURL: data['photoURL'],
      role: _parseRole(data['role']),
      vehicleIds: _parseStringList(data['vehicleIds']),
      bookingIds: _parseStringList(data['bookingIds']),
      preferences: _parseStringDynamicMap(data['preferences']),
      isEmailVerified: data['isEmailVerified'] ?? false,
      isPhoneVerified: data['isPhoneVerified'] ?? false,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      location: _parseLocationMap(data['location']),
    );
  }

  // Factory constructor from Map
  factory User.fromMap(Map<String, dynamic> data, String id) {
    return User(
      id: id,
      email: data['email'] ?? '',
      phoneNumber: data['phoneNumber'],
      displayName: data['displayName'] ?? '',
      photoURL: data['photoURL'],
      role: _parseRole(data['role']),
      vehicleIds: _parseStringList(data['vehicleIds']),
      bookingIds: _parseStringList(data['bookingIds']),
      preferences: _parseStringDynamicMap(data['preferences']),
      isEmailVerified: data['isEmailVerified'] ?? false,
      isPhoneVerified: data['isPhoneVerified'] ?? false,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      location: _parseLocationMap(data['location']),
    );
  }

  // Convert User to Map for Firestore
  Map<String, dynamic> toMap() {
    return {
      'email': email,
      'phoneNumber': phoneNumber,
      'displayName': displayName,
      'photoURL': photoURL,
      'role': role.name,
      'vehicleIds': vehicleIds,
      'bookingIds': bookingIds,
      'preferences': preferences,
      'isEmailVerified': isEmailVerified,
      'isPhoneVerified': isPhoneVerified,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
      'location': location,
    };
  }

  // Helper method to parse role from string
  static UserRole _parseRole(String? roleString) {
    switch (roleString) {
      case 'parkingOperator':
        return UserRole.parkingOperator;
      case 'admin':
        return UserRole.admin;
      default:
        return UserRole.user;
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

  // Helper method to safely parse Map<String, dynamic> from dynamic data
  static Map<String, dynamic> _parseStringDynamicMap(dynamic data) {
    if (data == null) return {};
    if (data is Map) {
      return Map<String, dynamic>.from(data);
    }
    return {};
  }

  // Helper method to safely parse location map
  static Map<String, double>? _parseLocationMap(dynamic data) {
    if (data == null) return null;
    if (data is Map) {
      try {
        return data.map((key, value) => MapEntry(
          key.toString(),
          (value is num) ? value.toDouble() : 0.0,
        ));
      } catch (e) {
        return null;
      }
    }
    return null;
  }

  // Copy with method for updates
  User copyWith({
    String? email,
    String? phoneNumber,
    String? displayName,
    String? photoURL,
    UserRole? role,
    List<String>? vehicleIds,
    List<String>? bookingIds,
    Map<String, dynamic>? preferences,
    bool? isEmailVerified,
    bool? isPhoneVerified,
    DateTime? updatedAt,
    Map<String, double>? location,
  }) {
    return User(
      id: id,
      email: email ?? this.email,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      displayName: displayName ?? this.displayName,
      photoURL: photoURL ?? this.photoURL,
      role: role ?? this.role,
      vehicleIds: vehicleIds ?? this.vehicleIds,
      bookingIds: bookingIds ?? this.bookingIds,
      preferences: preferences ?? this.preferences,
      isEmailVerified: isEmailVerified ?? this.isEmailVerified,
      isPhoneVerified: isPhoneVerified ?? this.isPhoneVerified,
      createdAt: createdAt,
      updatedAt: updatedAt ?? DateTime.now(),
      location: location ?? this.location,
    );
  }

  // Check if user has specific role
  bool hasRole(UserRole requiredRole) {
    switch (requiredRole) {
      case UserRole.admin:
        return role == UserRole.admin;
      case UserRole.parkingOperator:
        return role == UserRole.parkingOperator || role == UserRole.admin;
      case UserRole.user:
        return true; // All users have user role
    }
  }

  @override
  String toString() {
    return 'User{id: $id, email: $email, displayName: $displayName, role: $role}';
  }
}
