// lib/config/app_config.dart
class AppConfig {
  // API Keys
  static const String googleMapsApiKey = 'YOUR_GOOGLE_MAPS_API_KEY';
  static const String openWeatherApiKey = 'YOUR_OPENWEATHER_API_KEY';
  
  // Firebase Configuration
  static const String firebaseProjectId = 'smart-parking-app';
  
  // App Information
  static const String appName = 'Smart Parking';
  static const String appVersion = '1.0.0';
  
  // App Settings
  static const int bookingCancellationTimeLimit = 60; // Minutes before start time
  static const double defaultSearchRadius = 2000; // In meters
  static const int maxBookingDurationHours = 24;
  static const int maxAdvanceBookingDays = 30; // Up to 30 days in advance
  
  // Payment Settings
  static const bool enabledPayments = true; // Toggle payment functionality
  static const String currencySymbol = '₹';
  static const double cancellationFeePercentage = 0.1; // 10% cancellation fee
  
  // Notifications
  static const bool enablePushNotifications = true;
  static const bool enableLocationBasedNotifications = true;
  
  // Feature Flags
  static const bool enableElectricVehicleFiltering = true;
  static const bool enableAccessibilityFeatures = true;
  static const bool enableRealTimeUpdates = true;
  static const bool enableWeatherIntegration = true;
  static const bool enableTrafficIntegration = true;
  
  // User Roles
  static const String roleUser = 'user';
  static const String roleParkingOperator = 'parking_operator';
  static const String roleAdmin = 'admin';
  
  // Vehicle Types
  static const List<String> vehicleTypes = [
    'car',
    'motorcycle',
    'bicycle',
    'electric_car',
    'truck',
    'van'
  ];
  
  // Parking Spot Amenities
  static const List<String> parkingAmenities = [
    'covered',
    'electric_charging',
    'security',
    'cctv',
    'disabled_access',
    'car_wash',
    'valet'
  ];
}