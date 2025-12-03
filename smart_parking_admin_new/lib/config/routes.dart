// lib/config/routes.dart
import 'package:flutter/material.dart';
import '../screens/auth/login_screen.dart';
import '../screens/auth/admin_signup_screen.dart';
import '../screens/dashboard/dashboard_screen.dart';
import '../screens/parking/parking_management_screen.dart';
import '../screens/parking/parking_map_view_screen.dart';
import '../screens/bookings/booking_management_screen.dart';
import '../screens/users/user_management_screen.dart';

class AppRoutes {
  static const String login = '/login';
  static const String adminSignup = '/admin-signup';
  static const String dashboard = '/dashboard';
  static const String parkingManagement = '/parking';
  static const String parkingMapView = '/parking-map';
  static const String bookingManagement = '/bookings';
  static const String userManagement = '/users';

  static Map<String, WidgetBuilder> get routes {
    return {
      login: (context) => const LoginScreen(),
      adminSignup: (context) => const AdminSignupScreen(),
      dashboard: (context) => const DashboardScreen(),
      parkingManagement: (context) => const ParkingManagementScreen(),
      parkingMapView: (context) => const ParkingMapViewScreen(),
      bookingManagement: (context) => const BookingManagementScreen(),
      userManagement: (context) => const UserManagementScreen(),
    };
  }

  static Route<dynamic>? onGenerateRoute(RouteSettings settings) {
    switch (settings.name) {
      case login:
        return MaterialPageRoute(builder: (context) => const LoginScreen());
      case adminSignup:
        return MaterialPageRoute(builder: (context) => const AdminSignupScreen());
      case dashboard:
        return MaterialPageRoute(builder: (context) => const DashboardScreen());
      case parkingManagement:
        return MaterialPageRoute(builder: (context) => const ParkingManagementScreen());
      case parkingMapView:
        return MaterialPageRoute(builder: (context) => const ParkingMapViewScreen());
      case bookingManagement:
        return MaterialPageRoute(builder: (context) => const BookingManagementScreen());
      case userManagement:
        return MaterialPageRoute(builder: (context) => const UserManagementScreen());
      default:
        return MaterialPageRoute(
          builder: (context) => Scaffold(
            appBar: AppBar(title: const Text('Page Not Found')),
            body: const Center(
              child: Text('404 - Page Not Found'),
            ),
          ),
        );
    }
  }
}
