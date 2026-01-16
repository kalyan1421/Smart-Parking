// lib/screens/home/dashboard_screen.dart - Enhanced Dashboard screen
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:provider/provider.dart';
import 'package:smart_parking_app/config/app_config.dart';
import 'package:smart_parking_app/config/routes.dart';
import 'package:smart_parking_app/models/booking.dart';
import 'package:smart_parking_app/models/parking_spot.dart';
import 'package:smart_parking_app/models/traffic_bot.dart';
import 'package:smart_parking_app/providers/auth_provider.dart';
import 'package:smart_parking_app/providers/booking_provider.dart';
import 'package:smart_parking_app/providers/location_provider.dart';
import 'package:smart_parking_app/providers/parking_provider.dart';
import 'package:smart_parking_app/providers/traffic_provider.dart';
import 'package:smart_parking_app/screens/parking/id_generator.dart';
import 'package:smart_parking_app/screens/parking/parking_directions_screen.dart';
import 'package:smart_parking_app/services/pdf_service.dart';
import 'package:smart_parking_app/services/weather_service.dart';
import 'package:smart_parking_app/widgets/common/loading_indicator.dart';
import 'package:intl/intl.dart';

class DashboardScreen extends StatefulWidget {
  @override
  _DashboardScreenState createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  bool _isInitialized = false;
  GoogleMapController? _mapController;
  final Set<Marker> _markers = {};
  Set<Circle> _trafficHotspots = {};
  String _trafficCondition = 'Unknown';
  Color _trafficColor = Colors.grey;
  WeatherData? _weatherData;
  bool _isLoadingWeather = false;
  
  @override
  void initState() {
    super.initState();
    _loadData();
  }
  
  @override
  void dispose() {
    _mapController?.dispose();
    super.dispose();
  }
  
  Future<void> _loadData() async {
    if (mounted) {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final locationProvider = Provider.of<LocationProvider>(context, listen: false);
      final bookingProvider = Provider.of<BookingProvider>(context, listen: false);
      final parkingProvider = Provider.of<ParkingProvider>(context, listen: false);
      final trafficProvider = Provider.of<TrafficProvider>(context, listen: false);
      
      // Initialize location if needed
      if (!locationProvider.hasLocation) {
        await locationProvider.getCurrentLocation();
      }
      
      // Initialize traffic overlay
      if (!trafficProvider.isOverlaySetup) {
        await Future.microtask(() => trafficProvider.initializeTrafficOverlay());
      }
      
      // Load active bookings for user
      if (authProvider.currentUser != null) {
        await bookingProvider.loadActiveBookings(authProvider.currentUser!.id);
      }
      
      // Load nearby parking spots
      if (locationProvider.hasLocation) {
        await parkingProvider.findNearbyParkingSpots(
          locationProvider.currentLocation!.latitude,
          locationProvider.currentLocation!.longitude,
          radius: AppConfig.defaultSearchRadius
        );
      }
      
      // Load traffic data
      if (locationProvider.hasLocation) {
        await trafficProvider.loadTrafficData(
          locationProvider.currentLocation!.latitude,
          locationProvider.currentLocation!.longitude,
          2.0 // 2 km radius
        );
        
        // Create traffic hotspots visualization
        _createTrafficHotspots(trafficProvider);
        
        // Analyze overall traffic condition
        _analyzeTrafficCondition(trafficProvider);
        
        // Load weather data
        _loadWeather(locationProvider.currentLocation!.latitude, locationProvider.currentLocation!.longitude);
      }
      
      setState(() {
        _isInitialized = true;
      });
    }
  }
  
  void _createTrafficHotspots(TrafficProvider trafficProvider) {
    final hotspots = <Circle>{};
    
    for (final bot in trafficProvider.trafficBots) {
      Color color;
      double radius;
      
      switch (bot.trafficLevel) {
        case TrafficLevel.low:
          color = Colors.green;
          radius = 100.0;
          break;
        case TrafficLevel.medium:
          color = Colors.orange;
          radius = 150.0;
          break;
        case TrafficLevel.high:
          color = Colors.red;
          radius = 200.0;
          break;
        case TrafficLevel.severe:
          color = Colors.purple;
          radius = 250.0;
          break;
        default:
          color = Colors.blue;
          radius = 100.0;
      }
      
      hotspots.add(Circle(
        circleId: CircleId(bot.id),
        center: LatLng(bot.latitude, bot.longitude),
        radius: radius,
        fillColor: color.withOpacity(0.2),
        strokeColor: color,
        strokeWidth: 1,
      ));
    }
    
    setState(() {
      _trafficHotspots = hotspots;
    });
  }
  
