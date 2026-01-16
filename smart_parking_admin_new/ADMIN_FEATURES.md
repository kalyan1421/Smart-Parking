# Admin and Parking Operator Features

Here is the comprehensive list of Admin and Parking Operator features
implemented in the system:

## 1. Admin Dashboard
* Grid Quick Actions: Icon-based navigation for all management tools.
* Floating Action Button (FAB): Persistent "Scan Booking" button for instant
  entry/exit processing.
* Role-Based View: Dynamic dashboard that adapts based on whether the user is
  a Global Admin or a local Parking Operator.

## 2. QR Entry/Exit System
* Smart Scan Logic: Automatically detects the current state of a booking upon
  scanning.
* Check-In: Validates a customer's reservation and officially starts their
  parking session.
* Check-Out: Ends the session and automatically increments the available spots
  counter for that location in real-time.

## 3. Parking Spot Management
* Add New Spots: Create parking locations with full details (Name, Address,
  Description).
* Live Location Picker: Uses the device GPS to set the exact
  latitude/longitude for the parking pin.
* Capacity Control: Set total slots; the system handles the "Available" count
  automatically based on bookings.
* Pricing Management: Set and update hourly rates.
* Amenity Tags: Toggle features like CCTV, EV Charging, Security, etc.
* Delete/Edit: Full CRUD (Create, Read, Update, Delete) capability for parking
  locations.

## 4. User & Role Management
* Searchable Directory: List all registered users in the system.
* Promotion System: Ability to promote regular users to Parking Operators,
  giving them access to add and manage their own parking slots.

## 5. Booking Oversight
* Master Booking List: View every reservation in the system.
* Status Tracking: Real-time visibility into which bookings are Confirmed,
  Active, Completed, or Cancelled.

## 6. Admin Map View
* Global Overview: A map showing all parking points.
* Availability Heatmap: Points turn Green when spots are available and Red
  when the location is full.

## 7. Security & Automation
* Auto-Redirect: Upon login, the app detects if the user is an Admin/Operator
  and bypasses the customer home screen to open the Admin Dashboard
  immediately.
* Protected Routes: Admin screens are restricted to authorized roles only.
