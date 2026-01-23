// lib/screens/home/dashboard_screen.dart - Enhanced Dashboard screen
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:provider/provider.dart';
import 'package:smart_parking_app/config/app_config.dart';
import 'package:smart_parking_app/config/routes.dart';
import 'package:smart_parking_app/config/theme.dart';
import 'package:smart_parking_app/models/booking.dart';
import 'package:smart_parking_app/models/parking_spot.dart';
import 'package:smart_parking_app/models/traffic_bot.dart';
import 'package:smart_parking_app/providers/auth_provider.dart';
import 'package:smart_parking_app/providers/booking_provider.dart';
import 'package:smart_parking_app/providers/location_provider.dart';
import 'package:smart_parking_app/providers/parking_provider.dart';
import 'package:smart_parking_app/providers/traffic_provider.dart';
import 'package:smart_parking_app/screens/parking/parking_directions_screen.dart';
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
  String _trafficCondition = 'Normal';
  Color _trafficColor = AppTheme.successColor;
  int _trafficDelayMinutes = 0;
  Timer? _countdownTimer;
  
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _loadData();
        _startCountdownTimer();
      }
    });
  }
  
  @override
  void dispose() {
    _mapController?.dispose();
    _countdownTimer?.cancel();
    super.dispose();
  }
  
  void _startCountdownTimer() {
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {});
      }
    });
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
        2.0
      );
      
      if (!mounted) return;
      _analyzeTrafficCondition(trafficProvider);
    }
    
    if (mounted) {
      setState(() {
        _isInitialized = true;
      });
    }
  }
  
  void _analyzeTrafficCondition(TrafficProvider trafficProvider) {
    if (!mounted) return;
    
    String condition = 'Normal';
    Color color = AppTheme.successColor;
    int delayMinutes = 0;
    
    if (trafficProvider.trafficBots.isEmpty) {
      condition = 'Light traffic';
      color = AppTheme.successColor;
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
        condition = 'Heavy congestion';
        color = AppTheme.errorColor;
        delayMinutes = 25;
      } else if (highCount > 2) {
        condition = 'Heavy congestion';
        color = AppTheme.errorColor;
        delayMinutes = 15;
      } else if (highCount > 0 || mediumCount > 2) {
        condition = 'Moderate traffic';
        color = AppTheme.warningColor;
        delayMinutes = 8;
      } else {
        condition = 'Light traffic';
        color = AppTheme.successColor;
        delayMinutes = 0;
      }
    }
    
    if (mounted) {
      setState(() {
        _trafficCondition = condition;
        _trafficColor = color;
        _trafficDelayMinutes = delayMinutes;
      });
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
    
    // Add markers for nearby parking (limited to 5)
    final nearbySpots = parkingProvider.nearbyParkingSpots.take(5).toList();
    for (final spot in nearbySpots) {
      markers.add(Marker(
        markerId: MarkerId('parking_${spot.id}'),
        position: LatLng(spot.latitude, spot.longitude),
        icon: BitmapDescriptor.defaultMarkerWithHue(
          spot.availableSpots > 0 ? BitmapDescriptor.hueGreen : BitmapDescriptor.hueRed
        ),
        infoWindow: InfoWindow(
          title: spot.name,
          snippet: '${spot.availableSpots} spots',
        ),
      ));
    }
    
    setState(() {
      _markers.clear();
      _markers.addAll(markers);
    });
  }
  
  String _formatCountdown(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    final seconds = duration.inSeconds.remainder(60);
    return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }
  
  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final bookingProvider = Provider.of<BookingProvider>(context);
    final locationProvider = Provider.of<LocationProvider>(context);
    
    if (!_isInitialized || !locationProvider.hasLocation) {
      return const Scaffold(
        backgroundColor: AppTheme.backgroundColor,
        body: Center(child: LoadingIndicator()),
      );
    }
    
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      body: RefreshIndicator(
        onRefresh: _loadData,
        color: AppTheme.primaryColor,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Map Section
              _buildMapSection(locationProvider),
              
              // Content
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Welcome Card
                    _buildWelcomeCard(authProvider),
                    
                    const SizedBox(height: 16),
                    
                    // Active Booking Card
                    if (bookingProvider.activeBookings.isNotEmpty)
                      _buildActiveBookingCard(bookingProvider.activeBookings.first),
                    
                    const SizedBox(height: 16),
                    
                    // Traffic Status Card
                    _buildTrafficStatusCard(),
                    
                    const SizedBox(height: 24),
                    
                    // Quick Actions
                    _buildQuickActionsSection(bookingProvider),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
  
  Widget _buildMapSection(LocationProvider locationProvider) {
    return SizedBox(
      height: 220,
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
            myLocationEnabled: true,
            myLocationButtonEnabled: false,
            zoomControlsEnabled: false,
            onMapCreated: _onMapCreated,
            mapToolbarEnabled: false,
          ),
          // My Location Button
          Positioned(
            bottom: 16,
            right: 16,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                boxShadow: AppTheme.shadowMd,
              ),
              child: IconButton(
                onPressed: _centerOnUserLocation,
                icon: Icon(Icons.my_location, color: AppTheme.primaryColor),
              ),
            ),
          ),
          // Search Bar Overlay
          Positioned(
            bottom: 16,
            left: 16,
            right: 80,
            child: GestureDetector(
              onTap: () {
                Navigator.pushNamed(context, AppRoutes.parkingmap);
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                  boxShadow: AppTheme.shadowMd,
                ),
                child: Row(
                  children: [
                    Icon(Icons.search, color: AppTheme.textMuted),
                    const SizedBox(width: 12),
                    Text(
                      'Search for parking or location',
                      style: TextStyle(
                        color: AppTheme.textMuted,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildWelcomeCard(AuthProvider authProvider) {
    final user = authProvider.currentUser;
    final displayName = user?.displayName ?? 'User';
    final initial = displayName.isNotEmpty ? displayName[0].toUpperCase() : 'U';
    
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        boxShadow: AppTheme.shadowSm,
      ),
      child: Row(
        children: [
          // Avatar with image or initials
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              gradient: AppTheme.primaryGradient,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: AppTheme.primaryColor.withOpacity(0.3),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Center(
              child: Text(
                initial,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Welcome, $displayName',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Find your parking spot today',
                  style: TextStyle(
                    fontSize: 14,
                    color: AppTheme.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildActiveBookingCard(Booking booking) {
    final remaining = booking.endTime.difference(DateTime.now());
    final isExpiringSoon = remaining.inMinutes < 30;
    
    final parkingSpot = ParkingSpot(
      id: booking.parkingSpotId,
      name: booking.parkingSpotName,
      description: 'Booked parking spot',
      address: '',
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
    
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        boxShadow: AppTheme.shadowSm,
        border: Border.all(
          color: AppTheme.primaryColor.withOpacity(0.2),
          width: 1,
        ),
      ),
      child: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: AppTheme.primaryColor.withOpacity(0.05),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(AppTheme.radiusLg),
                topRight: Radius.circular(AppTheme.radiusLg),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        color: AppTheme.successColor,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'ACTIVE BOOKING',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.primaryColor,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
                Text(
                  _formatCountdown(remaining),
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: isExpiringSoon ? AppTheme.errorColor : AppTheme.primaryColor,
                  ),
                ),
              ],
            ),
          ),
          // Content
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  booking.parkingSpotName,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Space ${booking.id.substring(0, 4).toUpperCase()} • Expires at ${DateFormat('hh:mm a').format(booking.endTime)}',
                  style: TextStyle(
                    fontSize: 14,
                    color: AppTheme.textSecondary,
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
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
                        icon: const Icon(Icons.navigation, size: 18),
                        label: const Text('Directions'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primaryColor,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () {
                          Navigator.pushNamed(context, AppRoutes.bookingHistory);
                        },
                        icon: Icon(Icons.info_outline, size: 18, color: AppTheme.primaryColor),
                        label: Text('Details', style: TextStyle(color: AppTheme.primaryColor)),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          side: BorderSide(color: AppTheme.primaryColor.withOpacity(0.5)),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildTrafficStatusCard() {
    if (_trafficDelayMinutes == 0) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppTheme.successColor.withOpacity(0.1),
          borderRadius: BorderRadius.circular(AppTheme.radiusLg),
          border: Border.all(color: AppTheme.successColor.withOpacity(0.2)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppTheme.successColor.withOpacity(0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(Icons.check_circle, color: AppTheme.successColor),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _trafficCondition,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.successColor,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'No delays in your area',
                    style: TextStyle(
                      fontSize: 13,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }
    
    return Container(
      decoration: BoxDecoration(
        gradient: AppTheme.trafficGradient,
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        boxShadow: [
          BoxShadow(
            color: AppTheme.errorColor.withOpacity(0.3),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'TRAFFIC STATUS',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: Colors.white.withOpacity(0.8),
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _trafficCondition,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Expect +$_trafficDelayMinutes mins delay in your area',
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.white.withOpacity(0.9),
                  ),
                ),
              ],
            ),
          ),
          Icon(
            Icons.traffic,
            size: 48,
            color: Colors.white.withOpacity(0.3),
          ),
        ],
      ),
    );
  }
  
  Widget _buildQuickActionsSection(BookingProvider bookingProvider) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Quick Actions',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: AppTheme.textPrimary,
          ),
        ),
        const SizedBox(height: 16),
        GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 3,
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: 1.0,
          children: [
            _buildQuickActionItem(
              icon: Icons.local_parking_rounded,
              label: 'Find Parking',
              color: AppTheme.primaryColor,
              onTap: () => Navigator.pushNamed(context, AppRoutes.parkingmap),
            ),
            _buildQuickActionItem(
              icon: Icons.receipt_long_rounded,
              label: 'Bookings',
              color: AppTheme.primaryColor,
              badge: bookingProvider.activeBookings.isNotEmpty
                  ? bookingProvider.activeBookings.length
                  : null,
              onTap: () => Navigator.pushNamed(context, AppRoutes.bookingHistory),
            ),
            _buildQuickActionItem(
              icon: Icons.account_balance_wallet_rounded,
              label: 'Wallet',
              color: AppTheme.primaryColor,
              onTap: () => Navigator.pushNamed(context, AppRoutes.wallet),
            ),
            _buildQuickActionItem(
              icon: Icons.qr_code_scanner_rounded,
              label: 'Scan QR',
              color: AppTheme.primaryColor,
              onTap: () => Navigator.pushNamed(context, AppRoutes.scanQr),
            ),
            _buildQuickActionItem(
              icon: Icons.headset_mic_rounded,
              label: 'Support',
              color: AppTheme.primaryColor,
              onTap: () => Navigator.pushNamed(context, AppRoutes.chat),
            ),
            _buildQuickActionItem(
              icon: Icons.favorite_rounded,
              label: 'Favorites',
              color: AppTheme.primaryColor,
              onTap: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: const Text('Favorites coming soon!'),
                    behavior: SnackBarBehavior.floating,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ],
    );
  }
  
  Widget _buildQuickActionItem({
    required IconData icon,
    required String label,
    required Color color,
    int? badge,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(AppTheme.radiusLg),
          boxShadow: AppTheme.shadowSm,
        ),
        child: Stack(
          children: [
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                    ),
                    child: Icon(icon, color: color, size: 24),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    label,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: AppTheme.textPrimary,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
            if (badge != null)
              Positioned(
                top: 8,
                right: 8,
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: const BoxDecoration(
                    color: AppTheme.errorColor,
                    shape: BoxShape.circle,
                  ),
                  child: Text(
                    badge.toString(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 10,
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
