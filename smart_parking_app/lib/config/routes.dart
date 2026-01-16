
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
import 'package:smart_parking_app/screens/admin/admin_dashboard_screen.dart';
import 'package:smart_parking_app/screens/admin/admin_qr_scanner_screen.dart';
import 'package:smart_parking_app/screens/admin/admin_bookings_screen.dart';
import 'package:smart_parking_app/screens/admin/admin_users_screen.dart';
import 'package:smart_parking_app/screens/admin/manage_parking_spots_screen.dart';
import 'package:smart_parking_app/screens/admin/add_edit_parking_spot_screen.dart';
import 'package:smart_parking_app/models/parking_spot.dart';

class AppRoutes {
  // ... existing routes
  
  // Admin Routes
  static const String adminDashboard = '/admin-dashboard';
  static const String adminScanQr = '/admin-scan-qr';
  static const String adminBookings = '/admin-bookings';
  static const String adminUsers = '/admin-users';
  static const String adminMap = '/admin-map';
  static const String adminManageSpots = '/admin-manage-spots';
  static const String adminAddEditSpot = '/admin-add-edit-spot';
  
  static Map<String, WidgetBuilder> get routes => {
    // ... existing routes
    
    // Admin Routes
    adminDashboard: (context) => AdminDashboardScreen(),
    adminScanQr: (context) => AdminQRScannerScreen(),
    adminBookings: (context) => AdminBookingsScreen(),
    adminUsers: (context) => AdminUsersScreen(),
    adminMap: (context) => AdminMapScreen(),
    adminManageSpots: (context) => ManageParkingSpotsScreen(),
    adminAddEditSpot: (context) {
      final args = ModalRoute.of(context)?.settings.arguments;
      return AddEditParkingSpotScreen(parkingSpot: args as ParkingSpot?);
    },
  };
}