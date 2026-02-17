# 🅿️ QuickPark — Smart Parking System

> **Complete Technical Documentation**
> Version 1.0.0 | Flutter + Firebase + Python ML

---

## Table of Contents

1. [Overview](#1-overview)
2. [Architecture & Stack](#2-architecture--stack)
3. [Features](#3-features)
4. [Models & Data](#4-models--data)
5. [Backend Functions & Business Logic](#5-backend-functions--business-logic)
6. [User Roles & Permissions](#6-user-roles--permissions)
7. [Weather Integration](#7-weather-integration)
8. [UI & Navigation](#8-ui--navigation)
9. [Problems Addressed & Solutions](#9-problems-addressed--solutions)
10. [Dependencies](#10-dependencies)
11. [Build & Deployment](#11-build--deployment)
12. [Full Feature Table](#12-full-feature-table)

---

## 1. Overview

### 1.1 Core Purpose

**QuickPark** is a production-grade smart parking management ecosystem consisting of:

| Component | Technology | Purpose |
|---|---|---|
| **Customer App** | Flutter (Android/iOS) | End-users search, book, and manage parking sessions |
| **Admin Panel** | Flutter (Web/Desktop) | Operators manage spots, bookings, users, and revenue |
| **ML API Server** | Python (Flask) | ANPR plate detection + weather-based parking recommendations |

### 1.2 Problem Statement

Urban parking suffers from:

- **Blind searching** — drivers waste 15–20 minutes circling for parking
- **No real-time availability** — spots shown as "available" may be occupied
- **Manual check-in/out** — slow, error-prone, no audit trail
- **Weather-ignorant recommendations** — users aren't guided to covered/underground spots when it rains or when temps exceed 40°C
- **Double-booking & race conditions** — concurrent users booking the same last slot

QuickPark addresses every one of these through real-time streaming, atomic Firestore transactions, geospatial queries, ANPR automation, and weather-aware ML recommendations.

### 1.3 Target Users

| Role | Description |
|---|---|
| **Customer** | Drivers who need to find, book, and pay for parking |
| **Parking Operator** | Lot owners who list and manage their parking facilities |
| **Admin** | Platform administrators who oversee users, bookings, and revenue |

---

## 2. Architecture & Stack

### 2.1 Technology Stack

```
┌─────────────────────────────────────────────────────────────┐
│                    PRESENTATION LAYER                        │
│  Customer App (Flutter)     │     Admin Panel (Flutter Web)  │
│  Provider state management  │     Provider + ResponsiveFramework │
└──────────────┬──────────────┴──────────────┬────────────────┘
               │                              │
┌──────────────▼──────────────────────────────▼────────────────┐
│                    FIREBASE SERVICES                          │
│  Authentication  │  Cloud Firestore  │  Cloud Storage         │
│  (Email, Google, │  (NoSQL DB with   │  (Images, PDFs,        │
│   Phone OTP)     │   real-time sync) │   documents)           │
└──────────────────────────┬──────────────────────────────────┘
                           │
┌──────────────────────────▼──────────────────────────────────┐
│                   PYTHON ML BACKEND                          │
│  Flask API Server                                            │
│  ├── Number Plate Recognition (YOLOv8 + EasyOCR)            │
│  ├── Weather Recommendation Engine (Rule-based + sklearn)    │
│  └── Firebase Admin SDK (booking verification)               │
└─────────────────────────────────────────────────────────────┘
```

### 2.2 Firebase Services Used

| Service | Usage |
|---|---|
| **Firebase Auth** | Email/password, Google Sign-In, phone OTP authentication |
| **Cloud Firestore** | Primary NoSQL database: `users`, `bookings`, `parkingSpots`, `vehicles`, `transactions`, `partnerRequests`, `counters` |
| **Cloud Storage** | Profile images, vehicle photos, parking spot images, receipts (PDF), partner request documents |
| **Firebase Hosting** | Admin panel web deployment |

### 2.3 Data Flow

**Booking Flow (Customer → Firestore → Admin):**
```
1. Customer opens app → AuthProvider.initialize() → Firebase Auth check
2. Location obtained → ParkingProvider.startStreamingNearby() → GeoFlutterFire+ query
3. Firestore streams real-time parkingSpots → client-side filtering (price, amenities, vehicle type)
4. User selects spot → BookingProvider.createBooking()
5. DatabaseService.createBookingAtomic() runs Firestore TRANSACTION:
   a. Read counter doc + parking spot doc (all reads first)
   b. Validate available spots > 0
   c. Check time-slot conflicts against existing bookings
   d. Generate sequential booking ID (QB000001)
   e. Write booking doc + decrement availableSpots + update counter
6. Booking confirmed → local notification + scheduled reminder (15 min before end)
7. Admin panel receives real-time update via Firestore stream
```

**ANPR Check-in Flow (Camera → API → Firestore):**
```
1. Camera captures vehicle image
2. POST /api/check-in with base64 image
3. PlateDetector: YOLOv8 detection → EasyOCR text extraction → Indian format validation
4. Query Firestore for confirmed booking matching plate + current time window
5. Update booking status: confirmed → active, set checkedInAt timestamp
6. Return success + booking details
```

**Weather Recommendation Flow:**
```
1. GET /api/weather?lat=X&lon=Y → OpenWeatherMap API → current conditions
2. POST /api/recommendations with user location + parking spots list
3. ParkingRecommender scores each spot (weighted: distance 25%, weather 25%, availability 20%, price 15%, rating 10%, amenities 5%)
4. Weather suitability: rain → prefer covered/underground; hot → prefer underground; night → prefer secure
5. Return sorted recommendations with reasons ("Protected from rain", "Budget-friendly")
```

### 2.4 State Management

Both apps use the **Provider** pattern (ChangeNotifier):

**Customer App Providers:**
| Provider | File | Responsibility |
|---|---|---|
| `AuthProvider` | `providers/auth_provider.dart` | Login/register/Google/logout, user profile CRUD |
| `BookingProvider` | `providers/booking_provider.dart` | Atomic booking create/cancel, check-in/out, real-time streaming, PDF receipts |
| `ParkingProvider` | `providers/parking_provider.dart` | Real-time geo-streaming, filtering, sorting, CRUD |
| `WalletProvider` | `providers/wallet_provider.dart` | Balance management, add money, pay for booking |
| `VehicleProvider` | `providers/vehicle_provider.dart` | Vehicle CRUD, default vehicle management |
| `LocationProvider` | `providers/location_provider.dart` | GPS location tracking |
| `TrafficProvider` | `providers/traffic_provider.dart` | Traffic data management |
| `RoutingProvider` | `providers/routing_provider.dart` | Navigation routing |

**Admin App Providers:**
| Provider | File | Responsibility |
|---|---|---|
| `AuthProvider` | `providers/auth_provider.dart` | Admin/operator authentication + role gating |
| `AdminProvider` | `providers/admin_provider.dart` | Dashboard stats, user/booking/spot management |

---

## 3. Features

### 3.1 User Authentication

**What:** Multi-method authentication (email/password, Google Sign-In, phone OTP).

**Why:** Provide flexible, secure access; Google Sign-In reduces friction; phone OTP adds verification.

**How:**
- `AuthProvider` wraps Firebase Auth with state tracking (`AuthStatus` enum: initial, authenticating, authenticated, unauthenticated, error)
- On successful auth, user profile is loaded from Firestore `users` collection; if absent, auto-created
- Profile completion flow (`CompleteProfileScreen`) ensures name + phone are set before full access
- Password reset via `resetPassword()` sends Firebase reset email

**Code References:**
- `smart_parking_app/lib/providers/auth_provider.dart` — all auth methods
- `smart_parking_app/lib/screens/auth/login_screen.dart` — login UI
- `smart_parking_app/lib/screens/auth/register_screen.dart` — registration UI
- `smart_parking_app/lib/screens/auth/complete_profile_screen.dart` — profile completion
- `smart_parking_app/lib/screens/auth/splash_screen.dart` — initial auth check

---

### 3.2 Real-Time Parking Spot Discovery

**What:** Location-based parking spot discovery with live availability updates.

**Why:** Eliminates blind searching; shows real-time availability as admin updates spots.

**How:**
- `ParkingProvider.startStreamingNearby()` uses **GeoFlutterFire+** to subscribe to geo-radius queries on `parkingSpots` collection
- Firestore snapshots stream → `_processSpotUpdates()` diffs against cache (avoids unnecessary rebuilds)
- Fallback stream (`_startFallbackStream()`) loads all spots if geo-query fails
- Client-side filtering: price range, amenities, vehicle types, availability-only toggle
- Sorting: distance (using Geolocator), price, rating, availability
- Debounced notifications (16ms) prevent UI rebuild storms

**Code References:**
- `smart_parking_app/lib/providers/parking_provider.dart` — streaming + filtering logic
- `smart_parking_app/lib/screens/parking/parking_map_screen.dart` — Google Maps with markers
- `smart_parking_app/lib/screens/parking/parking_list_screen.dart` — list view
- `smart_parking_app/lib/screens/parking/filter_bar.dart` — filter UI
- `smart_parking_app/lib/screens/parking/parking_spot_bottom_sheet.dart` — spot detail sheet

---

### 3.3 Atomic Booking System

**What:** Transaction-safe booking with race-condition prevention and sequential IDs.

**Why:** Prevents double-booking the last available slot when multiple users book simultaneously.

**How:**
- `DatabaseService.createBookingAtomic()` runs a Firestore **transaction** (up to 3 retry attempts):
  1. Read counter doc + parking spot doc (Firestore requires all reads before writes)
  2. Validate `availableSpots > 0`
  3. Query overlapping bookings (same spot, overlapping time window)
  4. Reject if `overlappingCount >= totalSpots` (capacity-aware, not boolean)
  5. Generate sequential ID: `QB` + 6-digit padded number (e.g., `QB000042`)
  6. Calculate price: `(endTime - startTime) hours * pricePerHour`
  7. Write: booking doc, counter update, decrement `availableSpots`
- Cancellation (`cancelBookingAtomic()`) uses same pattern: read booking + spot, update status, increment spots, calculate tiered refund

**Refund Policy:**
| Time Before Start | Refund |
|---|---|
| > 24 hours | 90% |
| 2–24 hours | 50% |
| < 2 hours | 0% |

**Code References:**
- `smart_parking_app/lib/core/database/database_service.dart` — `createBookingAtomic()`, `cancelBookingAtomic()`, `checkOutAtomic()`
- `smart_parking_app/lib/providers/booking_provider.dart` — `createBooking()`, `cancelBooking()`
- `smart_parking_app/lib/repositories/booking_repository.dart` — repository pattern

---

### 3.4 QR Code Check-In/Out

**What:** Check-in at parking spots by scanning a QR code tied to the booking.

**Why:** Fast, contactless verification; validates user is physically at the parking location.

**How:**
- Each booking has a `qrCode` field
- `BookingProvider.checkInByQrCode()` queries Firestore for matching QR + confirmed/pending status
- **Geofencing check**: uses `Geolocator.distanceBetween()` to ensure user is within 100 meters of the parking spot
- If valid, updates booking status to `active` with `checkedInAt` timestamp and `checkInMethod: qrCode`

**Code References:**
- `smart_parking_app/lib/screens/parking/qr_scanner_screen.dart` — camera scanning UI
- `smart_parking_app/lib/providers/booking_provider.dart` — `checkInByQrCode()`

---

### 3.5 ANPR (Automatic Number Plate Recognition)

**What:** Check-in/out vehicles automatically by capturing their license plate.

**Why:** Enables fully automated, human-free parking gate systems.

**How:**
- **Detection**: YOLOv8 model detects plate region in image; falls back to OpenCV contour detection if YOLO unavailable
- **OCR**: EasyOCR extracts text from cropped plate region
- **Validation**: Regex validates Indian license plate format (e.g., `TS09AB1234`)
- **Booking Match**: Queries Firestore for matching `vehicleNumberPlate` + confirmed/active status
- **Time Validation**: Allows check-in 15 minutes before start time, rejects if past end time
- **Overtime**: Check-out calculates overtime at 1.5× hourly rate

**API Endpoints:**
| Endpoint | Method | Description |
|---|---|---|
| `/api/detect-plate` | POST | Detect plate from image (base64 or file) |
| `/api/check-in` | POST | Detect plate → find booking → activate |
| `/api/check-out` | POST | Detect plate → find active booking → complete + calculate overtime |

**Code References:**
- `python_models/number_plate_recognition/plate_detector.py` — `PlateDetector` class
- `python_models/number_plate_recognition/ocr_engine.py` — `OCREngine` class
- `python_models/api_server.py` — Flask endpoints

---

### 3.6 Weather-Based Parking Recommendations

**What:** ML-powered recommendation engine that scores parking spots based on current weather.

**Why:** Guides users to covered/underground parking during rain/heat; improves user experience and safety.

**How:**
- `WeatherService` fetches current weather from **OpenWeatherMap API**
- `ParkingRecommender._calculate_score()` uses weighted scoring:

| Factor | Weight | Logic |
|---|---|---|
| Distance | 25% | Closer = higher score (normalized to 5km max) |
| Weather Suitability | 25% | Rain → prefer covered (+0.3)/underground (+0.4); Hot → underground (+0.4); Night → secure (+0.2) |
| Availability | 20% | Lower occupancy = higher score |
| Price | 15% | Cheaper = higher score (normalized to ₹100/hr max) |
| Rating | 10% | Higher user rating = higher |
| Amenities | 5% | More amenities = higher |

- Bonus: 10% boost if weather suitability > 0.9
- Returns sorted list of `Recommendation` objects with human-readable reasons

**Weather Impact Matrix:**

| Condition | Covered Spot | Underground Spot | Open Spot |
|---|---|---|---|
| Raining | +0.3 ("Stay dry") | +0.4 ("Protected") | -0.2 ("May get wet") |
| Hot (>35°C) | +0.25 ("Shaded") | +0.4 ("Cool parking") | -0.15 ("Car heats up") |
| Cold (<10°C) | Neutral | +0.2 ("Warmer") | Neutral |
| High UV (>6) | +0.2 ("UV protected") | +0.2 | Neutral |
| Night/Fog | Neutral if secure | Neutral if secure | Neutral |

**Code References:**
- `python_models/weather_recommendation/recommender.py` — `ParkingRecommender` class
- `python_models/weather_recommendation/weather_api.py` — `WeatherService` class
- `python_models/api_server.py` — `/api/recommendations`, `/api/weather`, `/api/weather-advice`
- `smart_parking_app/lib/services/weather_service.dart` — Flutter-side weather integration

---

### 3.7 Digital Wallet & Payments

**What:** In-app wallet for adding funds and paying for parking.

**Why:** Frictionless payments; wallet balance eliminates repeated card entry.

**How:**
- `WalletProvider.addMoney()` runs Firestore transaction: increment `walletBalance` on user doc + create transaction record
- `WalletProvider.payForBooking()` checks balance ≥ amount, then deducts atomically
- Transaction types: `deposit`, `payment`, `refund`, `withdrawal`
- Payment methods: `upi`, `card`, `netbanking`, `wallet`, `cash`
- Wallet screen shows balance + transaction history

**Code References:**
- `smart_parking_app/lib/providers/wallet_provider.dart` — `addMoney()`, `payForBooking()`
- `smart_parking_app/lib/models/transaction.dart` — `WalletTransaction` model
- `smart_parking_app/lib/screens/wallet/wallet_screen.dart` — wallet UI

---

### 3.8 Vehicle Management

**What:** CRUD for user vehicles with default vehicle selection.

**Why:** Users need to register vehicles for booking (plate number is used for ANPR check-in).

**How:**
- `VehicleProvider` manages `vehicles` collection filtered by `userId`
- Adding a vehicle: creates Firestore doc; if `isDefault`, batch-unsets other defaults
- Vehicle model tracks: `numberPlate`, `make`, `model`, `color`, `type` (car/motorcycle/bicycle/electric), `fuelType`
- Insurance and registration tracking with document uploads

**Code References:**
- `smart_parking_app/lib/providers/vehicle_provider.dart` — CRUD operations
- `smart_parking_app/lib/models/vehicle.dart` — `Vehicle` model (227 lines with full Firestore serialization)
- `smart_parking_app/lib/screens/profile/vehicles/vehicle_list_screen.dart` — vehicle management UI

---

### 3.9 PDF Receipt Generation

**What:** Generate downloadable PDF receipts for bookings, cancellations, and batch exports.

**Why:** Official documentation for parking sessions; useful for business expense tracking.

**How:**
- `PdfManager` class orchestrates receipt generation
- `PdfService` generates PDF documents using the `pdf` package
- Receipts include: booking ID, vehicle details, spot info, timestamps, price breakdown, QR code
- Cancellation receipts include refund amount and reason
- Batch generation for multiple bookings

**Code References:**
- `smart_parking_app/lib/services/pdf_service.dart` — PDF generation
- `smart_parking_app/lib/services/pdf_manager.dart` — orchestration layer

---

### 3.10 Push Notifications

**What:** Local and scheduled push notifications for booking events.

**Why:** Timely reminders prevent missed parking sessions and overstay fees.

**How:**
- `NotificationService` uses `flutter_local_notifications` package
- Booking confirmed → immediate notification
- 15 minutes before end → scheduled reminder ("Your parking expires in 15 minutes")
- Auto-cancel no-shows → notification

**Code References:**
- `smart_parking_app/lib/services/notification_service.dart` — notification management
- `smart_parking_app/lib/providers/booking_provider.dart` — `_showBookingNotification()`

---

### 3.11 Partner Request System

**What:** Users can apply to become parking operators by submitting documents.

**Why:** Enables the platform to on-board new parking lot owners.

**How:**
- `PartnerRequest` model tracks: business name, address, documents (business registration, parking photos, ID proof), total parking spots, operating hours
- Status flow: `pending` → `underReview` → `approved`/`rejected`
- Document upload to Firebase Storage (`partnerRequests/{id}/documents/`)
- Admin reviews in admin panel

**Code References:**
- `smart_parking_app/lib/models/partner_request.dart` — `PartnerRequest` model
- `smart_parking_app/lib/services/partner_request_service.dart` — submission logic
- `smart_parking_app/lib/screens/profile/partner_request_screen.dart` — application UI

---

### 3.12 Chat Support (AI Bot)

**What:** In-app chat support with AI-powered responses.

**Why:** Provides instant help without human support agents.

**How:**
- `TrafficBot` model provides pre-defined intents and responses
- Chat screen with message bubbles and quick-reply suggestions
- Covers: booking help, pricing inquiries, account issues

**Code References:**
- `smart_parking_app/lib/screens/chat/chat_support_screen.dart` — chat UI
- `smart_parking_app/lib/models/traffic_data.dart` — `TrafficBot` model

---

### 3.13 Parking Directions & Navigation

**What:** Turn-by-turn directions from user's location to selected parking spot.

**Why:** Guides drivers directly to the parking facility.

**How:**
- `RoutingProvider` computes routes using multiple options (fastest, shortest, toll-free)
- `RouteOption` model stores: distance, duration, polyline points, estimated fuel cost
- Integrates with Google Maps for rendering

**Code References:**
- `smart_parking_app/lib/providers/routing_provider.dart` — route computation
- `smart_parking_app/lib/models/route_option.dart` — `RouteOption` model
- `smart_parking_app/lib/screens/parking/parking_directions_screen.dart` — directions UI

---

### 3.14 Issue Reporting & Rating

**What:** Users can report issues and rate parking spots after completion.

**Why:** Quality feedback loop; helps other users and operators improve.

**Code References:**
- `smart_parking_app/lib/screens/parking/report_issue_screen.dart`
- `smart_parking_app/lib/screens/parking/rate_parking_screen.dart`
- `smart_parking_app/lib/providers/booking_provider.dart` — `addFeedback()`

---

### 3.15 Admin Dashboard

**What:** Comprehensive admin panel for platform management.

**Why:** Operators and admins need to manage spots, bookings, users, and view analytics.

**Features:**
- Dashboard with stats (total users, bookings, revenue, active spots)
- Parking spot CRUD with image upload
- Booking management (view, filter, update status)
- User management (view profiles, update roles)
- Revenue analytics and reporting
- Responsive layout (mobile, tablet, desktop) via `responsive_framework`

**Code References:**
- `smart_parking_admin_new/lib/screens/dashboard/dashboard_screen.dart`
- `smart_parking_admin_new/lib/screens/parking/parking_management_screen.dart`
- `smart_parking_admin_new/lib/screens/bookings/booking_management_screen.dart`
- `smart_parking_admin_new/lib/screens/users/user_management_screen.dart`
- `smart_parking_admin_new/lib/providers/admin_provider.dart`

---

## 4. Models & Data

### 4.1 Data Models Summary

| Model | File | Firestore Collection | Fields |
|---|---|---|---|
| `User` | `models/user.dart` | `users` | id, email, phoneNumber, displayName, city, emergencyContact, photoURL, role, vehicleIds, bookingIds, preferences, walletBalance, location, isEmailVerified, isPhoneVerified |
| `Booking` | `models/booking.dart` | `bookings` | id, userId, parkingSpotId, parkingSpotName, vehicleId, vehicleNumberPlate, latitude, longitude, startTime, endTime, pricePerHour, totalPrice, status, paymentMethod, qrCode, checkedInAt, checkedOutAt, checkInMethod, checkOutMethod, overtimeFee, cancellationReason, cancellationFee, feedback, notes, autoCompleteEnabled |
| `ParkingSpot` | `models/parking_spot.dart` | `parkingSpots` | id, name, description, latitude, longitude, geoPoint, totalSpots, availableSpots, pricePerHour, amenities, vehicleTypes, ownerId, status, operatingHours, images, rating, reviewCount, isVerified, weatherData, address, contactPhone, accessibility |
| `Vehicle` | `models/vehicle.dart` | `vehicles` | id, userId, numberPlate, make, model, color, type, fuelType, year, isDefault, insuranceExpiry, registrationExpiry, documents |
| `WalletTransaction` | `models/transaction.dart` | `transactions` | id, userId, amount, type, description, createdAt, bookingId, paymentMethod, status |
| `TrafficData` | `models/traffic_data.dart` | — | Embedded traffic/bot models for chat support |
| `PartnerRequest` | `models/partner_request.dart` | `partnerRequests` | id, userId, businessName, businessAddress, totalParkingSpots, operatingHours, documents, status, adminNotes |
| `RouteOption` | `models/route_option.dart` | — | Client-side route computation model |

### 4.2 Firestore Collections Schema

**`users`**
```
users/{userId}
├── id: string
├── email: string
├── displayName: string
├── phoneNumber: string?
├── role: "user" | "parkingOperator"
├── walletBalance: number
├── preferences: { theme, notifications, preferCovered }
├── location: { latitude, longitude }
├── vehicleIds: string[]
├── bookingIds: string[]
├── createdAt: Timestamp
└── updatedAt: Timestamp
```

**`bookings`**
```
bookings/{bookingId}   (e.g., QB000042)
├── userId: string
├── parkingSpotId: string
├── parkingSpotName: string
├── vehicleId: string
├── vehicleNumberPlate: string
├── latitude/longitude: number
├── startTime/endTime: Timestamp
├── pricePerHour/totalPrice: number
├── status: "pending" | "confirmed" | "active" | "completed" | "cancelled" | "expired"
├── paymentMethod: string
├── qrCode: string
├── checkedInAt/checkedOutAt: Timestamp?
├── checkInMethod: "qrCode" | "numberPlate" | "manual"
├── overtimeFee: number?
├── feedback: { rating, review, createdAt }
├── cancellationReason/cancellationFee: string/number?
├── createdAt/updatedAt: Timestamp
└── autoCompleteEnabled: bool
```

**`parkingSpots`**
```
parkingSpots/{spotId}   (e.g., QP000001)
├── name/description/address: string
├── latitude/longitude: number
├── position: { geohash: string, geopoint: GeoPoint }  // For GeoFlutterFire+
├── totalSpots/availableSpots: number
├── pricePerHour: number
├── amenities: string[]  ("security", "covered", "ev_charging", ...)
├── vehicleTypes: string[]  ("car", "motorcycle", "bicycle", ...)
├── ownerId: string
├── status: "available" | "occupied" | "maintenance" | "reserved"
├── operatingHours: { monday: { open, close }, ... }
├── images: string[]
├── rating: number
├── reviewCount: number
├── isVerified: bool
├── contactPhone: string
├── accessibility: { wheelchair, elevator, ramp }
├── createdAt/updatedAt: Timestamp
└── weatherData: Map?
```

**`vehicles`**
```
vehicles/{vehicleId}
├── userId: string
├── numberPlate: string
├── make/model/color: string
├── type: "car" | "motorcycle" | "bicycle" | "electric_car" | "truck" | "van"
├── fuelType: "petrol" | "diesel" | "electric" | "hybrid" | "cng"
├── year: number
├── isDefault: bool
├── insuranceExpiry/registrationExpiry: Timestamp?
├── documents: { insurance, registration, pollution }
└── createdAt/updatedAt: Timestamp
```

**`transactions`**
```
transactions/{transactionId}
├── userId: string
├── amount: number
├── type: "deposit" | "payment" | "refund" | "withdrawal"
├── description: string
├── bookingId: string?
├── paymentMethod: "upi" | "card" | "netbanking" | "wallet" | "cash"
├── status: "pending" | "completed" | "failed" | "refunded"
└── createdAt: Timestamp
```

**`counters`**
```
counters/bookings
└── lastId: number  // Incremented atomically for sequential booking IDs
```

---

## 5. Backend Functions & Business Logic

### 5.1 Firestore Transactions (Client-Side)

The app uses **client-side Firestore transactions** (not Cloud Functions) for critical operations:

| Operation | Function | Logic |
|---|---|---|
| **Create Booking** | `DatabaseService.createBookingAtomic()` | Read counter + spot → validate availability + time conflicts → generate ID → write booking + decrement spots |
| **Cancel Booking** | `DatabaseService.cancelBookingAtomic()` | Read booking + spot → calculate tiered refund → update status → increment spots |
| **Check-Out** | `DatabaseService.checkOutAtomic()` | Read booking + spot → update status to completed → increment spots |
| **Add Money** | `WalletProvider.addMoney()` | Increment user balance + create transaction record |
| **Pay for Booking** | `WalletProvider.payForBooking()` | Decrement user balance + create transaction record |

### 5.2 Python API Server Business Logic

| Endpoint | Business Rule |
|---|---|
| `/api/check-in` | Allow check-in 15 min before `startTime`; reject after `endTime` |
| `/api/check-out` | Calculate overtime at **1.5× hourly rate** for time past `endTime` |
| `/api/recommendations` | Filter by: max distance (5km), availability > 0, max price, EV charging need; apply weighted scoring |

### 5.3 Auto-Cancel No-Shows

`BookingProvider.autoCancelNoShows()` runs on `loadUserBookings()`:
- Finds confirmed/pending bookings with no check-in
- Grace period: **15 minutes** after both `startTime` AND `createdAt`
- Auto-cancels with reason "No-show: Auto-cancelled"

### 5.4 Firestore Security Rules

Production-grade rules (`firestore.rules`, 419 lines) enforce:
- Users can only read/write their own documents
- Booking creation requires authenticated user matching `userId`
- Parking spot writes restricted to operators and admins
- Admin operations require `role == "admin"` in user doc
- Transaction safety via field-level validation

### 5.5 Storage Security Rules

`storage.rules` (221 lines) enforces:
- Profile images: owner-only write, 2MB max, image types only
- Vehicle/parking images: authenticated write, 10MB max
- Documents (ID, license): owner-only read/write, 5MB max, PDF/image types
- Receipts: authenticated write, PDF only, 10MB max
- Public assets: anyone can read
- Admin uploads: authenticated only
- Analytics/backups: no client access

---

## 6. User Roles & Permissions

### 6.1 Role Definitions

| Role | Enum Value | Description |
|---|---|---|
| **Customer** | `UserRole.user` | Regular app user |
| **Parking Operator** | `UserRole.parkingOperator` | Parking lot owner/manager |
| **Admin** | `admin` (Firestore field) | Platform administrator |

### 6.2 Permissions Matrix

| Feature | Customer | Parking Operator | Admin |
|---|---|---|---|
| Browse/search parking spots | ✅ | ✅ | ✅ |
| Book parking spots | ✅ | ✅ | ✅ |
| Manage own vehicles | ✅ | ✅ | ✅ |
| Manage wallet | ✅ | ✅ | ✅ |
| Submit partner request | ✅ | ❌ | ❌ |
| Add/edit parking spots | ❌ | ✅ (own) | ✅ (all) |
| View own bookings | ✅ | ✅ | ✅ |
| View all bookings | ❌ | ✅ (own spots) | ✅ |
| Access admin dashboard | ❌ | ✅ | ✅ |
| Manage users | ❌ | ❌ | ✅ |
| View revenue analytics | ❌ | ✅ (own) | ✅ |

### 6.3 Access Control (Admin App)

`SimpleAuthWrapper` in `smart_parking_admin_new/lib/main.dart`:
```dart
if (authProvider.isAdmin || authProvider.isParkingOperator) {
  return const DashboardScreen();  // Grant access
} else {
  return const AccessDeniedScreen();  // Block regular users
}
```

---

## 7. Weather Integration

### 7.1 Architecture

```
OpenWeatherMap API ← WeatherService (Python) ← ParkingRecommender ← Flask API ← Flutter App
                                                                                    ↓
                                                              WeatherService (Dart) ← HomeScreen/DashboardScreen
```

### 7.2 API Used

- **Service**: OpenWeatherMap API (Current Weather Data)
- **Config**: API key set in `AppConfig.openWeatherApiKey` and Python environment
- **Data Retrieved**: Temperature, humidity, weather condition, description, icon, wind speed, UV index, visibility, sunrise/sunset times

### 7.3 Weather Properties

The `WeatherData` class computes:
| Property | Condition | Effect |
|---|---|---|
| `is_raining` | condition in [rain, drizzle, thunderstorm] | Prefer covered/underground |
| `is_hot` | temperature > 35°C | Prefer underground/shaded |
| `is_cold` | temperature < 10°C | Prefer underground |
| `is_poor_visibility` | visibility < 1000m | Prefer secure/well-lit |
| `is_daytime` | current time between sunrise and sunset | Night → prefer secure |

### 7.4 Features Dependent on Weather

1. **Parking Recommendations** — 25% weight in scoring algorithm
2. **Weather Advice** — Human-readable tips ("It's raining! We recommend covered parking")
3. **Preference Auto-Set** — `prefer_covered` auto-enabled when raining or hot
4. **Parking Spot Cards** — Display weather suitability indicators

### 7.5 Impact on Booking

Weather data does **not block** bookings but **influences recommendations**:
- Rain: covered/underground spots score 0.3–0.4 higher; open spots score 0.2 lower
- Open spots with rain get a warning label ("May get wet")
- Hot weather: "Cool underground parking" recommendation
- All recommendations include human-readable `reasons` array

---

## 8. UI & Navigation

### 8.1 Customer App Screens

| Screen | Route | Purpose |
|---|---|---|
| **SplashScreen** | `/splash` | Initial loading + auth state check |
| **LoginScreen** | `/login` | Email/password + Google sign-in |
| **RegisterScreen** | `/register` | New user registration |
| **PasswordResetScreen** | `/password-reset` | Password reset via email |
| **CompleteProfileScreen** | `/complete-profile` | First-time name + phone setup |
| **HomeScreen** | `/home` | Bottom nav container (5 tabs) |
| **DashboardScreen** | — (tab 0) | Welcome, weather, nearby spots, active bookings |
| **BookingHistoryScreen** | `/booking-history` (tab 1) | Past + active bookings list |
| **WalletScreen** | `/wallet` (tab 2) | Balance, add money, transaction history |
| **ParkingMapScreen** | `/parking-map` (tab 3) | Google Maps with parking markers |
| **ProfileScreen** | — (tab 4) | User info, settings, logout |
| **ParkingListScreen** | `/parking-list` | Filtered list of parking spots |
| **ParkingSpotBottomSheet** | — (modal) | Spot detail + book button |
| **BookingConfirmationScreen** | — (push) | Review + confirm booking |
| **QRScannerScreen** | `/scan-qr` | QR code scanner for check-in |
| **ParkingDirectionsScreen** | — (push) | Navigation to parking spot |
| **RateParkingScreen** | — (push) | Post-visit rating + review |
| **ReportIssueScreen** | — (push) | Report parking spot issues |
| **VehicleListScreen** | `/manage-vehicles` | Vehicle CRUD |
| **ChatSupportScreen** | `/chat` | AI chat support |
| **PartnerRequestScreen** | `/partner-request` | Apply to become operator |

### 8.2 Admin App Screens

| Screen | Purpose |
|---|---|
| **LoginScreen** | Admin/operator authentication |
| **AdminSignupScreen** | New admin registration |
| **DashboardScreen** | Stats cards, charts, quick actions |
| **ParkingManagementScreen** | CRUD for parking spots |
| **ParkingSpotDetailScreen** | Single spot view + edit |
| **AddParkingSpotScreen** | New spot creation form |
| **BookingManagementScreen** | All bookings with filters |
| **BookingDetailsScreen** | Single booking view |
| **UserManagementScreen** | All users with role management |
| **UserDetailScreen** | Single user profile view |
| **RevenueScreen** | Revenue analytics + charts |
| **SettingsScreen** | App configuration |

### 8.3 Navigation Architecture

**Customer App**: Bottom navigation with 5 tabs using `IndexedStack` for state preservation:
```
Home → [Dashboard, History, Wallet, Map, Profile]
```

**Admin App**: Responsive sidebar navigation adapting to screen size:
```
Desktop: Fixed sidebar + content area
Tablet: Collapsible sidebar
Mobile: Bottom navigation / Drawer
```

---

## 9. Problems Addressed & Solutions

### 9.1 Race Condition Prevention

**Problem**: Two users booking the last available slot simultaneously.

**Solution**: Firestore transactions with all-reads-before-writes pattern. The transaction re-reads the spot document, checks `availableSpots > 0` and overlapping booking count, then atomically decrements. If another transaction committed first, Firestore retries (up to 3 attempts).

### 9.2 Real-Time Sync Between Apps

**Problem**: Admin updates spot availability, but customer app shows stale data.

**Solution**: Firestore snapshot streams (`parkingSpots` collection). Both apps subscribe to real-time updates. `ParkingProvider._processSpotUpdates()` diffs incoming data against cache and only triggers rebuild if `availableSpots`, `status`, or `pricePerHour` changed.

### 9.3 Notification During Build

**Problem**: `notifyListeners()` called during widget build causes Flutter framework error.

**Solution**: `BookingProvider._safeNotifyListeners()` uses `SchedulerBinding.instance.addPostFrameCallback()` to defer notifications to the next frame. `_notifyListenersDebounced()` adds 50ms debounce to batch rapid updates.

### 9.4 No-Show Management

**Problem**: Users book but never show up, blocking spots for others.

**Solution**: `autoCancelNoShows()` auto-cancels bookings 15 minutes after start time if no check-in. Runs on every `loadUserBookings()` call.

### 9.5 Overtime Overstay

**Problem**: Users stay past their booking end time.

**Solution**: Check-out calculates overtime fee at 1.5× the hourly rate for any time past `endTime`.

### 9.6 Geo-Query Failures

**Problem**: GeoFlutterFire+ geo-queries can fail due to missing `position.geopoint` field.

**Solution**: `ParkingProvider.startStreamingNearby()` catches errors and falls back to `_startFallbackStream()` which loads all spots ordered by `createdAt` (no geo-filtering).

### 9.7 UI Rebuild Storms

**Problem**: Frequent Firestore updates cause excessive widget rebuilds.

**Solution**: Multiple layers of protection:
- `_processSpotUpdates()` compares new vs cached data; skips notify if unchanged
- `_notifyListenersDebounced()` uses 16ms debounce (one frame)
- `_filterDebounce` adds 50ms debounce on filter operations

### 9.8 Profile Incompleteness

**Problem**: Google Sign-In users lack phone number; app features require it.

**Solution**: `AuthProvider.isProfileComplete` getter checks `displayName != 'New User'` and `phoneNumber != null`. `CompleteProfileScreen` is shown before granting full access.

---

## 10. Dependencies

### 10.1 Customer App (`smart_parking_app/pubspec.yaml`)

| Package | Version | Purpose |
|---|---|---|
| `flutter` | SDK | Core framework |
| `firebase_core` | ^3.13.0 | Firebase initialization |
| `firebase_auth` | ^5.5.3 | Authentication |
| `cloud_firestore` | ^5.6.7 | NoSQL database |
| `firebase_storage` | ^12.4.4 | File storage |
| `firebase_messaging` | ^15.2.4 | Push notifications |
| `provider` | ^6.1.2 | State management |
| `google_sign_in` | ^6.2.2 | Google authentication |
| `google_maps_flutter` | ^2.10.0 | Map rendering |
| `geolocator` | ^13.0.2 | GPS location |
| `geoflutterfire_plus` | ^0.0.32 | Geo-spatial Firestore queries |
| `geocoding` | ^3.0.0 | Address ↔ coordinates conversion |
| `qr_code_scanner` | ^1.0.1 | QR code scanning |
| `qr_flutter` | ^4.1.0 | QR code generation |
| `pdf` | ^3.11.2 | PDF generation |
| `printing` | ^5.13.4 | PDF preview/print/share |
| `path_provider` | ^2.1.5 | File system paths |
| `flutter_local_notifications` | ^18.0.1 | Local push notifications |
| `timezone` | ^0.10.0 | Timezone handling |
| `image_picker` | ^1.1.2 | Camera/gallery image selection |
| `cached_network_image` | ^3.4.1 | Image caching |
| `flutter_rating_bar` | ^4.0.1 | Star rating widget |
| `intl` | ^0.20.1 | Date/number formatting |
| `url_launcher` | ^6.3.1 | Open external URLs |
| `share_plus` | ^10.1.4 | Share content |
| `permission_handler` | ^11.3.1 | Runtime permissions |
| `shimmer` | ^3.0.0 | Loading placeholder effect |
| `carousel_slider` | ^5.0.0 | Image carousel |
| `smooth_page_indicator` | ^1.2.0+3 | Page indicator dots |

### 10.2 Admin App (`smart_parking_admin_new/pubspec.yaml`)

| Package | Version | Purpose |
|---|---|---|
| `responsive_framework` | ^1.5.1 | Responsive layouts (mobile/tablet/desktop) |
| `fl_chart` | ^0.70.2 | Charts and graphs for analytics |
| `data_table_2` | ^2.5.15 | Enhanced data tables |
| `file_picker` | ^8.1.6 | File selection for uploads |
| `flutter_dropzone` | ^4.0.3 | Drag-and-drop file upload |
| *(plus all Firebase packages above)* | | |

### 10.3 Python ML Backend (`python_models/requirements.txt`)

| Package | Purpose |
|---|---|
| `flask` + `flask-cors` | REST API server |
| `opencv-python` | Image processing for plate detection |
| `ultralytics` | YOLOv8 object detection |
| `easyocr` | Optical character recognition |
| `numpy` | Numerical operations |
| `scikit-learn` + `joblib` | ML model training/loading |
| `requests` | HTTP client (weather API) |
| `firebase-admin` | Firebase integration |

---

## 11. Build & Deployment

### 11.1 Prerequisites

- Flutter SDK ≥ 3.6.1 (Dart ≥ 3.6.1)
- Node.js ≥ 16 (for Firebase CLI and setup scripts)
- Python ≥ 3.8 (for ML backend)
- Firebase CLI (`npm install -g firebase-tools`)
- Google Maps API key
- OpenWeatherMap API key

### 11.2 Firebase Setup

1. **Create Firebase Project** at [Firebase Console](https://console.firebase.google.com)

2. **Enable Services:**
   - Authentication → Enable Email/Password, Google, Phone
   - Cloud Firestore → Create database (production mode)
   - Storage → Enable

3. **Deploy Security Rules:**
   ```bash
   firebase deploy --only firestore:rules
   firebase deploy --only storage
   ```

4. **Deploy Firestore Indexes:**
   ```bash
   firebase deploy --only firestore:indexes
   ```

5. **Create Admin User:**
   ```bash
   npm install
   node setup_admin.js
   ```

6. **Populate Sample Parking Data:**
   ```bash
   node populate_parking.js
   ```

### 11.3 Customer App

1. **Configure API Keys** in `lib/config/app_config.dart`:
   ```dart
   static const String googleMapsApiKey = 'YOUR_KEY';
   static const String openWeatherApiKey = 'YOUR_KEY';
   ```

2. **Configure Firebase:**
   ```bash
   cd smart_parking_app
   flutterfire configure
   ```

3. **Install Dependencies:**
   ```bash
   flutter pub get
   ```

4. **Run:**
   ```bash
   flutter run
   ```

5. **Build APK:**
   ```bash
   flutter build apk --release
   ```

### 11.4 Admin Panel

1. **Configure Firebase:**
   ```bash
   cd smart_parking_admin_new
   flutterfire configure
   ```

2. **Install & Run:**
   ```bash
   flutter pub get
   flutter run -d chrome    # Web
   flutter run -d macos     # Desktop
   ```

3. **Build for Web Hosting:**
   ```bash
   flutter build web
   firebase deploy --only hosting
   ```

### 11.5 Python ML Backend

1. **Install Dependencies:**
   ```bash
   cd python_models
   pip install -r requirements.txt
   ```

2. **Set Environment Variables:**
   ```bash
   export FIREBASE_CREDENTIALS_PATH=/path/to/serviceAccountKey.json
   export OPENWEATHER_API_KEY=your_key
   export FLASK_DEBUG=false
   ```

3. **Run Server:**
   ```bash
   python api_server.py
   ```
   Server starts at `http://0.0.0.0:5000`

---

## 12. Full Feature Table

| # | Feature | Status | Component | Key Files |
|---|---|---|---|---|
| 1 | Email/Password Auth | ✅ Working | Customer App | `auth_provider.dart`, `login_screen.dart` |
| 2 | Google Sign-In | ✅ Working | Customer App | `auth_provider.dart` |
| 3 | Phone OTP Verification | ✅ Working | Customer App | `auth_provider.dart` |
| 4 | Profile Management | ✅ Working | Customer App | `profile_screen.dart`, `complete_profile_screen.dart` |
| 5 | Password Reset | ✅ Working | Customer App | `password_reset_screen.dart` |
| 6 | Account Deletion | ✅ Working | Customer App | `auth_provider.dart` |
| 7 | Real-Time Parking Map | ✅ Working | Customer App | `parking_map_screen.dart`, `parking_provider.dart` |
| 8 | Geo-Radius Search | ✅ Working | Customer App | `parking_provider.dart` (GeoFlutterFire+) |
| 9 | Parking List View | ✅ Working | Customer App | `parking_list_screen.dart` |
| 10 | Multi-Filter System | ✅ Working | Customer App | `filter_bar.dart`, `parking_provider.dart` |
| 11 | Sorting (Distance/Price/Rating) | ✅ Working | Customer App | `parking_provider.dart` |
| 12 | Parking Spot Detail | ✅ Working | Customer App | `parking_spot_bottom_sheet.dart` |
| 13 | Atomic Booking Creation | ✅ Working | Customer App | `database_service.dart`, `booking_provider.dart` |
| 14 | Sequential Booking IDs | ✅ Working | Customer App | `database_service.dart` |
| 15 | Booking Cancellation + Refund | ✅ Working | Customer App | `database_service.dart`, `booking_provider.dart` |
| 16 | QR Code Check-In | ✅ Working | Customer App | `qr_scanner_screen.dart`, `booking_provider.dart` |
| 17 | Geofencing Validation | ✅ Working | Customer App | `booking_provider.dart` (100m radius) |
| 18 | ANPR Check-In/Out | ✅ Working | Python API | `plate_detector.py`, `api_server.py` |
| 19 | Overtime Fee Calculation | ✅ Working | Both | `booking_provider.dart`, `api_server.py` |
| 20 | Auto-Cancel No-Shows | ✅ Working | Customer App | `booking_provider.dart` |
| 21 | Booking History | ✅ Working | Customer App | `booking_history_screen.dart` |
| 22 | Booking Confirmation Screen | ✅ Working | Customer App | `booking_confirmation_screen.dart` |
| 23 | Digital Wallet | ✅ Working | Customer App | `wallet_provider.dart`, `wallet_screen.dart` |
| 24 | Add Money (UPI/Card/NetBanking) | ✅ Working | Customer App | `wallet_provider.dart` |
| 25 | Wallet Payment | ✅ Working | Customer App | `wallet_provider.dart` |
| 26 | Vehicle Management (CRUD) | ✅ Working | Customer App | `vehicle_provider.dart`, `vehicle_list_screen.dart` |
| 27 | Default Vehicle Selection | ✅ Working | Customer App | `vehicle_provider.dart` |
| 28 | PDF Receipt Generation | ✅ Working | Customer App | `pdf_service.dart`, `pdf_manager.dart` |
| 29 | Batch Receipt Export | ✅ Working | Customer App | `pdf_manager.dart` |
| 30 | Push Notifications | ✅ Working | Customer App | `notification_service.dart` |
| 31 | Scheduled Reminders | ✅ Working | Customer App | `booking_provider.dart` |
| 32 | Weather Display | ✅ Working | Both | `weather_service.dart`, `recommender.py` |
| 33 | Weather-Based Recommendations | ✅ Working | Python API | `recommender.py`, `api_server.py` |
| 34 | Weather Parking Advice | ✅ Working | Python API | `recommender.py` |
| 35 | Parking Directions | ✅ Working | Customer App | `parking_directions_screen.dart` |
| 36 | Route Options | ✅ Working | Customer App | `routing_provider.dart` |
| 37 | Rate Parking Spot | ✅ Working | Customer App | `rate_parking_screen.dart` |
| 38 | Report Issue | ✅ Working | Customer App | `report_issue_screen.dart` |
| 39 | AI Chat Support | ✅ Working | Customer App | `chat_support_screen.dart` |
| 40 | Partner Request System | ✅ Working | Customer App | `partner_request_screen.dart` |
| 41 | Admin Dashboard + Stats | ✅ Working | Admin App | `dashboard_screen.dart` |
| 42 | Admin Parking CRUD | ✅ Working | Admin App | `parking_management_screen.dart` |
| 43 | Admin Booking Management | ✅ Working | Admin App | `booking_management_screen.dart` |
| 44 | Admin User Management | ✅ Working | Admin App | `user_management_screen.dart` |
| 45 | Revenue Analytics | ✅ Working | Admin App | `revenue_screen.dart` |
| 46 | Responsive Admin Layout | ✅ Working | Admin App | `responsive_framework` |
| 47 | Firestore Security Rules | ✅ Deployed | Firebase | `firestore.rules` |
| 48 | Storage Security Rules | ✅ Deployed | Firebase | `storage.rules` |
| 49 | Firestore Indexes | ✅ Deployed | Firebase | `firestore.indexes.json` |
| 50 | Sample Data Seeder | ✅ Working | Scripts | `populate_parking.js` |
| 51 | Admin User Setup | ✅ Working | Scripts | `setup_admin.js` |
| 52 | Number Plate Detection API | ✅ Working | Python API | `plate_detector.py` |
| 53 | Health Check Endpoint | ✅ Working | Python API | `api_server.py` |

---

> **Document generated**: February 2026
> **Repository**: [github.com/kalyan1421/Smart-Parking](https://github.com/kalyan1421/Smart-Parking)
> **Project ID**: `smart-parking-kalyan-2024`
