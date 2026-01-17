const admin = require('firebase-admin');
const geohash = require('ngeohash');

// --- CONFIGURATION ---
// ⚠️ IMPORTANT: Your Firestore uses 'parkingSpots' (camelCase)
const COLLECTION_NAME = 'parkingSpots'; 
const ID_PREFIX = 'QP'; // Quick Park prefix
const ID_START = 1; // Starting number

var serviceAccount = require("./serviceAccountKey.json");

if (!admin.apps.length) {
  admin.initializeApp({
    credential: admin.credential.cert(serviceAccount)
  });
}

const db = admin.firestore();

// --- DATA SETS ---
const AMENITIES_OPTIONS = [
  'Security Camera', 'Lighting', 'Covered', 'EV Charging', 
  '24/7 Access', 'Wheelchair Accessible', 'Restroom Nearby', 
  'Car Wash', 'Valet Service', 'Security Guard'
];

const VEHICLE_TYPES = ['car', 'motorcycle', 'suv'];

const DESCRIPTIONS = [
  "Safe and secure parking spot near the main market.",
  "Covered parking with 24/7 security guard.",
  "Easy access to metro station and bus stops.",
  "Spacious slots suitable for SUVs and sedans.",
  "Automated entry system with EV charging capabilities."
];

// --- ZONES (Hyderabad, Chennai, AP) ---
const ZONES = [
  // Hyderabad
  { city: 'Hyderabad', area: 'HITEC City', lat: 17.4472, lng: 78.3765, count: 35 },
  { city: 'Hyderabad', area: 'Gachibowli', lat: 17.4401, lng: 78.3489, count: 35 },
  { city: 'Hyderabad', area: 'Jubilee Hills', lat: 17.4311, lng: 78.4112, count: 20 },
  { city: 'Hyderabad', area: 'Banjara Hills', lat: 17.4138, lng: 78.4398, count: 20 },
  { city: 'Hyderabad', area: 'Secunderabad', lat: 17.4399, lng: 78.4983, count: 25 },
  { city: 'Hyderabad', area: 'Kukatpally', lat: 17.4917, lng: 78.3920, count: 25 },
  
  // Chennai
  { city: 'Chennai', area: 'T Nagar', lat: 13.0427, lng: 80.2375, count: 30 },
  { city: 'Chennai', area: 'Anna Nagar', lat: 13.0850, lng: 80.2065, count: 25 },
  { city: 'Chennai', area: 'Velachery', lat: 12.9760, lng: 80.2212, count: 25 },
  { city: 'Chennai', area: 'OMR', lat: 12.9654, lng: 80.2461, count: 30 },
  
  // Andhra Pradesh
  { city: 'Vijayawada', area: 'Benz Circle', lat: 16.4997, lng: 80.6561, count: 25 },
  { city: 'Vijayawada', area: 'MG Road', lat: 16.5062, lng: 80.6480, count: 20 },
  { city: 'Visakhapatnam', area: 'Dwaraka Nagar', lat: 17.7298, lng: 83.3088, count: 25 },
  { city: 'Visakhapatnam', area: 'Beach Road', lat: 17.7100, lng: 83.3200, count: 20 },
  { city: 'Tirupati', area: 'Railway Station', lat: 13.6280, lng: 79.4190, count: 20 },
  { city: 'Tirupati', area: 'Alipiri', lat: 13.6496, lng: 79.3980, count: 20 }
];

// --- HELPERS ---
function getRandomInt(min, max) {
  return Math.floor(Math.random() * (max - min + 1)) + min;
}

function getRandomSubarray(arr, size) {
  var shuffled = arr.slice(0), i = arr.length, temp, index;
  while (i--) {
    index = Math.floor((i + 1) * Math.random());
    temp = shuffled[index];
    shuffled[index] = shuffled[i];
    shuffled[i] = temp;
  }
  return shuffled.slice(0, size);
}

function getOperatingHours() {
  const schedule = {};
  ['monday', 'tuesday', 'wednesday', 'thursday', 'friday', 'saturday', 'sunday'].forEach(day => {
    schedule[day] = {
      open: '06:00',
      close: '23:00'
    };
  });
  return schedule;
}

