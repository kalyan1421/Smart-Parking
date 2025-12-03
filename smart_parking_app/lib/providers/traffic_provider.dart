// lib/providers/traffic_provider.dart
import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:smart_parking_app/config/constants.dart';
import 'package:smart_parking_app/models/traffic_bot.dart';

class TrafficProvider with ChangeNotifier {
  List<TrafficBot> _trafficBots = [];
  bool _isLoading = false;
  TileOverlay? _trafficOverlay;
  bool _showTrafficLayer = true;
  bool _isOverlaySetup = false;
  
  // Getters
  List<TrafficBot> get trafficBots => _trafficBots;
  bool get isLoading => _isLoading;
  TileOverlay? get trafficOverlay => _trafficOverlay;
  bool get showTrafficLayer => _showTrafficLayer;
  bool get isOverlaySetup => _isOverlaySetup;
  String get tileOverlayId => 'traffic_layer';
  
  // Toggle traffic layer visibility
  void toggleTrafficLayer() {
    _showTrafficLayer = !_showTrafficLayer;
    notifyListeners();
  }
  
  // Setup traffic layer overlay without notifying listeners
  void setupTrafficOverlay() {
    // Only set up once to avoid rebuilding during build
    if (_isOverlaySetup) return;
    
    _trafficOverlay = TileOverlay(
      tileOverlayId: TileOverlayId(tileOverlayId),
      // Google Maps API traffic tiles
      tileProvider: NetworkTileProvider(),
      zIndex: 1,
      visible: _showTrafficLayer,
      fadeIn: true,
    );
    
    _isOverlaySetup = true;
    // No notifyListeners() here to avoid build-time notification
  }
  
  // Initialize traffic overlay (call this from initState with post-frame callback)
  Future<void> initializeTrafficOverlay() async {
    if (!_isOverlaySetup) {
      setupTrafficOverlay();
      // Safe to notify listeners since this is called outside build
      notifyListeners();
    }
  }
  
  // Update overlay visibility
  void updateOverlayVisibility(bool visible) {
    if (_showTrafficLayer != visible) {
      _showTrafficLayer = visible;
      notifyListeners();
    }
  }
  
  // Load traffic data from Google Maps API
  Future<void> loadTrafficData(double latitude, double longitude, double radiusKm) async {
    _isLoading = true;
    notifyListeners();
    
    try {
      // In a real implementation, we would use the Google Maps Roads API
      // to get traffic data for segments. Since this requires backend logic
      // to process the API response, we'll use our mock data here for demonstration.
      
      // Example API call to Google Maps Roads API (requires backend processing):
      // final url = 'https://roads.googleapis.com/v1/snapToRoads?path=$path&interpolate=true&key=${AppConstants.googleMapsApiKey}';
      
      // For real traffic data, we're using TileOverlay in the map directly
      // which automatically displays Google Maps traffic layer
      
      // For the bot visualization, we still need to generate some data
      _generateTrafficBots(latitude, longitude, radiusKm);
    } catch (e) {
      print('Error fetching traffic data: $e');
      _generateTrafficBots(latitude, longitude, radiusKm);
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
  
  // Generate traffic bots based on real road segments
  void _generateTrafficBots(double centerLat, double centerLng, double radiusKm) {
    final random = Random();
    final List<TrafficBot> mockBots = [];
    
    // Define traffic levels
    final trafficLevels = [
      TrafficLevel.low,
      TrafficLevel.medium,
      TrafficLevel.high,
      TrafficLevel.severe,
    ];
    
    // Create random traffic bots around the center
    // In a real implementation, these would be placed on actual roads
    for (int i = 0; i < 50; i++) {
      // Random position within radius
      final double r = radiusKm * sqrt(random.nextDouble()) * 0.009; // Convert km to approx degrees
      final double theta = random.nextDouble() * 2 * pi;
      
      final double lat = centerLat + r * cos(theta);
      final double lng = centerLng + r * sin(theta);
      
      // Random traffic level
      final trafficLevel = trafficLevels[random.nextInt(trafficLevels.length)];
      
      final bot = TrafficBot(
        id: 'traffic_${i}_${DateTime.now().millisecondsSinceEpoch}',
        latitude: lat,
        longitude: lng,
        trafficLevel: trafficLevel,
        timestamp: DateTime.now(),
      );
      
      mockBots.add(bot);
    }
    
    _trafficBots = mockBots;
  }
}

// Network tile provider for Google Maps traffic layer
class NetworkTileProvider implements TileProvider {
  @override
  Future<Tile> getTile(int x, int y, int? zoom) async {
    if (zoom == null) {
      return Tile(0, 0, Uint8List(0));
    }
    
    // Google Maps traffic tile URL format
    final url = 'https://mt0.google.com/vt/lyrs=m@221097413,traffic&x=$x&y=$y&z=$zoom&key=YOUR_GOOGLE_MAPS_API_KEY';
    
    try {
      final response = await http.get(Uri.parse(url));
      
      if (response.statusCode == 200) {
        return Tile(256, 256, response.bodyBytes);
      }
    } catch (e) {
      print('Error loading tile: $e');
    }
    
    // Return empty tile on error
    return Tile(0, 0, Uint8List(0));
  }
}