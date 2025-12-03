// lib/services/admin_setup_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:geoflutterfire_plus/geoflutterfire_plus.dart';
import '../core/database/database_service.dart';
import '../models/parking_spot.dart';

class AdminSetupService {
  static const String adminEmail = 'admin@smartparking.com';
  static const String adminPassword = 'admin123456';
  static const String adminDisplayName = 'Admin User';

  /// Creates admin user and sets up initial data
  static Future<Map<String, dynamic>> setupAdmin() async {
    try {
      print('🧩 Phase1Audit: 🚀 Starting admin setup...');
      
      // Step 1: Create or verify admin user
      final adminUser = await _createOrGetAdminUser();
      
      // Step 2: Create admin profile in Firestore
      await _createAdminProfile(adminUser.uid);
      
      // Step 3: Seed sample parking slots once
      final alreadySeeded = await hasParkingSpots();
      if (!alreadySeeded) {
        await _createSampleParkingSpots();
      } else {
        print('🧩 Phase1Audit: Skipping seeding, parking slots already exist');
      }
      
      print('🧩 Phase1Audit: ✅ Admin setup completed successfully!');
      
      return {
        'success': true,
        'message': 'Admin setup completed successfully',
        'adminUid': adminUser.uid,
        'adminEmail': adminEmail,
        'parkingSpotsCreated': 3,
      };
      
    } catch (e) {
      print('🧩 Phase1Audit: ❌ Admin setup failed: $e');
      return {
        'success': false,
        'message': 'Admin setup failed: $e',
        'error': e.toString(),
      };
    }
  }

  /// Creates admin user in Firebase Auth or returns existing user
  static Future<User> _createOrGetAdminUser() async {
    try {
      // Try to sign in with existing credentials
      final credential = await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: adminEmail,
        password: adminPassword,
      );
      
      if (credential.user != null) {
        print('🧩 Phase1Audit: ✅ Admin user already exists and authenticated');
        return credential.user!;
      }
    } catch (e) {
      print('🧩 Phase1Audit: ℹ️ Admin user does not exist or wrong credentials, will create new one');
    }

    // Create new admin user
    try {
      final credential = await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: adminEmail,
        password: adminPassword,
      );
      
