
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

class AppRoutes {
  static const String login = '/login';
  static const String register = '/register';
  static const String passwordReset = '/password-reset';
  static const String completeProfile = '/complete-profile';
  static const String home = '/home';
  static const String map = '/map';
  static const String parkingList = '/parking-list';
  static const String parkingDetail = '/parking-detail';
  static const String bookingHistory = '/booking-history';
  static const String profile = '/profile';
  static const String parkingmap = '/parking_map_screen';
  
  static Map<String, WidgetBuilder> get routes => {
    login: (context) => LoginScreen(),
    register: (context) => RegisterScreen(),
    passwordReset: (context) => PasswordResetScreen(),
    completeProfile: (context) => CompleteProfileScreen(),
    home: (context) => HomeScreen(),
    map: (context) => MapScreen(),
    parkingList: (context) => ParkingListScreen(),
    bookingHistory: (context) => BookingHistoryScreen(),
    profile: (context) => ProfileScreen(),
    parkingmap: (context) => ParkingMapScreen()
  };
}