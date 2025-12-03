// setup_admin.js - Script to create admin user in Firebase
// Run this with: node setup_admin.js

const admin = require('firebase-admin');

// Initialize Firebase Admin SDK
// You'll need to download the service account key from Firebase Console
const serviceAccount = require('./smart-parking-service-account-key.json');

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
  databaseURL: 'https://smart-parking-kalyan-2024-default-rtdb.firebaseio.com'
});

const auth = admin.auth();
const db = admin.firestore();

async function createAdminUser() {
  try {
    console.log('🚀 Setting up admin user...');
    
    // Admin credentials from README
    const adminEmail = 'admin@smartparking.com';
    const adminPassword = 'admin123456';
    const adminDisplayName = 'Admin User';
    
    // Step 1: Create user in Firebase Auth
    console.log('📧 Creating Firebase Auth user...');
    let userRecord;
    
    try {
      // Try to create new user
      userRecord = await auth.createUser({
        email: adminEmail,
        password: adminPassword,
        displayName: adminDisplayName,
        emailVerified: true
      });
      console.log('✅ Firebase Auth user created:', userRecord.uid);
    } catch (error) {
      if (error.code === 'auth/email-already-exists') {
        // User already exists, get the existing user
        console.log('⚠️  User already exists, retrieving existing user...');
        userRecord = await auth.getUserByEmail(adminEmail);
        console.log('✅ Found existing user:', userRecord.uid);
        
        // Update password
        await auth.updateUser(userRecord.uid, {
          password: adminPassword,
          displayName: adminDisplayName,
          emailVerified: true
        });
        console.log('✅ Updated user password and details');
      } else {
        throw error;
      }
    }
    
    // Step 2: Create/Update user document in Firestore
    console.log('📄 Creating Firestore user document...');
    
    const userDoc = {
      id: userRecord.uid,
      email: adminEmail,
      displayName: adminDisplayName,
      role: 'admin',
      phoneNumber: '+1234567890', // Optional
      isEmailVerified: true,
      isPhoneVerified: false,
      createdAt: admin.firestore.Timestamp.now(),
      updatedAt: admin.firestore.Timestamp.now(),
      preferences: {
        theme: 'light',
        notifications: true
      }
    };
    
    await db.collection('users').doc(userRecord.uid).set(userDoc, { merge: true });
    console.log('✅ Firestore user document created/updated');
    
    // Step 3: Create some sample parking spots for testing
    console.log('🅿️  Creating sample parking spots...');
    await createSampleParkingSpots();
    
    console.log('\n🎉 Admin setup completed successfully!');
    console.log('\n📋 Admin Login Credentials:');
    console.log(`📧 Email: ${adminEmail}`);
    console.log(`🔑 Password: ${adminPassword}`);
    console.log(`👤 Display Name: ${adminDisplayName}`);
    console.log(`🆔 UID: ${userRecord.uid}`);
    console.log(`🏷️  Role: admin`);
    
    console.log('\n🔗 Next Steps:');
    console.log('1. Open your Smart Parking Admin app');
    console.log('2. Use the credentials above to log in');
    console.log('3. Verify admin dashboard functionality');
    
  } catch (error) {
    console.error('❌ Error setting up admin user:', error);
  }
}

