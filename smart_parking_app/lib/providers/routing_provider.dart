// lib/providers/routing_provider.dart
import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:smart_parking_app/config/constants.dart';
import 'package:smart_parking_app/models/route_option.dart';
import 'package:smart_parking_app/models/traffic_bot.dart';

class RoutingProvider with ChangeNotifier {
  List<RouteOption> _routeOptions = [];
  RouteOption? _selectedRoute;
  bool _isLoading = false;
  
  // Getters
  List<RouteOption> get routeOptions => _routeOptions;
  RouteOption? get selectedRoute => _selectedRoute;
  bool get isLoading => _isLoading;
  
  // Find routes between two points using Google Maps Directions API
  Future<void> findRoutes({
    required LatLng origin,
    required LatLng destination,
  }) async {
    _isLoading = true;
    notifyListeners();
    
    try {
      // Request multiple routes from Google Maps Directions API
      final routes = await _fetchGoogleMapsRoutes(origin, destination);
      
      if (routes.isNotEmpty) {
        _routeOptions = routes;
        
        // Sort by duration (fastest first)
        _routeOptions.sort((a, b) => a.durationMinutes.compareTo(b.durationMinutes));
        
        // Auto-select the fastest route
        if (_routeOptions.isNotEmpty) {
          _selectedRoute = _routeOptions.first;
        }
      } else {
        // Fallback to mock routes if Google API returns no routes
        _generateMockRoutes(origin, destination);
      }
    } catch (e) {
      print('Error fetching routes: $e');
      // Fallback to mock routes on API error
      _generateMockRoutes(origin, destination);
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
  
  // Fetch routes from Google Maps Directions API
  Future<List<RouteOption>> _fetchGoogleMapsRoutes(LatLng origin, LatLng destination) async {
    final List<RouteOption> routes = [];
    
    // Build Google Maps Directions API URL
    final url = 'https://maps.googleapis.com/maps/api/directions/json'
        '?origin=${origin.latitude},${origin.longitude}'
        '&destination=${destination.latitude},${destination.longitude}'
        '&alternatives=true'  // Request alternative routes
        '&mode=driving'       // Travel mode (driving, walking, bicycling, transit)
        '&departure_time=now' // Use current time for traffic consideration
        '&traffic_model=best_guess' // Traffic model (best_guess, pessimistic, optimistic)
        '&key=YOUR_GOOGLE_MAPS_API_KEY';
    
    final response = await http.get(Uri.parse(url));
    
    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      
      if (data['status'] == 'OK') {
        final List<dynamic> routesData = data['routes'];
        
        for (int i = 0; i < routesData.length; i++) {
          final route = routesData[i];
          final leg = route['legs'][0]; // First leg contains the full route info
          
          // Parse route data
          final String routeId = 'google_route_$i';
          final String summary = route['summary'] ?? 'Route ${i + 1}';
          
          // Get duration and distance
          final int durationSeconds = leg['duration']['value'];
          final int durationInTrafficSeconds = leg['duration_in_traffic']?['value'] ?? durationSeconds;
          final int durationMinutes = (durationInTrafficSeconds / 60).round();
          final double distanceMeters = leg['distance']['value'].toDouble();
          final double distanceKm = distanceMeters / 1000;
          
          // Determine traffic level based on difference between normal duration and duration in traffic
          TrafficLevel trafficLevel = TrafficLevel.low;
          if (leg['duration_in_traffic'] != null) {
            final double trafficRatio = durationInTrafficSeconds / durationSeconds;
            
            if (trafficRatio >= 2.0) {
              trafficLevel = TrafficLevel.severe;
            } else if (trafficRatio >= 1.5) {
              trafficLevel = TrafficLevel.high;
            } else if (trafficRatio >= 1.2) {
              trafficLevel = TrafficLevel.medium;
            }
          }
          
          // Decode polyline points
          final List<LatLng> points = _decodePolyline(route['overview_polyline']['points']);
          
          // Create route option
          final routeOption = RouteOption(
            id: routeId,
            points: points,
            durationMinutes: durationMinutes,
            distanceKm: distanceKm,
            trafficLevel: trafficLevel,
            description: 'via $summary',
          );
          
          routes.add(routeOption);
        }
      }
    }
    
    return routes;
  }
  
  // Decode Google Maps encoded polyline string
  List<LatLng> _decodePolyline(String encoded) {
    List<LatLng> points = [];
    int index = 0, len = encoded.length;
    int lat = 0, lng = 0;
    
    while (index < len) {
      int b, shift = 0, result = 0;
      
      // Decode latitude
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);
      
      int dlat = ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));
      lat += dlat;
      
