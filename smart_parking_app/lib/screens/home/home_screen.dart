// lib/screens/home/home_screen.dart - Home screen with bottom navigation
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:smart_parking_app/providers/auth_provider.dart';
import 'package:smart_parking_app/providers/location_provider.dart';
import 'package:smart_parking_app/screens/home/dashboard_screen.dart';
import 'package:smart_parking_app/screens/maps/map_screen.dart';
import 'package:smart_parking_app/screens/parking/parking_map_screen.dart';
import 'package:smart_parking_app/screens/parking/parking_list_screen.dart';
import 'package:smart_parking_app/screens/profile/profile_screen.dart';
import 'package:smart_parking_app/widgets/common/loading_indicator.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;
  final List<Widget> _pages = [
    DashboardScreen(),
    MapScreen(),
    ParkingListScreen(),
    ProfileScreen(),
  ];
  
  @override
  void initState() {
    super.initState();
     WidgetsBinding.instance.addPostFrameCallback((_) {
    _initializeProviders();
  });
  }
  
  Future<void> _initializeProviders() async {
    final locationProvider = Provider.of<LocationProvider>(context, listen: false);
    
    // Initialize location service
    if (!locationProvider.hasLocation) {
      await locationProvider.getCurrentLocation();
    }
  }
  
  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final locationProvider = Provider.of<LocationProvider>(context);
    
    // Check if user is logged in
    if (authProvider.currentUser == null) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              LoadingIndicator(),
              SizedBox(height: 16),
              Text('Loading your profile...'),
            ],
          ),
        ),
      );
    }
    
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: _pages,
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        type: BottomNavigationBarType.fixed,
        selectedItemColor: Theme.of(context).primaryColor,
        unselectedItemColor: Colors.grey,
        items: [
          BottomNavigationBarItem(
            icon: Icon(Icons.dashboard),
            label: 'Dashboard',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.map),
            label: 'Map',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.local_parking),
            label: 'Bookings',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}