      if (credential.user != null) {
        // Update profile
        await credential.user!.updateDisplayName(adminDisplayName);
        print('🧩 Phase1Audit: ✅ Admin user created successfully');
        return credential.user!;
      } else {
        throw Exception('Failed to create admin user');
      }
    } catch (e) {
      throw Exception('Failed to create admin user: $e');
    }
  }

  /// Creates admin profile in Firestore users collection
  static Future<void> _createAdminProfile(String uid) async {
    try {
      final userDoc = {
        'id': uid,
        'email': adminEmail,
        'displayName': adminDisplayName,
        'role': 'admin',
        'phoneNumber': '+1234567890',
        'isEmailVerified': true,
        'isPhoneVerified': false,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        'preferences': {
          'theme': 'light',
          'notifications': true,
        },
        'vehicleIds': [],
        'bookingIds': [],
        'location': null,
      };

      await DatabaseService.collection('users').doc(uid).set(userDoc);
      print('🧩 Phase1Audit: ✅ Admin profile created in Firestore');
    } catch (e) {
      throw Exception('Failed to create admin profile: $e');
    }
  }

  /// Creates sample parking spots for testing
  static Future<void> _createSampleParkingSpots() async {
    try {
      final sampleSpots = [
        _createDowntownPlaza(),
        _createTechHubParking(),
        _createMallParking(),
      ];

      for (int i = 0; i < sampleSpots.length; i++) {
        final spot = sampleSpots[i];
        await DatabaseService.collection('parking_slots').doc(spot.id).set(spot.toMap());
        print('🧩 Phase1Audit: ✅ Created parking slot: ${spot.name}');
      }

      print('🧩 Phase1Audit: ✅ All sample parking slots created');
    } catch (e) {
      throw Exception('Failed to create sample parking spots: $e');
    }
  }

  static ParkingSpot _createDowntownPlaza() {
    return ParkingSpot(
      id: 'downtown_plaza',
      name: 'Downtown Plaza Parking',
      description: 'Premium parking in the heart of the city',
      latitude: 17.331472,
      longitude: 78.5259811,
      geoPoint: GeoFirePoint(GeoPoint(17.331472, 78.5259811)),
      totalSpots: 100,
      availableSpots: 75,
      pricePerHour: 15.0,
      ownerId: 'system',
      address: 'Downtown Plaza, Main Street',
      amenities: ['security', 'covered', 'ev_charging'],
      vehicleTypes: ['car', 'motorcycle'],
      status: ParkingSpotStatus.available,
      isVerified: true,
      rating: 4.5,
      reviewCount: 128,
      operatingHours: {
        'monday': {'open': '06:00', 'close': '22:00'},
        'tuesday': {'open': '06:00', 'close': '22:00'},
        'wednesday': {'open': '06:00', 'close': '22:00'},
        'thursday': {'open': '06:00', 'close': '22:00'},
        'friday': {'open': '06:00', 'close': '23:00'},
        'saturday': {'open': '07:00', 'close': '23:00'},
        'sunday': {'open': '08:00', 'close': '21:00'},
      },
      contactPhone: '+91 9876543210',
      accessibility: {
        'wheelchair': true,
        'elevator': true,
        'ramp': true,
      },
      images: [],
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
  }

  static ParkingSpot _createTechHubParking() {
    return ParkingSpot(
      id: 'tech_hub_parking',
      name: 'Tech Hub Business Center',
      description: 'Modern parking facility for tech professionals',
      latitude: 17.332472,
      longitude: 78.5269811,
      geoPoint: GeoFirePoint(GeoPoint(17.332472, 78.5269811)),
      totalSpots: 150,
      availableSpots: 120,
      pricePerHour: 12.0,
      ownerId: 'system',
      address: 'Tech Hub, HITEC City',
      amenities: ['security', 'wifi', 'restroom'],
      vehicleTypes: ['car', 'motorcycle', 'bicycle'],
      status: ParkingSpotStatus.available,
      isVerified: true,
      rating: 4.3,
      reviewCount: 89,
      operatingHours: {
        'monday': {'open': '05:00', 'close': '23:00'},
        'tuesday': {'open': '05:00', 'close': '23:00'},
        'wednesday': {'open': '05:00', 'close': '23:00'},
        'thursday': {'open': '05:00', 'close': '23:00'},
        'friday': {'open': '05:00', 'close': '23:00'},
        'saturday': {'open': '06:00', 'close': '22:00'},
        'sunday': {'open': '07:00', 'close': '21:00'},
      },
      contactPhone: '+91 9876543211',
      accessibility: {
        'wheelchair': true,
        'elevator': false,
        'ramp': true,
      },
      images: [],
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
  }

  static ParkingSpot _createMallParking() {
    return ParkingSpot(
      id: 'mall_parking',
      name: 'City Mall Parking',
      description: 'Convenient shopping mall parking',
      latitude: 17.330472,
      longitude: 78.5249811,
      geoPoint: GeoFirePoint(GeoPoint(17.330472, 78.5249811)),
      totalSpots: 200,
      availableSpots: 180,
      pricePerHour: 8.0,
      ownerId: 'system',
      address: 'City Mall, Shopping District',
      amenities: ['covered', 'restroom', 'food_court'],
      vehicleTypes: ['car', 'motorcycle'],
      status: ParkingSpotStatus.available,
      isVerified: true,
      rating: 4.1,
      reviewCount: 156,
      operatingHours: {
        'monday': {'open': '09:00', 'close': '22:00'},
        'tuesday': {'open': '09:00', 'close': '22:00'},
        'wednesday': {'open': '09:00', 'close': '22:00'},
        'thursday': {'open': '09:00', 'close': '22:00'},
        'friday': {'open': '09:00', 'close': '23:00'},
        'saturday': {'open': '09:00', 'close': '23:00'},
        'sunday': {'open': '10:00', 'close': '22:00'},
      },
      contactPhone: '+91 9876543212',
      accessibility: {
        'wheelchair': true,
        'elevator': true,
        'ramp': true,
      },
      images: [],
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
  }

  /// Checks if admin user exists and has proper role
  static Future<bool> isAdminSetupComplete() async {
    try {
      // Check if current user is admin
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) return false;

      // Check if user has admin role in Firestore
      final userDoc = await DatabaseService.collection('users').doc(currentUser.uid).get();
      if (!userDoc.exists) return false;

      final userData = userDoc.data() as Map<String, dynamic>?;
      final role = userData?['role'] as String?;
      
      return role == 'admin';
    } catch (e) {
      print('Error checking admin setup: $e');
      return false;
    }
  }

  /// Checks if parking spots exist in database
  static Future<bool> hasParkingSpots() async {
    try {
      final query = await DatabaseService.collection('parking_slots').limit(1).get();
      return query.docs.isNotEmpty;
    } catch (e) {
      print('🧩 Phase1Audit: Error checking parking slots: $e');
      return false;
    }
  }
}