  void _analyzeTrafficCondition(TrafficProvider trafficProvider) {
    // ... (rest of the method)
  }

  Future<void> _loadWeather(double lat, double lon) async {
    setState(() {
      _isLoadingWeather = true;
    });
    try {
      final weatherService = WeatherService();
      final data = await weatherService.getCurrentWeather(lat, lon);
      setState(() {
        _weatherData = data;
        _isLoadingWeather = false;
      });
    } catch (e) {
      print('Error loading weather: $e');
      setState(() {
        _isLoadingWeather = false;
      });
    }
  }
  
  void _onMapCreated(GoogleMapController controller) {
    setState(() {
      _mapController = controller;
    });
    
    _centerOnUserLocation();
    _addMarkersToMap();
  }
  
  void _centerOnUserLocation() {
    final locationProvider = Provider.of<LocationProvider>(context, listen: false);
    
    if (locationProvider.hasLocation && _mapController != null) {
      _mapController!.animateCamera(CameraUpdate.newLatLngZoom(
        LatLng(
          locationProvider.currentLocation!.latitude,
          locationProvider.currentLocation!.longitude
        ),
        14.0
      ));
    }
  }
  
  void _addMarkersToMap() {
    final locationProvider = Provider.of<LocationProvider>(context, listen: false);
    final parkingProvider = Provider.of<ParkingProvider>(context, listen: false);
    final bookingProvider = Provider.of<BookingProvider>(context, listen: false);
    
    final markers = <Marker>{};
    
    // Add user location marker
    if (locationProvider.hasLocation) {
      markers.add(Marker(
        markerId: MarkerId('user_location'),
        position: LatLng(
          locationProvider.currentLocation!.latitude,
          locationProvider.currentLocation!.longitude
        ),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
        infoWindow: InfoWindow(title: 'Your Location'),
      ));
    }
    
    // Add markers for active booking locations
    for (final booking in bookingProvider.activeBookings) {
      markers.add(Marker(
        markerId: MarkerId('booking_${booking.id}'),
        position: LatLng(booking.latitude, booking.longitude),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
        infoWindow: InfoWindow(
          title: booking.parkingSpotName,
          snippet: 'Your active booking',
        ),
      ));
    }
    
    // Add markers for nearby parking (limited to 5 to avoid cluttering)
    final nearbySpots = parkingProvider.nearbyParkingSpots.take(5).toList();
    for (final spot in nearbySpots) {
      // Skip if this spot is already booked by the user
      if (bookingProvider.activeBookings.any((b) => b.parkingSpotId == spot.id)) {
        continue;
      }
      
      markers.add(Marker(
        markerId: MarkerId('parking_${spot.id}'),
        position: LatLng(spot.latitude, spot.longitude),
        icon: BitmapDescriptor.defaultMarkerWithHue(
          spot.availableSpots > 0 ? BitmapDescriptor.hueYellow : BitmapDescriptor.hueRed
        ),
        infoWindow: InfoWindow(
          title: spot.name,
          snippet: '${spot.availableSpots} spots • ${AppConfig.currencySymbol}${spot.pricePerHour.toStringAsFixed(2)}/hr',
        ),
      ));
    }
    
    setState(() {
      _markers.clear();
      _markers.addAll(markers);
    });
  }
  
