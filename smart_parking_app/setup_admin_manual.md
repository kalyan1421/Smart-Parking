# 🔐 Manual Admin Setup Guide

## Method 1: Using Firebase Console (Recommended)

### Step 1: Create Admin User in Firebase Authentication
1. Go to [Firebase Console](https://console.firebase.google.com/)
2. Select your project: `smart-parking-kalyan-2024`
3. Navigate to **Authentication** → **Users**
4. Click **Add user**
5. Enter:
   - **Email**: `admin@smartparking.com`
   - **Password**: `admin123456`
6. Click **Add user**
7. Copy the **User UID** (you'll need it for the next step)

### Step 2: Create Admin Profile in Firestore
1. Navigate to **Firestore Database**
2. Go to the `users` collection (create if it doesn't exist)
3. Click **Add document**
4. Use the **User UID** from Step 1 as the **Document ID**
5. Add the following fields:

```json
{
  "id": "USER_UID_FROM_STEP_1",
  "email": "admin@smartparking.com",
  "displayName": "Admin User",
  "role": "admin",
  "phoneNumber": "+1234567890",
  "isEmailVerified": true,
  "isPhoneVerified": false,
  "createdAt": "2024-01-01T00:00:00.000Z",
  "updatedAt": "2024-01-01T00:00:00.000Z",
  "preferences": {
    "theme": "light",
    "notifications": true
  },
  "vehicleIds": [],
  "bookingIds": [],
  "location": null
}
```

### Step 3: Add Sample Parking Spots
1. In Firestore, go to the `parking_spots` collection (create if it doesn't exist)
2. Add these sample documents:

#### Document 1: `downtown_plaza`
```json
{
  "id": "downtown_plaza",
  "name": "Downtown Plaza Parking",
  "description": "Premium parking in the heart of the city",
  "latitude": 17.331472,
  "longitude": 78.5259811,
  "position": {
    "geohash": "tdr1u8b",
    "geopoint": {
      "latitude": 17.331472,
      "longitude": 78.5259811
    }
  },
  "totalSpots": 100,
  "availableSpots": 75,
  "pricePerHour": 15.0,
  "ownerId": "system",
  "address": "Downtown Plaza, Main Street",
  "amenities": ["security", "covered", "ev_charging"],
  "vehicleTypes": ["car", "motorcycle"],
  "status": "available",
  "isVerified": true,
  "rating": 4.5,
  "reviewCount": 128,
  "operatingHours": {
    "monday": { "open": "06:00", "close": "22:00" },
    "tuesday": { "open": "06:00", "close": "22:00" },
    "wednesday": { "open": "06:00", "close": "22:00" },
    "thursday": { "open": "06:00", "close": "22:00" },
    "friday": { "open": "06:00", "close": "23:00" },
    "saturday": { "open": "07:00", "close": "23:00" },
    "sunday": { "open": "08:00", "close": "21:00" }
  },
  "contactPhone": "+91 9876543210",
  "accessibility": {
    "wheelchair": true,
    "elevator": true,
    "ramp": true
  },
  "images": [],
  "createdAt": "2024-01-01T00:00:00.000Z",
  "updatedAt": "2024-01-01T00:00:00.000Z",
  "weatherData": null
}
```

#### Document 2: `tech_hub_parking`
```json
{
  "id": "tech_hub_parking",
  "name": "Tech Hub Business Center",
  "description": "Modern parking facility for tech professionals",
  "latitude": 17.332472,
  "longitude": 78.5269811,
  "position": {
    "geohash": "tdr1u8c",
    "geopoint": {
      "latitude": 17.332472,
      "longitude": 78.5269811
    }
  },
  "totalSpots": 150,
  "availableSpots": 120,
  "pricePerHour": 12.0,
  "ownerId": "system",
  "address": "Tech Hub, HITEC City",
  "amenities": ["security", "wifi", "restroom"],
  "vehicleTypes": ["car", "motorcycle", "bicycle"],
  "status": "available",
  "isVerified": true,
  "rating": 4.3,
  "reviewCount": 89,
  "operatingHours": {
    "monday": { "open": "05:00", "close": "23:00" },
    "tuesday": { "open": "05:00", "close": "23:00" },
    "wednesday": { "open": "05:00", "close": "23:00" },
    "thursday": { "open": "05:00", "close": "23:00" },
    "friday": { "open": "05:00", "close": "23:00" },
    "saturday": { "open": "06:00", "close": "22:00" },
    "sunday": { "open": "07:00", "close": "21:00" }
  },
  "contactPhone": "+91 9876543211",
  "accessibility": {
    "wheelchair": true,
    "elevator": false,
    "ramp": true
  },
  "images": [],
  "createdAt": "2024-01-01T00:00:00.000Z",
  "updatedAt": "2024-01-01T00:00:00.000Z",
  "weatherData": null
}
```

## Method 2: Using Node.js Script (Advanced)

If you have Node.js installed and want to automate the process:

1. Install Firebase Admin SDK:
```bash
npm install firebase-admin
```

2. Download service account key:
   - Go to Firebase Console → Project Settings → Service Accounts
   - Click "Generate new private key"
   - Save as `smart-parking-service-account-key.json`

3. Run the setup script:
```bash
node setup_admin.js
```

## 🔍 Verification Steps

After setup, verify everything works:

1. **Test Authentication**:
   - Open your admin app
   - Log in with `admin@smartparking.com` / `admin123456`

2. **Test Firestore Rules**:
   - Check that admin can read/write all collections
   - Verify parking spots are visible

3. **Test User App**:
   - Open your user app  
   - Check that parking spots are loading
   - Verify no loading issues

## 🚨 Troubleshooting

### Login Issues
- Ensure user exists in Firebase Auth
- Check user role is "admin" in Firestore
- Verify Firestore rules are deployed

### No Parking Spots
- Check `parking_spots` collection exists
- Verify position.geopoint field format
- Check Firestore permissions

### Permission Errors
- Deploy updated Firestore rules
- Verify user role matches rule expectations
