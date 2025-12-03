
// lib/models/traffic_data.dart - Traffic data model
import 'package:cloud_firestore/cloud_firestore.dart';

enum CongestionLevel {
  low,
  moderate,
  high
}

class TrafficData {
  final String id;
  final double latitude;
  final double longitude;
  final String locationName;
  final String? imageUrl;
  final int vehicleCount;
  final CongestionLevel congestionLevel;
  final DateTime timestamp;
  final bool isLive;
  
  TrafficData({
    required this.id,
    required this.latitude,
    required this.longitude,
    required this.locationName,
    this.imageUrl,
    required this.vehicleCount,
    required this.congestionLevel,
    required this.timestamp,
    this.isLive = false,
  });
  
  // Create traffic data from JSON (MongoDB document)
  factory TrafficData.fromJson(Map<String, dynamic> json) {
    return TrafficData(
      id: json['_id'],
      latitude: json['latitude'],
      longitude: json['longitude'],
      locationName: json['locationName'],
      imageUrl: json['imageUrl'],
      vehicleCount: json['vehicleCount'] ?? 0,
      congestionLevel: _parseCongestionLevel(json['congestionLevel']),
      timestamp: DateTime.parse(json['timestamp']),
      isLive: json['isLive'] ?? false,
    );
  }
  
  // Convert traffic data to JSON (for MongoDB)
  Map<String, dynamic> toJson() {
    return {
      '_id': id,
      'latitude': latitude,
      'longitude': longitude,
      'locationName': locationName,
      'imageUrl': imageUrl,
      'vehicleCount': vehicleCount,
      'congestionLevel': congestionLevel.toString().split('.').last,
      'timestamp': timestamp.toIso8601String(),
      'isLive': isLive,
    };
  }
  
  // Parse congestion level from string
  static CongestionLevel _parseCongestionLevel(String? level) {
    if (level == null) return CongestionLevel.low;
    
    switch (level.toLowerCase()) {
      case 'moderate':
        return CongestionLevel.moderate;
      case 'high':
        return CongestionLevel.high;
      default:
        return CongestionLevel.low;
    }
  }
  
  // Check if traffic data is recent (within 30 minutes)
  bool get isRecent {
    final now = DateTime.now();
    return now.difference(timestamp).inMinutes <= 30;
  }
}
