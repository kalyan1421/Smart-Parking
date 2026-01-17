
// lib/config/routes.dart - App routes
import 'package:flutter/material.dart';
import 'package:smart_parking_app/screens/auth/login_screen.dart';
import 'package:smart_parking_app/screens/auth/register_screen.dart';
import 'package:smart_parking_app/screens/auth/password_reset_screen.dart';
import 'package:smart_parking_app/screens/auth/complete_profile_screen.dart';
import 'package:smart_parking_app/screens/home/home_screen.dart';
import 'package:smart_parking_app/screens/maps/map_screen.dart';
import 'package:smart_parking_app/screens/parking/parking_map_screen.dart';
import 'package:smart_parking_app/screens/parking/parking_list_screen.dart';
import 'package:smart_parking_app/screens/profile/booking_history_screen.dart';
import 'package:smart_parking_app/screens/profile/profile_screen.dart';
import 'package:smart_parking_app/screens/profile/vehicles/vehicle_list_screen.dart';
import 'package:smart_parking_app/screens/wallet/wallet_screen.dart';
import 'package:smart_parking_app/screens/chat/chat_support_screen.dart';
import 'package:smart_parking_app/screens/parking/qr_scanner_screen.dart';
import 'package:smart_parking_app/screens/profile/partner_request_screen.dart';

class AppRoutes {
  // Auth Routes
  static const String login = '/login';
  static const String register = '/register';
  static const String passwordReset = '/password-reset';
  static const String completeProfile = '/complete-profile';
  
  // Home Routes
  static const String home = '/home';
  
  // Map Routes
  static const String map = '/map';
  
  // Parking Routes
  static const String parkingmap = '/parking-map';
  static const String parkingList = '/parking-list';
  static const String parkingDetail = '/parking-detail';
  static const String scanQr = '/scan-qr';
  
  // Profile Routes
  static const String bookingHistory = '/booking-history';
  static const String manageVehicles = '/manage-vehicles';
  static const String partnerRequest = '/partner-request';
  
  // Other Routes
  static const String wallet = '/wallet';
  static const String chat = '/chat';
  
  static Map<String, WidgetBuilder> get routes => {
    // Auth Routes
    login: (context) => LoginScreen(),
    register: (context) => RegisterScreen(),
    passwordReset: (context) => PasswordResetScreen(),
    completeProfile: (context) => CompleteProfileScreen(),
    
    // Home Routes
    home: (context) => HomeScreen(),
    
    // Map Routes
    map: (context) => MapScreen(),
    
    // Parking Routes
    parkingmap: (context) => ParkingMapScreen(),
    parkingList: (context) => ParkingListScreen(),
    scanQr: (context) => QRScannerScreen(),
    
    // Profile Routes
    bookingHistory: (context) => BookingHistoryScreen(),
    manageVehicles: (context) => VehicleListScreen(),
    partnerRequest: (context) => PartnerRequestScreen(),
    
    // Other Routes
    wallet: (context) => WalletScreen(),
    chat: (context) => ChatSupportScreen(),
  };
}