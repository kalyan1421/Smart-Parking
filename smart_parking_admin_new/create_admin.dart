// create_admin.dart - Quick admin setup script
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:smart_parking_admin_new/firebase_options.dart';

void main() async {
  // Initialize Firebase
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  print('🔥 Firebase initialized');

  final auth = FirebaseAuth.instance;
  final firestore = FirebaseFirestore.instance;

  const adminEmail = 'admin@smartparking.com';
  const adminPassword = 'admin123456';
  const adminName = 'Admin User';

  try {
    print('📧 Creating admin user...');
    
    // Try to create admin user
    UserCredential? credential;
    try {
      credential = await auth.createUserWithEmailAndPassword(
        email: adminEmail,
        password: adminPassword,
      );
      print('✅ Admin user created in Firebase Auth');
    } catch (e) {
      if (e.toString().contains('email-already-in-use')) {
        print('ℹ️ Admin user already exists, signing in...');
        credential = await auth.signInWithEmailAndPassword(
          email: adminEmail,
          password: adminPassword,
        );
      } else {
        throw e;
      }
    }

    if (credential?.user != null) {
      final user = credential!.user!;
      
      // Update display name
      await user.updateDisplayName(adminName);
      print('✅ Display name updated');

      // Create/update user document in Firestore
      final userDoc = {
        'id': user.uid,
        'email': adminEmail,
        'displayName': adminName,
        'role': 'admin',
        'phoneNumber': '+1234567890',
        'isEmailVerified': user.emailVerified,
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

      await firestore.collection('users').doc(user.uid).set(userDoc);
      print('✅ Admin document created in Firestore');

      // Create a sample parking spot for testing
      await createSampleParkingSpot(firestore, user.uid);

      print('\n🎉 Admin setup completed successfully!');
      print('\n📋 Admin Login Credentials:');
      print('📧 Email: $adminEmail');
      print('🔑 Password: $adminPassword');
      print('👤 Name: $adminName');
      print('🆔 UID: ${user.uid}');
      print('🏷️ Role: admin');
      
      print('\n✅ You can now login to the admin app!');
    }
  } catch (e) {
    print('❌ Error creating admin: $e');
  }
}

Future<void> createSampleParkingSpot(FirebaseFirestore firestore, String adminUid) async {
  try {
    print('🅿️ Creating sample parking spot...');
    
    final parkingSpot = {
      'id': 'sample_downtown_parking',
      'name': 'Downtown Free Parking',
      'description': 'Sample free parking spot created by admin\n\n🎉 FREE PARKING AVAILABLE!',
      'latitude': 17.331472,
      'longitude': 78.5259811,
      'position': {
        'geohash': 'tdr1u8b',
        'geopoint': GeoPoint(17.331472, 78.5259811),
      },
      'totalSpots': 20,
      'availableSpots': 20,
      'pricePerHour': 0.0,
      'ownerId': adminUid,
      'address': 'Downtown Area, Sample Street',
      'amenities': ['Free Parking', 'Security', 'Lighting'],
      'vehicleTypes': ['car', 'motorcycle'],
      'status': 'available',
      'isVerified': true,
      'rating': 4.5,
      'reviewCount': 10,
      'operatingHours': {
        'monday': {'open': '00:00', 'close': '23:59'},
        'tuesday': {'open': '00:00', 'close': '23:59'},
        'wednesday': {'open': '00:00', 'close': '23:59'},
        'thursday': {'open': '00:00', 'close': '23:59'},
        'friday': {'open': '00:00', 'close': '23:59'},
        'saturday': {'open': '00:00', 'close': '23:59'},
        'sunday': {'open': '00:00', 'close': '23:59'},
      },
      'contactPhone': '+91 9876543210',
      'accessibility': {
        'wheelchair': true,
        'elevator': false,
        'ramp': true,
      },
      'images': [],
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
      'weatherData': null,
    };

    await firestore.collection('parking_spots').doc('sample_downtown_parking').set(parkingSpot);
    print('✅ Sample parking spot created');
  } catch (e) {
    print('⚠️ Error creating sample parking spot: $e');
  }
}
