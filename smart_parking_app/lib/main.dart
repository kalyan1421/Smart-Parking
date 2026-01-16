// lib/main.dart - Firebase-based QuickPark App
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'config/routes.dart';
import 'config/theme.dart';
import 'core/database/database_service.dart';
import 'providers/auth_provider.dart';
import 'providers/booking_provider.dart';
import 'providers/location_provider.dart';
import 'providers/parking_provider.dart';
import 'providers/traffic_provider.dart';
import 'providers/routing_provider.dart';
import 'providers/vehicle_provider.dart';
import 'providers/wallet_provider.dart';
import 'repositories/booking_repository.dart';
import 'screens/auth/login_screen.dart';
import 'screens/home/home_screen.dart';
import 'services/notification_service.dart';
import 'widgets/common/loading_indicator.dart';
import 'screens/auth/complete_profile_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize Firebase services
  await DatabaseService.init();
  
  // Initialize Notification Service
  await NotificationService().init();
  
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        // Core providers
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => LocationProvider()),
        ChangeNotifierProvider(create: (_) => TrafficProvider()),
        ChangeNotifierProvider(create: (_) => RoutingProvider()),
        ChangeNotifierProvider(create: (_) => ParkingProvider()),
        ChangeNotifierProvider(create: (_) => VehicleProvider()),
        ChangeNotifierProvider(create: (_) => WalletProvider()),
        
        // Initialize repositories
        Provider(create: (_) => BookingRepository()),
        
        // Initialize providers that depend on repositories
        ChangeNotifierProxyProvider<BookingRepository, BookingProvider>(
          create: (context) => BookingProvider(context.read<BookingRepository>()),
          update: (context, repository, previous) => previous ?? BookingProvider(repository),
        ),
      ],
      child: MyAppContent(),
    );
  }
}

class MyAppContent extends StatefulWidget {
  @override
  _MyAppContentState createState() => _MyAppContentState();
}

class _MyAppContentState extends State<MyAppContent> {
  bool _initializing = true;
  bool _initialized = false;
  String? _error;
  
  @override
  void initState() {
    super.initState();
    // We use Future.microtask to schedule the initialization after the current build phase
    Future.microtask(() => _initializeApp());
  }
  
  Future<void> _initializeApp() async {
    if (_initialized) return;
    
    try {
      setState(() {
        _initializing = true;
      });
      
      // Initialize auth provider
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      await authProvider.initialize();
      
      // Initialize location provider
      final locationProvider = Provider.of<LocationProvider>(context, listen: false);
      await locationProvider.initialize();
      
      // Initialize traffic provider
      final trafficProvider = Provider.of<TrafficProvider>(context, listen: false);
      await Future.microtask(() => trafficProvider.initializeTrafficOverlay());
      
      setState(() {
        _initializing = false;
        _initialized = true;
        _error = null;
      });
    } catch (e) {
      print('Error initializing app: $e');
      setState(() {
        _initializing = false;
        _initialized = true;
        _error = e.toString();
      });
    }
  }
  
  @override
  Widget build(BuildContext context) {
    // Show loading screen while initializing
    if (_initializing) {
      return MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'QuickPark',
        theme: AppTheme.lightTheme,
        home: Scaffold(
          body: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                LoadingIndicator(),
                SizedBox(height: 16),
                Text('Loading QuickPark...'),
              ],
            ),
          ),
        ),
      );
    }
    
    // Show error screen if initialization failed
    if (_error != null) {
      return MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'QuickPark',
        theme: AppTheme.lightTheme,
        home: Scaffold(
          body: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.error_outline, color: Colors.red, size: 48),
                SizedBox(height: 16),
                Text('Failed to initialize app:'),
                SizedBox(height: 8),
                Text(_error!, style: TextStyle(color: Colors.red)),
                SizedBox(height: 16),
                ElevatedButton(
                  onPressed: _initializeApp,
                  child: Text('Retry'),
                ),
              ],
            ),
          ),
        ),
      );
    }
    
    // App is initialized, show normal content
    return Consumer<AuthProvider>(
      builder: (context, authProvider, _) {
        return MaterialApp(
          debugShowCheckedModeBanner: false,
          title: 'QuickPark',
          theme: AppTheme.lightTheme,
          routes: AppRoutes.routes,
          home: _getHomeScreen(authProvider),
        );
      },
    );
  }

  Widget _getHomeScreen(AuthProvider authProvider) {
    if (!authProvider.isLoggedIn) {
      return LoginScreen();
    }
    
    // If logged in but profile incomplete, show profile completion
    if (!authProvider.isProfileComplete) {
      return CompleteProfileScreen();
    }
    
    // Otherwise show home screen
    return HomeScreen();
  }
}