  Widget _buildActiveBookingCard(Booking booking) {
    final durationMinutes = booking.endTime.difference(DateTime.now()).inMinutes;
    final hours = durationMinutes ~/ 60;
    final minutes = durationMinutes % 60;
    
    final timeRemaining = hours > 0 
        ? '${hours}h ${minutes > 0 ? '${minutes}m' : ''} remaining' 
        : minutes > 0 
            ? '${minutes}m remaining' 
            : 'Expires soon';
    
    // Create parking spot object for directions
    final parkingSpot = ParkingSpot(
      id: booking.parkingSpotId,
      name: booking.parkingSpotName,
      description: 'Booked parking spot',
      address: '', // Not available from booking
      latitude: booking.latitude,
      longitude: booking.longitude,
      totalSpots: 0,
      availableSpots: 0,
      pricePerHour: booking.totalPrice / (booking.endTime.difference(booking.startTime).inHours == 0 ? 1 : booking.endTime.difference(booking.startTime).inHours),
      amenities: [],
      operatingHours: {},
      vehicleTypes: ['car'],
      ownerId: '',
      geoPoint: null,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
      isVerified: true,
    );
    
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    booking.parkingSpotName,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.green.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    'ACTIVE',
                    style: TextStyle(
                      color: Colors.green,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: 12),
            Row(
              children: [
                Icon(Icons.access_time, size: 16, color: Colors.grey[600]),
                SizedBox(width: 4),
                Text(
                  timeRemaining,
                  style: TextStyle(
                    color: durationMinutes < 30 ? Colors.red : Colors.grey[600],
                    fontWeight: durationMinutes < 30 ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
              ],
            ),
            SizedBox(height: 6),
            Row(
              children: [
                Icon(Icons.calendar_today, size: 16, color: Colors.grey[600]),
                SizedBox(width: 4),
                Text(
                  '${DateFormat('MMM d').format(booking.startTime)} • ${DateFormat('h:mm a').format(booking.startTime)} - ${DateFormat('h:mm a').format(booking.endTime)}',
                  style: TextStyle(color: Colors.grey[600]),
                ),
              ],
            ),
            SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => ParkingDirectionsScreen(
                            parkingSpot: parkingSpot,
                          ),
                        ),
                      );
                    },
                    icon: Icon(Icons.directions),
                    label: Text('DIRECTIONS'),
                    style: OutlinedButton.styleFrom(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ),
                SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.pushNamed(context, AppRoutes.bookingHistory);
                    },
                    icon: Icon(Icons.visibility),
                    label: Text('DETAILS'),
                    style: ElevatedButton.styleFrom(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildNearbyParkingItem(ParkingSpot spot) {
    return ListTile(
      title: Text(spot.name),
      subtitle: Text(
        '${spot.availableSpots} spots • ${AppConfig.currencySymbol}${spot.pricePerHour.toStringAsFixed(2)}/hr',
      ),
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: spot.availableSpots > 0 ? Colors.green.withOpacity(0.1) : Colors.red.withOpacity(0.1),
          shape: BoxShape.circle,
        ),
        child: Icon(
          Icons.local_parking,
          color: spot.availableSpots > 0 ? Colors.green : Colors.red,
        ),
      ),
      trailing: Container(
        width: 40,
        padding: EdgeInsets.symmetric(vertical: 4),
        decoration: BoxDecoration(
          color: spot.availableSpots > 0 ? Colors.green : Colors.red,
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(
          spot.availableSpots > 0 ? 'OPEN' : 'FULL',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 10,
          ),
        ),
      ),
      onTap: () {
        Navigator.pushNamed(context, AppRoutes.parkingDetail);
      },
    );
  }
  
  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final bookingProvider = Provider.of<BookingProvider>(context);
    final parkingProvider = Provider.of<ParkingProvider>(context);
    final locationProvider = Provider.of<LocationProvider>(context);
    final trafficProvider = Provider.of<TrafficProvider>(context);
    
    // Prepare tile overlays
    Set<TileOverlay> tileOverlays = {};
    if (trafficProvider.isOverlaySetup && 
        trafficProvider.trafficOverlay != null &&
        trafficProvider.showTrafficLayer) {
      tileOverlays = {trafficProvider.trafficOverlay!};
    }
    
    if (!_isInitialized || !locationProvider.hasLocation) {
      return Center(
        child: LoadingIndicator(),
      );
    }
    
    return Scaffold(
      appBar: AppBar(
        title: Text('QuickPark'),
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            icon: Icon(Icons.refresh),
            onPressed: _loadData,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadData,
        child: SingleChildScrollView(
          physics: AlwaysScrollableScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Map section
              Container(
                height: 200,
                child: Stack(
                  children: [
                    GoogleMap(
                      initialCameraPosition: CameraPosition(
                        target: LatLng(
                          locationProvider.currentLocation!.latitude,
                          locationProvider.currentLocation!.longitude,
                        ),
                        zoom: 13,
                      ),
                      markers: _markers,
                      circles: _trafficHotspots,
                      tileOverlays: tileOverlays,
                      myLocationEnabled: true,
                      myLocationButtonEnabled: false,
                      zoomControlsEnabled: false,
                      onMapCreated: _onMapCreated,
                      mapToolbarEnabled: false,
                    ),
                    Positioned(
                      bottom: 8,
                      right: 8,
                      child: FloatingActionButton.small(
                        onPressed: () {
                          Navigator.pushNamed(context, AppRoutes.map);
                        },
                        child: Icon(Icons.fullscreen),
                        tooltip: 'Open Map',
                        backgroundColor: Colors.white,
                        foregroundColor: Theme.of(context).primaryColor,
                      ),
                    ),
                  ],
                ),
              ),
              
              // Content
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Welcome section
                    Card(
                      elevation: 2,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Welcome, ${authProvider.currentUser?.displayName ?? 'User'}!',
                                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  SizedBox(height: 8),
                                  if (_weatherData != null)
                                    Row(
                                      children: [
                                        Image.network(_weatherData!.iconUrl, width: 24, height: 24),
                                        SizedBox(width: 4),
                                        Text(
                                          '${_weatherData!.tempC.toStringAsFixed(1)}°C - ${_weatherData!.conditionText}',
                                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                            color: Colors.blue[700],
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ],
                                    )
                                  else if (_isLoadingWeather)
                                    SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                                  else
                                    Text(
                                      'Find and reserve parking spots easily.',
                                      style: Theme.of(context).textTheme.bodyMedium,
                                    ),
                                ],
                              ),
                            ),
                            CircleAvatar(
                              radius: 30,
                              backgroundColor: Theme.of(context).primaryColor,
                              child: Text(
                                authProvider.currentUser?.displayName.isNotEmpty == true
                                    ? authProvider.currentUser!.displayName[0].toUpperCase()
                                    : 'U',
                                style: TextStyle(
                                  fontSize: 24,
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    
                    SizedBox(height: 24),
                    
                    // Traffic status section
                    Card(
                      elevation: 2,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Current Traffic',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                            SizedBox(height: 12),
                            Row(
                              children: [
                                Icon(
                                  Icons.traffic,
                                  color: _trafficColor,
                                  size: 32,
                                ),
                                SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        '$_trafficCondition Traffic Conditions',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 16,
                                          color: _trafficColor,
                                        ),
                                      ),
                                      SizedBox(height: 4),
                                      Text(
                                        'Based on real-time traffic data in your area',
                                        style: TextStyle(
                                          color: Colors.grey[600],
                                          fontSize: 12,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Switch(
                                  value: trafficProvider.showTrafficLayer,
                                  onChanged: (value) {
                                    trafficProvider.toggleTrafficLayer();
                                  },
                                  activeColor: Theme.of(context).primaryColor,
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    
                    SizedBox(height: 24),
                    
                    // Active bookings section
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Active Bookings',
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        if (bookingProvider.activeBookings.isNotEmpty)
                          TextButton(
                            onPressed: () {
                              Navigator.pushNamed(context, AppRoutes.bookingHistory);
                            },
                            child: Text('View All'),
                          ),
                      ],
                    ),
                    SizedBox(height: 8),
                    
                    if (bookingProvider.isLoading)
                      Center(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 16.0),
                          child: CircularProgressIndicator(),
                        ),
                      )
                    else if (bookingProvider.activeBookings.isEmpty)
                      Card(
                        elevation: 0,
                        color: Colors.grey[100],
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            children: [
                              Icon(
                                Icons.local_parking,
                                size: 48,
                                color: Colors.grey[400],
                              ),
                              SizedBox(height: 12),
                              Text(
                                'No active bookings',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.grey[600],
                                ),
                              ),
                              SizedBox(height: 4),
                              Text(
                                'Book a parking spot for your next trip',
                                style: TextStyle(
                                  color: Colors.grey[600],
                                  fontSize: 12,
                                ),
                                textAlign: TextAlign.center,
                              ),
                              SizedBox(height: 16),
                              ElevatedButton.icon(
                                onPressed: () {
                                  Navigator.pushNamed(context, AppRoutes.parkingmap);
                                },
                                icon: Icon(Icons.search),
                                label: Text('FIND PARKING'),
                                style: ElevatedButton.styleFrom(
                                  padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                    else
                      ...bookingProvider.activeBookings.take(2).map((booking) => 
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8.0),
                          child: _buildActiveBookingCard(booking),
                        )
                      ).toList(),
                    
                    SizedBox(height: 24),
                    
                    // Nearby parking section
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Nearby Parking',
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        TextButton(
                          onPressed: () {
                            Navigator.pushNamed(context, AppRoutes.parkingList);
                          },
                          child: Text('See All'),
                        ),
                      ],
                    ),
                    SizedBox(height: 8),
                    
                    if (parkingProvider.isLoading)
                      Center(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 16.0),
                          child: CircularProgressIndicator(),
                        ),
                      )
                    else if (parkingProvider.nearbyParkingSpots.isEmpty)
                      Card(
                        elevation: 0,
                        color: Colors.grey[100],
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Center(
                            child: Text(
                              'No parking spots found nearby',
                              style: TextStyle(color: Colors.grey[600]),
                            ),
                          ),
                        ),
                      )
                    else
                      Card(
                        elevation: 2,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(
                          children: [
                            ...parkingProvider.nearbyParkingSpots.take(3).map((spot) => 
                              _buildNearbyParkingItem(spot)
                            ).toList(),
                            Divider(height: 1),
                            TextButton(
                              onPressed: () {
                                Navigator.pushNamed(context, AppRoutes.parkingList);
                              },
                              child: Text('VIEW ALL PARKING SPOTS'),
                              style: TextButton.styleFrom(
                                padding: EdgeInsets.symmetric(vertical: 12),
                              ),
                            ),
                          ],
                        ),
                      ),
                    
                    SizedBox(height: 24),
                    
                    // Quick actions
                    Text(
                      'Quick Actions',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 16),
                    
                    Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      alignment: WrapAlignment.start,
                      children: [
                        _buildQuickActionCard(
                          context,
                          Icons.search,
                          'Find Parking',
                          () {
                            Navigator.pushNamed(context, AppRoutes.parkingmap);
                          },
                        ),
                        _buildQuickActionCard(
                          context,
                          Icons.history,
                          'My Bookings',
                          () {
                            Navigator.pushNamed(context, AppRoutes.bookingHistory);
                          },
                          badge: bookingProvider.activeBookings.length > 0 ? 
                            bookingProvider.activeBookings.length.toString() : null,
                        ),
                        _buildQuickActionCard(
                          context,
                          Icons.account_balance_wallet,
                          'Wallet',
                          () {
                            Navigator.pushNamed(context, AppRoutes.wallet);
                          },
                        ),
                        _buildQuickActionCard(
                          context,
                          Icons.chat,
                          'Support',
                          () {
                            Navigator.pushNamed(context, AppRoutes.chat);
                          },
                        ),
                        _buildQuickActionCard(
                          context,
                          Icons.qr_code_scanner,
                          'Scan QR',
                          () {
                            Navigator.pushNamed(context, AppRoutes.scanQr);
                          },
                        ),
                      ],
                    ),
                    
                    SizedBox(height: 16),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
  
  Widget _buildQuickActionCard(
    BuildContext context,
    IconData icon,
    String label,
    VoidCallback onTap, {
    String? badge,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: 100,
        height: 100,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 5,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: Stack(
          children: [
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  icon,
                  size: 36,
                  color: Theme.of(context).primaryColor,
                ),
                SizedBox(height: 8),
                Text(
                  label,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
            if (badge != null)
              Positioned(
                top: 8,
                right: 8,
                child: Container(
                  padding: EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: Colors.red,
                    shape: BoxShape.circle,
                  ),
                  child: Text(
                    badge,
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}