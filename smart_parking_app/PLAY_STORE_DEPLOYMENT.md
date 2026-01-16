# QuickPark - Google Play Store Deployment Guide

## 📱 App Information

| Field | Value |
|-------|-------|
| **App Name** | QuickPark |
| **Package Name** | com.quickpark.smartparking |
| **Version** | 1.0.0 |
| **Version Code** | 1 |
| **Min SDK** | Android 6.0 (API 23) |
| **Target SDK** | Android 14 (API 35) |

---

## 🔐 Signing Configuration

The app is configured with release signing for Play Store deployment.

### Keystore Location
```
android/keystore/release.jks
```

### Key Properties
```
android/key.properties
```

> ⚠️ **IMPORTANT**: Never commit `key.properties` or `*.jks` files to version control. They are already in `.gitignore`.

---

## 🛠️ Build Commands

### Generate Release AAB (Android App Bundle)
```bash
cd smart_parking_app
flutter clean
flutter pub get
flutter build appbundle --release
```

The AAB file will be generated at:
```
build/app/outputs/bundle/release/app-release.aab
```

### Generate Release APK (for testing)
```bash
flutter build apk --release
```

APK location:
```
build/app/outputs/flutter-apk/app-release.apk
```

---

## 📋 Play Store Requirements Checklist

### Required Assets

#### App Icon
- ✅ High-res icon (512 x 512 px)
- Location: `assets/playstore.png`

#### Feature Graphic
- Size: 1024 x 500 px
- Create and upload to Play Console

#### Screenshots (Required)
- Phone: At least 2 screenshots (16:9 or 9:16)
- Tablet (7"): At least 1 screenshot (optional but recommended)
- Tablet (10"): At least 1 screenshot (optional but recommended)

### Store Listing Content

#### Short Description (80 characters max)
```
Smart parking made easy - find, book & pay for parking spots instantly.
```

#### Full Description (4000 characters max)
```
QuickPark is your ultimate smart parking companion! Find available parking spots near you, book them in advance, and pay seamlessly through the app.

🚗 KEY FEATURES:

📍 FIND PARKING
• Real-time map view of available parking spots
• Filter by location, price, and availability
• Get directions to your parking spot

📅 EASY BOOKING
• Book parking spots in advance
• Flexible time slots
• Instant confirmation with QR code

💳 SECURE PAYMENTS
• Multiple payment options
• Transparent pricing
• Digital receipts

📊 HISTORY & MANAGEMENT
• View booking history
• Download PDF receipts
• Rate and review parking locations

🔔 SMART NOTIFICATIONS
• Booking reminders
• Parking expiry alerts
• Special offers and discounts

Whether you're heading to work, shopping, or exploring the city, QuickPark ensures you always find the perfect parking spot. Save time, reduce stress, and park smarter!

Download QuickPark today and never circle the block looking for parking again!
```

### App Categorization
- **Category**: Auto & Vehicles or Maps & Navigation
- **Content Rating**: Everyone

### Privacy Policy
- Required URL for apps that collect user data
- Must include data collection and usage details

### Contact Information
- Support email (required)
- Phone number (optional)
- Website (optional)

---

## 🔒 Permissions Used

| Permission | Purpose |
|------------|---------|
| `INTERNET` | Network communication |
| `ACCESS_FINE_LOCATION` | Precise location for parking search |
| `ACCESS_COARSE_LOCATION` | Approximate location |
| `ACCESS_BACKGROUND_LOCATION` | Location updates while parked |
| `CAMERA` | QR code scanning |
| `READ_EXTERNAL_STORAGE` | Profile image selection |
| `WRITE_EXTERNAL_STORAGE` | PDF receipt storage |
| `FOREGROUND_SERVICE` | Background location updates |

---

## 📤 Upload Process

### Step 1: Create App in Play Console
1. Go to [Google Play Console](https://play.google.com/console)
2. Click "Create app"
3. Fill in app details and language
4. Accept Developer Program Policies

### Step 2: Complete Store Listing
1. Add app name, descriptions, icon
2. Upload screenshots and feature graphic
3. Set categorization and contact info

### Step 3: Set Up Content Rating
1. Answer content rating questionnaire
2. Receive IARC rating certificate

### Step 4: Set Pricing & Distribution
1. Set app as Free or Paid
2. Select target countries
3. Set content guidelines compliance

### Step 5: Upload AAB
1. Go to Production > Create new release
2. Upload `app-release.aab`
3. Add release notes
4. Review and roll out

---

## 🔄 Version Updates

For future updates, increment version in `pubspec.yaml`:

```yaml
version: 1.0.1+2  # version_name+version_code
```

Always increment `versionCode` for each release.

---

## 🐛 Troubleshooting

### Build Errors

**Error: Keystore not found**
```bash
# Verify keystore exists
ls -la android/keystore/release.jks
```

**Error: Wrong key password**
```bash
# Verify key.properties values match keystore credentials
cat android/key.properties
```

### ProGuard Issues
If the release build crashes, check `android/app/proguard-rules.pro` and add keep rules for affected classes.

---

## 📞 Support

For deployment assistance, contact the development team.

---

*Last updated: January 2026*
