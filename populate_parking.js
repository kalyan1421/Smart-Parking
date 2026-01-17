
const admin = require('firebase-admin');
const geohash = require('ngeohash');

// 1. Initialize Firebase Admin SDK
// Make sure you have your serviceAccountKey.json in the same folder
var serviceAccount = require("./serviceAccountKey.json");

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount)
});

const db = admin.firestore();

// 2. Configuration Data
const CITIES = [
  { name: 'hyderabad', lat: 17.3850, lng: 78.4867, weight: 0.4 }, // 40% of spots
  { name: 'chennai', lat: 13.0827, lng: 80.2707, weight: 0.3 },   // 30% of spots
  { name: 'vijayawada', lat: 16.5062, lng: 80.6480, weight: 0.1 },
  { name: 'visakhapatnam', lat: 17.6868, lng: 83.2185, weight: 0.1 },
  { name: 'tirupati', lat: 13.6288, lng: 79.4192, weight: 0.1 }
];

const PARKING_NAMES = [
  "City Center Parking", "Mall Plaza Spot", "Metro Station Park", 
  "Market Complex", "Tech Park Zone", "Central Garage", "High Street Parking",
  "Residency Grounds", "Airport Long Stay", "Railway Station Slot"
];

const FACILITIES_LIST = [
  "CCTV", "Covered Roof", "EV Charging", "Disabled Access", "24/7 Guard", "Car Wash"
];

// Helper to get random number in range
const randomInt = (min, max) => Math.floor(Math.random() * (max - min + 1)) + min;

// Helper to generate random coordinates around a center point (radius in degrees approx)
const randomLocation = (centerLat, centerLng, radius = 0.05) => {
  const y0 = centerLat;
  const x0 = centerLng;
  const u = Math.random();
  const v = Math.random();
  const w = radius * Math.sqrt(u);
  const t = 2 * Math.PI * v;
  const x = w * Math.cos(t);
  const y = w * Math.sin(t);
  return {
    latitude: y + y0,
    longitude: x + x0
  };
};

async function generateData() {
  console.log("🚀 Starting data generation for 500 spots...");
  
  const batchSize = 400; // Firestore batch limit is 500
  let batch = db.batch();
  let count = 0;
  let totalCreated = 0;

  for (let i = 0; i < 500; i++) {
    // 1. Pick a city based on weight
    const rand = Math.random();
    let cumulativeWeight = 0;
    let selectedCity = CITIES[0];
    
    for (const city of CITIES) {
      cumulativeWeight += city.weight;
      if (rand <= cumulativeWeight) {
        selectedCity = city;
        break;
      }
    }

    // 2. Generate Random Location
    const loc = randomLocation(selectedCity.lat, selectedCity.lng);
    const hash = geohash.encode(loc.latitude, loc.longitude);

    // 3. Generate Random Details
    const totalSlots = randomInt(20, 150);
    const availableSlots = randomInt(0, totalSlots);
    const price = randomInt(20, 100); // Price between 20-100 per hour
    
    // Pick random 2-4 facilities
    const facilities = [];
    while(facilities.length < randomInt(2, 4)) {
        const f = FACILITIES_LIST[Math.floor(Math.random() * FACILITIES_LIST.length)];
        if(!facilities.includes(f)) facilities.push(f);
    }

    // 4. Create Document Object
    const ref = db.collection('parking_spots').doc();
    const parkingData = {
      name: `${PARKING_NAMES[randomInt(0, PARKING_NAMES.length - 1)]} - ${randomInt(100, 999)}`,
      address: `Sector ${randomInt(1, 99)}, ${selectedCity.name}, ${selectedCity.name === 'chennai' ? 'TN' : 'AP/TS'}`,
      city: selectedCity.name,
      location: new admin.firestore.GeoPoint(loc.latitude, loc.longitude),
      geoHash: hash,
      totalSlots: totalSlots,
      availableSlots: availableSlots,
      pricePerHour: price,
      facilities: facilities,
      isActive: true,
      imageUrl: "https://maps.gstatic.com/tactile/basepage/pegman_sherlock.png", // Placeholder
      createdAt: admin.firestore.FieldValue.serverTimestamp()
    };

    batch.set(ref, parkingData);
    count++;
    totalCreated++;

    // Commit batch if full
    if (count >= batchSize) {
      await batch.commit();
      console.log(`✅ Committed batch of ${count} spots...`);
      batch = db.batch();
      count = 0;
    }
  }

  // Commit remaining
  if (count > 0) {
    await batch.commit();
    console.log(`✅ Committed final batch of ${count} spots.`);
  }

  console.log(`🎉 Successfully created ${totalCreated} parking spots!`);
}

generateData().catch(console.error);