async function createSampleParkingSpots() {
  const sampleSpots = [
    {
      id: 'downtown_plaza',
      name: 'Downtown Plaza Parking',
      description: 'Premium parking in the heart of the city',
      latitude: 17.331472,
      longitude: 78.5259811,
      position: {
        geohash: 'tdr1u8b',
        geopoint: new admin.firestore.GeoPoint(17.331472, 78.5259811)
      },
      totalSpots: 100,
      availableSpots: 75,
      pricePerHour: 15.0,
      ownerId: 'system',
      address: 'Downtown Plaza, Main Street',
      amenities: ['security', 'covered', 'ev_charging'],
      vehicleTypes: ['car', 'motorcycle'],
      status: 'available',
      isVerified: true,
      rating: 4.5,
      reviewCount: 128,
      operatingHours: {
        monday: { open: '06:00', close: '22:00' },
        tuesday: { open: '06:00', close: '22:00' },
        wednesday: { open: '06:00', close: '22:00' },
        thursday: { open: '06:00', close: '22:00' },
        friday: { open: '06:00', close: '23:00' },
        saturday: { open: '07:00', close: '23:00' },
        sunday: { open: '08:00', close: '21:00' }
      },
      contactPhone: '+91 9876543210',
      accessibility: {
        wheelchair: true,
        elevator: true,
        ramp: true
      },
      images: [],
      createdAt: admin.firestore.Timestamp.now(),
      updatedAt: admin.firestore.Timestamp.now()
    },
    {
      id: 'tech_hub_parking',
      name: 'Tech Hub Business Center',
      description: 'Modern parking facility for tech professionals',
      latitude: 17.332472,
      longitude: 78.5269811,
      position: {
        geohash: 'tdr1u8c',
        geopoint: new admin.firestore.GeoPoint(17.332472, 78.5269811)
      },
      totalSpots: 150,
      availableSpots: 120,
      pricePerHour: 12.0,
      ownerId: 'system',
      address: 'Tech Hub, HITEC City',
      amenities: ['security', 'wifi', 'restroom'],
      vehicleTypes: ['car', 'motorcycle', 'bicycle'],
      status: 'available',
      isVerified: true,
      rating: 4.3,
      reviewCount: 89,
      operatingHours: {
        monday: { open: '05:00', close: '23:00' },
        tuesday: { open: '05:00', close: '23:00' },
        wednesday: { open: '05:00', close: '23:00' },
        thursday: { open: '05:00', close: '23:00' },
        friday: { open: '05:00', close: '23:00' },
        saturday: { open: '06:00', close: '22:00' },
        sunday: { open: '07:00', close: '21:00' }
      },
      contactPhone: '+91 9876543211',
      accessibility: {
        wheelchair: true,
        elevator: false,
        ramp: true
      },
      images: [],
      createdAt: admin.firestore.Timestamp.now(),
      updatedAt: admin.firestore.Timestamp.now()
    },
    {
      id: 'mall_parking',
      name: 'City Mall Parking',
      description: 'Convenient shopping mall parking',
      latitude: 17.330472,
      longitude: 78.5249811,
      position: {
        geohash: 'tdr1u89',
        geopoint: new admin.firestore.GeoPoint(17.330472, 78.5249811)
      },
      totalSpots: 200,
      availableSpots: 180,
      pricePerHour: 8.0,
      ownerId: 'system',
      address: 'City Mall, Shopping District',
      amenities: ['covered', 'restroom', 'food_court'],
      vehicleTypes: ['car', 'motorcycle'],
      status: 'available',
      isVerified: true,
      rating: 4.1,
      reviewCount: 156,
      operatingHours: {
        monday: { open: '09:00', close: '22:00' },
        tuesday: { open: '09:00', close: '22:00' },
        wednesday: { open: '09:00', close: '22:00' },
        thursday: { open: '09:00', close: '22:00' },
        friday: { open: '09:00', close: '23:00' },
        saturday: { open: '09:00', close: '23:00' },
        sunday: { open: '10:00', close: '22:00' }
      },
      contactPhone: '+91 9876543212',
      accessibility: {
        wheelchair: true,
        elevator: true,
        ramp: true
      },
      images: [],
      createdAt: admin.firestore.Timestamp.now(),
      updatedAt: admin.firestore.Timestamp.now()
    }
  ];

  for (const spot of sampleSpots) {
    await db.collection('parking_spots').doc(spot.id).set(spot, { merge: true });
    console.log(`✅ Created parking spot: ${spot.name}`);
  }
}

// Run the setup
createAdminUser()
  .then(() => {
    console.log('\n✨ Setup completed successfully!');
    process.exit(0);
  })
  .catch((error) => {
    console.error('\n💥 Setup failed:', error);
    process.exit(1);
  });