function fuzzLocation(lat, lng) {
  // Randomize within ~500-800m
  const latOffset = (Math.random() - 0.5) * 0.008; 
  const lngOffset = (Math.random() - 0.5) * 0.008;
  return { lat: lat + latOffset, lng: lng + lngOffset };
}

// Generate sequential ID like QP000001, QP000002, etc.
function generateSequentialId(number) {
  return `${ID_PREFIX}${String(number).padStart(6, '0')}`;
}

// --- MAIN GENERATOR ---
async function run() {
  console.log(`🚀 Starting Smart Parking Seed into '${COLLECTION_NAME}'...`);
  console.log(`📋 Using sequential IDs: ${ID_PREFIX}000001, ${ID_PREFIX}000002, ...`);
  
  const batchLimit = 400;
  let batch = db.batch();
  let operationCounter = 0;
  let sequentialId = ID_START; // Global counter for sequential IDs

  for (const zone of ZONES) {
    console.log(`📍 Processing ${zone.city} - ${zone.area}...`);

    for (let i = 0; i < zone.count; i++) {
      const loc = fuzzLocation(zone.lat, zone.lng);
      const hash = geohash.encode(loc.lat, loc.lng);
      
      const totalSpots = getRandomInt(10, 80);
      const availableSpots = getRandomInt(0, totalSpots);
      
      // Generate sequential document ID
      const docId = generateSequentialId(sequentialId);
      const docRef = db.collection(COLLECTION_NAME).doc(docId);
      
      const parkingSpot = {
        id: docId, // Use sequential ID
        name: `${zone.area} Parking ${String.fromCharCode(65 + i % 26)}-${getRandomInt(100, 999)}`,
        description: DESCRIPTIONS[getRandomInt(0, DESCRIPTIONS.length - 1)],
        address: `${getRandomInt(1, 100)}, Main Road, ${zone.area}, ${zone.city}`,
        
        // Geospatial Data (Critical)
        location: new admin.firestore.GeoPoint(loc.lat, loc.lng),
        latitude: loc.lat,   // For your model mapping
        longitude: loc.lng,  // For your model mapping
        geoHash: hash,
        
        // Capacity & Price
        totalSpots: totalSpots,
        availableSpots: availableSpots,
        pricePerHour: getRandomInt(20, 100),
        
        // Arrays & Objects
        amenities: getRandomSubarray(AMENITIES_OPTIONS, getRandomInt(2, 5)),
        vehicleTypes: getRandomSubarray(VEHICLE_TYPES, getRandomInt(1, 3)),
        operatingHours: getOperatingHours(),
        images: ["https://maps.gstatic.com/tactile/basepage/pegman_sherlock.png"], // Placeholder
        
        // Meta
        status: 'available', // Enum matching
        ownerId: 'system_admin_script',
        contactPhone: `+91 ${getRandomInt(7000000000, 9999999999)}`,
        rating: parseFloat((3.5 + Math.random() * 1.5).toFixed(1)),
        reviewCount: getRandomInt(5, 100),
        isVerified: true,
        
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
        updatedAt: admin.firestore.FieldValue.serverTimestamp()
      };

      batch.set(docRef, parkingSpot);
      operationCounter++;
      sequentialId++; // Increment for next document

      if (operationCounter >= batchLimit) {
        await batch.commit();
        console.log(`   ✅ Committed batch of ${operationCounter} spots (up to ${generateSequentialId(sequentialId - 1)})...`);
        batch = db.batch();
        operationCounter = 0;
      }
    }
  }

  if (operationCounter > 0) {
    await batch.commit();
  }

  const totalAdded = sequentialId - ID_START;
  console.log(`\n🎉 SUCCESS! Added ${totalAdded} parking spots.`);
  console.log(`📝 IDs range: ${generateSequentialId(ID_START)} to ${generateSequentialId(sequentialId - 1)}`);
  console.log(`⚠️ NOTE: Ensure your Flutter app's 'DatabaseService' queries the collection: '${COLLECTION_NAME}'`);
}

run().catch(console.error);