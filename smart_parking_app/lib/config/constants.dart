// lib/config/constants.dart
class AppConstants {
  // Collection names
  static const String usersCollection = 'users';
  static const String bookingsCollection = 'bookings';
  static const String parkingSpotsCollection = 'parking_slots';
  static const String vehiclesCollection = 'vehicles';
  static const String notificationsCollection = 'notifications';
  static const String reviewsCollection = 'reviews';
  
  // App constants
  static const String appName = 'Smart Parking';
  static const String appVersion = '1.0.0';
  
  // Default values
  static const double defaultSearchRadius = 2000.0; // meters
  static const int defaultBookingDuration = 2; // hours
  static const double defaultCancellationFeePercentage = 0.1; // 10%
  
  // Map settings
  static const double defaultZoom = 15.0;
  static const double defaultLat = 37.7749;
  static const double defaultLng = -122.4194;
  
  // API Keys (to be replaced with actual keys)
  static const String googleMapsApiKey = 'YOUR_GOOGLE_MAPS_API_KEY';
  static const String openWeatherApiKey = 'YOUR_OPENWEATHER_API_KEY';
  
  // Additional collection names
  static const String trafficDataCollection = 'traffic_data';
  
  // Supported vehicle types
  static const List<String> vehicleTypes = [
    'car',
    'motorcycle',
    'bicycle',
    'electricCar',
    'truck',
    'van',
    'suv'
  ];
  
  // Supported amenities
  static const List<String> parkingAmenities = [
    'covered',
    'electric_charging',
    'security',
    'cctv',
    'disabled_access',
    'car_wash',
    'valet',
    'lighting',
    'elevator',
    '24_7_access'
  ];
}