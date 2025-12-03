// lib/models/traffic_bot.dart
import 'package:flutter/material.dart';

// Enum for traffic levels
enum TrafficLevel {
  low,     // Free flowing
  medium,  // Moderate congestion
  high,    // Heavy congestion
  severe   // Completely jammed
}

class TrafficBot {
  final String id;
  final double latitude;
  final double longitude;
  final TrafficLevel trafficLevel;
  final DateTime timestamp;
  
  TrafficBot({
    required this.id,
    required this.latitude,
    required this.longitude,
    required this.trafficLevel,
    required this.timestamp,
  });
  
  // Create from JSON (e.g., from API)
  factory TrafficBot.fromJson(Map<String, dynamic> json) {
    return TrafficBot(
      id: json['id'],
      latitude: json['latitude'],
      longitude: json['longitude'],
      trafficLevel: _parseTrafficLevel(json['trafficLevel']),
      timestamp: DateTime.parse(json['timestamp']),
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
  
  // Get color based on traffic level
  static Color getColorForTrafficLevel(TrafficLevel level) {
    switch (level) {
      case TrafficLevel.low:
        return Colors.green;
      case TrafficLevel.medium:
        return Colors.orange;
      case TrafficLevel.high:
        return Colors.red;
      case TrafficLevel.severe:
        return Colors.purple;
    }
  }
  
  // Get human-readable description
  static String getDescriptionForTrafficLevel(TrafficLevel level) {
    switch (level) {
      case TrafficLevel.low:
        return 'Low traffic';
      case TrafficLevel.medium:
        return 'Moderate traffic';
      case TrafficLevel.high:
        return 'Heavy traffic';
      case TrafficLevel.severe:
        return 'Severe congestion';
    }
  }
}