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
import 'package:smart_parking_app/screens/parking/parking_directions_screen.dart';
import 'package:smart_parking_app/services/weather_service.dart';
import 'package:smart_parking_app/widgets/common/loading_indicator.dart';
import 'package:intl/intl.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

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
    // Defer data loading to after the build phase
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _loadData();
      }
    });
  }
  
  @override
  void dispose() {
    _mapController?.dispose();
    super.dispose();
  }
  
  Future<void> _loadData() async {
    if (!mounted) return;
    
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final locationProvider = Provider.of<LocationProvider>(context, listen: false);
    final bookingProvider = Provider.of<BookingProvider>(context, listen: false);
    final parkingProvider = Provider.of<ParkingProvider>(context, listen: false);
    final trafficProvider = Provider.of<TrafficProvider>(context, listen: false);
    
    // Initialize location if needed
    if (!locationProvider.hasLocation) {
      await locationProvider.getCurrentLocation();
    }
    
    if (!mounted) return;
    
    // Initialize traffic overlay
    if (!trafficProvider.isOverlaySetup) {
      await Future.microtask(() => trafficProvider.initializeTrafficOverlay());
    }
    
    if (!mounted) return;
    
    // Load active bookings for user
    if (authProvider.currentUser != null) {
      await bookingProvider.loadActiveBookings(authProvider.currentUser!.id);
    }
    
    if (!mounted) return;
    
    // Load nearby parking spots
    if (locationProvider.hasLocation) {
      await parkingProvider.findNearbyParkingSpots(
        locationProvider.currentLocation!.latitude,
        locationProvider.currentLocation!.longitude,
        radius: AppConfig.defaultSearchRadius
      );
    }
    
    if (!mounted) return;
    
    // Load traffic data
    if (locationProvider.hasLocation) {
      await trafficProvider.loadTrafficData(
        locationProvider.currentLocation!.latitude,
        locationProvider.currentLocation!.longitude,
        2.0 // 2 km radius
      );
      
      if (!mounted) return;
      
      // Create traffic hotspots visualization
      _createTrafficHotspots(trafficProvider);
      
      // Analyze overall traffic condition
      _analyzeTrafficCondition(trafficProvider);
      
      // Load weather data
      _loadWeather(locationProvider.currentLocation!.latitude, locationProvider.currentLocation!.longitude);
    }
    
    if (mounted) {
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
    
    if (mounted) {
      setState(() {
        _trafficHotspots = hotspots;
      });
    }
  }
  
  void _analyzeTrafficCondition(TrafficProvider trafficProvider) {
    // Analyze traffic and set condition
    if (!mounted) return;
    
    String condition = 'Unknown';
    Color color = Colors.grey;
    
    if (trafficProvider.trafficBots.isEmpty) {
      condition = 'Normal';
      color = Colors.green;
    } else {
      int severeCount = 0;
      int highCount = 0;
      int mediumCount = 0;
      
      for (final bot in trafficProvider.trafficBots) {
        switch (bot.trafficLevel) {
          case TrafficLevel.severe:
            severeCount++;
            break;
          case TrafficLevel.high:
            highCount++;
            break;
          case TrafficLevel.medium:
            mediumCount++;
            break;
          default:
            break;
        }
      }
      
      if (severeCount > 0) {
        condition = 'Severe';
        color = Colors.purple;
      } else if (highCount > 2) {
        condition = 'Heavy';
        color = Colors.red;
      } else if (highCount > 0 || mediumCount > 2) {
        condition = 'Moderate';
        color = Colors.orange;
      } else {
        condition = 'Light';
        color = Colors.green;
      }
    }
    
    if (mounted) {
      setState(() {
        _trafficCondition = condition;
        _trafficColor = color;
      });
    }
  }

  Future<void> _loadWeather(double lat, double lon) async {
    if (!mounted) return;
    
    setState(() {
      _isLoadingWeather = true;
    });
    
    try {
      final weatherService = WeatherService();
      final data = await weatherService.getCurrentWeather(lat, lon);
      if (mounted) {
        setState(() {
          _weatherData = data;
          _isLoadingWeather = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading weather: $e');
      if (mounted) {
        setState(() {
          _isLoadingWeather = false;
        });
      }
    }
  }
  
  void _onMapCreated(GoogleMapController controller) {
    if (!mounted) return;
    
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
    if (!mounted) return;
    
    final locationProvider = Provider.of<LocationProvider>(context, listen: false);
    final parkingProvider = Provider.of<ParkingProvider>(context, listen: false);
    final bookingProvider = Provider.of<BookingProvider>(context, listen: false);
    
    final markers = <Marker>{};
    
    // Add user location marker
    if (locationProvider.hasLocation) {
      markers.add(Marker(
        markerId: const MarkerId('user_location'),
        position: LatLng(
          locationProvider.currentLocation!.latitude,
          locationProvider.currentLocation!.longitude
        ),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
        infoWindow: const InfoWindow(title: 'Your Location'),
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
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    booking.parkingSpotName,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.green.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Text(
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
            const SizedBox(height: 12),
            Row(
              children: [
                Icon(Icons.access_time, size: 16, color: Colors.grey[600]),
                const SizedBox(width: 4),
                Text(
                  timeRemaining,
                  style: TextStyle(
                    color: durationMinutes < 30 ? Colors.red : Colors.grey[600],
                    fontWeight: durationMinutes < 30 ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                Icon(Icons.calendar_today, size: 16, color: Colors.grey[600]),
                const SizedBox(width: 4),
                Text(
                  '${DateFormat('MMM d').format(booking.startTime)} • ${DateFormat('h:mm a').format(booking.startTime)} - ${DateFormat('h:mm a').format(booking.endTime)}',
                  style: TextStyle(color: Colors.grey[600]),
                ),
              ],
            ),
            const SizedBox(height: 12),
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
                    icon: const Icon(Icons.directions),
                    label: const Text('DIRECTIONS'),
                    style: OutlinedButton.styleFrom(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.pushNamed(context, AppRoutes.bookingHistory);
                    },
                    icon: const Icon(Icons.visibility),
                    label: const Text('DETAILS'),
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
        padding: const EdgeInsets.symmetric(vertical: 4),
        decoration: BoxDecoration(
          color: spot.availableSpots > 0 ? Colors.green : Colors.red,
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(
          spot.availableSpots > 0 ? 'OPEN' : 'FULL',
          textAlign: TextAlign.center,
          style: const TextStyle(
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
      return const Center(
        child: LoadingIndicator(),
      );
    }
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('QuickPark'),
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadData,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadData,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Map section
              SizedBox(
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
                        tooltip: 'Open Map',
                        backgroundColor: Colors.white,
                        foregroundColor: Theme.of(context).primaryColor,
                        child: const Icon(Icons.fullscreen),
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
                                  const SizedBox(height: 8),
                                  if (_weatherData != null)
                                    Row(
                                      children: [
                                        Image.network(_weatherData!.iconUrl, width: 24, height: 24),
                                        const SizedBox(width: 4),
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
                                    const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
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
                                style: const TextStyle(
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
                    
                    const SizedBox(height: 24),
                    
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
                            const Text(
                              'Current Traffic',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Icon(
                                  Icons.traffic,
                                  color: _trafficColor,
                                  size: 32,
                                ),
                                const SizedBox(width: 12),
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
                                      const SizedBox(height: 4),
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
                    
                    const SizedBox(height: 24),
                    
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
                            child: const Text('View All'),
                          ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    
                    if (bookingProvider.isLoading)
                      const Center(
                        child: Padding(
                          padding: EdgeInsets.symmetric(vertical: 16.0),
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
                              const SizedBox(height: 12),
                              Text(
                                'No active bookings',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.grey[600],
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Book a parking spot for your next trip',
                                style: TextStyle(
                                  color: Colors.grey[600],
                                  fontSize: 12,
                                ),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 16),
                              ElevatedButton.icon(
                                onPressed: () {
                                  Navigator.pushNamed(context, AppRoutes.parkingmap);
                                },
                                icon: const Icon(Icons.search),
                                label: const Text('FIND PARKING'),
                                style: ElevatedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
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
                      ),
                    
                    const SizedBox(height: 24),
                    
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
                          child: const Text('See All'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    
                    if (parkingProvider.isLoading)
                      const Center(
                        child: Padding(
                          padding: EdgeInsets.symmetric(vertical: 16.0),
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
                            ),
                            const Divider(height: 1),
                            TextButton(
                              onPressed: () {
                                Navigator.pushNamed(context, AppRoutes.parkingList);
                              },
                              style: TextButton.styleFrom(
                                padding: const EdgeInsets.symmetric(vertical: 12),
                              ),
                              child: const Text('VIEW ALL PARKING SPOTS'),
                            ),
                          ],
                        ),
                      ),
                    
                    const SizedBox(height: 24),
                    
                    // Quick actions
                    Text(
                      'Quick Actions',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    
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
                          badge: bookingProvider.activeBookings.isNotEmpty ? 
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
                    
                    const SizedBox(height: 16),
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
              offset: const Offset(0, 2),
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
                const SizedBox(height: 8),
                Text(
                  label,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
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
                  padding: const EdgeInsets.all(6),
                  decoration: const BoxDecoration(
                    color: Colors.red,
                    shape: BoxShape.circle,
                  ),
                  child: Text(
                    badge,
                    style: const TextStyle(
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
