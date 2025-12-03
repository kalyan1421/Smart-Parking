// lib/config/app_config.dart
import 'package:flutter/material.dart';

class AppConfig {
  static const String appName = 'Smart Parking Admin';
  static const String version = '1.0.0';
  
  // Firebase configuration
  static const String projectId = 'smart-parking-kalyan-2024';
  
  // Pagination
  static const int defaultPageSize = 50;
  
  // Theme colors
  static const Map<String, dynamic> colors = {
    'primary': 0xFF2196F3,
    'primaryDark': 0xFF1976D2,
    'accent': 0xFFFF9800,
    'success': 0xFF4CAF50,
    'warning': 0xFFFF9800,
    'error': 0xFFF44336,
    'background': 0xFFF5F5F5,
    'surface': 0xFFFFFFFF,
    'onPrimary': 0xFFFFFFFF,
    'onSurface': 0xFF212121,
  };
  
  // Color getters
  static Color get primaryColor => Color(colors['primary']);
  
  // Feature flags
  static const Map<String, bool> features = {
    'enableRevenueTracking': true,
    'enableUserManagement': true,
    'enableParkingSpotVerification': true,
    'enableBookingModification': true,
    'enableExcelExport': true,
    'enablePDFGeneration': true,
  };
  
  // API endpoints (if needed)
  static const Map<String, String> endpoints = {
    'notifications': '/api/notifications',
    'reports': '/api/reports',
    'analytics': '/api/analytics',
  };
  
  // Default values
  static const Map<String, dynamic> defaults = {
    'parkingSpotPricePerHour': 5.0,
    'maxParkingSpots': 100,
    'bookingCancellationFeePercent': 10,
    'defaultOperatingHours': {
      'monday': {'open': '08:00', 'close': '20:00'},
      'tuesday': {'open': '08:00', 'close': '20:00'},
      'wednesday': {'open': '08:00', 'close': '20:00'},
      'thursday': {'open': '08:00', 'close': '20:00'},
      'friday': {'open': '08:00', 'close': '20:00'},
      'saturday': {'open': '09:00', 'close': '18:00'},
      'sunday': {'open': '09:00', 'close': '18:00'},
    },
  };
}