      // Decode longitude
      shift = 0;
      result = 0;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);
      
      int dlng = ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));
      lng += dlng;
      
      final latLng = LatLng(lat / 1e5, lng / 1e5);
      points.add(latLng);
    }
    
    return points;
  }
  
  // Select a specific route
  void selectRoute(RouteOption route) {
    _selectedRoute = route;
    notifyListeners();
  }
  
  // Generate mock routes for testing when API fails
  void _generateMockRoutes(LatLng origin, LatLng destination) {
    final random = Random();
    final List<RouteOption> mockRoutes = [];
    
    // Define traffic levels for different routes
    final trafficLevels = [
      TrafficLevel.low,
      TrafficLevel.medium,
      TrafficLevel.high,
    ];
    
    // Route descriptions
    final descriptions = [
      'via Highway',
      'via Main Street',
      'via Downtown',
    ];
    
    // Generate 3 different routes
    for (int i = 0; i < 3; i++) {
      final trafficLevel = trafficLevels[i % trafficLevels.length];
      final description = descriptions[i % descriptions.length];
      
      // Base duration and distance
      final baseDuration = 15 + random.nextInt(15); // 15-30 minutes
      final baseDistance = 5.0 + random.nextDouble() * 5.0; // 5-10 km
      
      // Adjust duration based on traffic
      int durationFactor = 1;
      switch (trafficLevel) {
        case TrafficLevel.low:
          durationFactor = 1;
          break;
        case TrafficLevel.medium:
          durationFactor = 2;
          break;
        case TrafficLevel.high:
          durationFactor = 3;
          break;
        case TrafficLevel.severe:
          durationFactor = 4;
          break;
      }
      
      final adjustedDuration = baseDuration * durationFactor;
      
      // Generate route points
      final List<LatLng> points = _generateRoutePoints(origin, destination, i);
      
      final route = RouteOption(
        id: 'mock_route_$i',
        points: points,
        durationMinutes: adjustedDuration,
        distanceKm: baseDistance + (i * 1.5), // Each route slightly longer
        trafficLevel: trafficLevel,
        description: description,
      );
      
      mockRoutes.add(route);
    }
    
    // Sort by duration (fastest first)
    mockRoutes.sort((a, b) => a.durationMinutes.compareTo(b.durationMinutes));
    
    _routeOptions = mockRoutes;
    
    // Auto-select the fastest route
    if (_routeOptions.isNotEmpty) {
      _selectedRoute = _routeOptions.first;
    }
  }
  
  // Generate route points between origin and destination
  List<LatLng> _generateRoutePoints(LatLng origin, LatLng destination, int routeIndex) {
    final List<LatLng> points = [];
    final random = Random();
    
    // Add origin
    points.add(origin);
    
    // Calculate direct line between origin and destination
    final latDiff = destination.latitude - origin.latitude;
    final lngDiff = destination.longitude - origin.longitude;
    
    // Number of points to generate
    final numPoints = 10 + random.nextInt(10);
    
    // Generate intermediate points with some randomness based on route index
    for (int i = 1; i <= numPoints; i++) {
      // Basic progression from origin to destination
      final ratio = i / (numPoints + 1);
      final baseLat = origin.latitude + latDiff * ratio;
      final baseLng = origin.longitude + lngDiff * ratio;
      
      // Add randomness based on route index
      // Each route will have different "wiggle"
      final latOffset = (random.nextDouble() - 0.5) * 0.005 * (routeIndex + 1);
      final lngOffset = (random.nextDouble() - 0.5) * 0.005 * (routeIndex + 1);
      
      final point = LatLng(
        baseLat + latOffset,
        baseLng + lngOffset,
      );
      
      points.add(point);
    }
    
    // Add destination
    points.add(destination);
    
    return points;
  }
  
  // Clear all routes
  void clearRoutes() {
    _routeOptions = [];
    _selectedRoute = null;
    notifyListeners();
  }
}