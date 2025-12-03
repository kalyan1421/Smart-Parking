// lib/models/route_option.dart
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:smart_parking_app/models/traffic_bot.dart';

class RouteOption {
  final String id;
  final List<LatLng> points; // Polyline points
  final int durationMinutes; // Estimated duration in minutes
  final double distanceKm; // Distance in kilometers
  final TrafficLevel trafficLevel; // Overall traffic level
  final String description; // Route description (e.g., "via Highway 101")
  
  RouteOption({
    required this.id,
    required this.points,
    required this.durationMinutes,
    required this.distanceKm,
    required this.trafficLevel,
    required this.description,
  });
  
  // Factory method to create from JSON data
  factory RouteOption.fromJson(Map<String, dynamic> json) {
    // Parse polyline points
    final List<dynamic> rawPoints = json['points'];
    final List<LatLng> parsedPoints = rawPoints
        .map((point) => LatLng(point['lat'], point['lng']))
        .toList();
    
    return RouteOption(
      id: json['id'],
      points: parsedPoints,
      durationMinutes: json['durationMinutes'],
      distanceKm: json['distanceKm'],
      trafficLevel: _parseTrafficLevel(json['trafficLevel']),
      description: json['description'],
    );
  }
  
  // Helper to parse traffic level from string
  static TrafficLevel _parseTrafficLevel(String level) {
    switch (level.toLowerCase()) {
      case 'low':
        return TrafficLevel.low;
      case 'medium':
        return TrafficLevel.medium;
      case 'high':
        return TrafficLevel.high;
      case 'severe':
        return TrafficLevel.severe;
      default:
        return TrafficLevel.medium;
    }
  }
  
  // Formatted time string (e.g. "25 min")
  String get formattedTime {
    if (durationMinutes < 60) {
      return '$durationMinutes min';
    } else {
      final hours = durationMinutes ~/ 60;
      final minutes = durationMinutes % 60;
      return '$hours h ${minutes > 0 ? '$minutes min' : ''}';
    }
  }
  
  // Formatted distance string (e.g. "5.2 km")
  String get formattedDistance {
    return '${distanceKm.toStringAsFixed(1)} km';
  }
  
  // Get a summary of the route
  String get summary {
    return '$formattedTime ($formattedDistance) - ${TrafficBot.getDescriptionForTrafficLevel(trafficLevel)}';
  }
}