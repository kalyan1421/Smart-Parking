// lib/models/revenue_data.dart
import 'package:cloud_firestore/cloud_firestore.dart';

class RevenueData {
  final String id;
  final String parkingSpotId;
  final String parkingSpotName;
  final DateTime date;
  final double dailyRevenue;
  final int totalBookings;
  final int completedBookings;
  final int cancelledBookings;
  final double averageBookingValue;
  final Map<String, int> hourlyBookings; // Hour -> count
  final Map<String, double> hourlyRevenue; // Hour -> revenue
  final DateTime createdAt;
  final DateTime updatedAt;

  RevenueData({
    required this.id,
    required this.parkingSpotId,
    required this.parkingSpotName,
    required this.date,
    required this.dailyRevenue,
    required this.totalBookings,
    required this.completedBookings,
    required this.cancelledBookings,
    required this.averageBookingValue,
    this.hourlyBookings = const {},
    this.hourlyRevenue = const {},
    required this.createdAt,
    required this.updatedAt,
  });

  factory RevenueData.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    
    return RevenueData(
      id: doc.id,
      parkingSpotId: data['parkingSpotId'] ?? '',
      parkingSpotName: data['parkingSpotName'] ?? '',
      date: (data['date'] as Timestamp?)?.toDate() ?? DateTime.now(),
      dailyRevenue: data['dailyRevenue']?.toDouble() ?? 0.0,
      totalBookings: data['totalBookings'] ?? 0,
      completedBookings: data['completedBookings'] ?? 0,
      cancelledBookings: data['cancelledBookings'] ?? 0,
      averageBookingValue: data['averageBookingValue']?.toDouble() ?? 0.0,
      hourlyBookings: Map<String, int>.from(data['hourlyBookings'] ?? {}),
      hourlyRevenue: Map<String, double>.from(data['hourlyRevenue'] ?? {}),
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'parkingSpotId': parkingSpotId,
      'parkingSpotName': parkingSpotName,
      'date': Timestamp.fromDate(date),
      'dailyRevenue': dailyRevenue,
      'totalBookings': totalBookings,
      'completedBookings': completedBookings,
      'cancelledBookings': cancelledBookings,
      'averageBookingValue': averageBookingValue,
      'hourlyBookings': hourlyBookings,
      'hourlyRevenue': hourlyRevenue,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }

  // Calculate success rate
  double get successRate {
    if (totalBookings == 0) return 0.0;
    return (completedBookings / totalBookings) * 100;
  }

  // Get formatted date string
  String get dateString {
    return '${date.day}/${date.month}/${date.year}';
  }
}

class AggregatedRevenueData {
  final double totalRevenue;
  final int totalBookings;
  final double averageBookingValue;
  final List<RevenueData> dailyData;
  final Map<String, double> monthlyRevenue; // Month -> revenue
  final Map<String, int> monthlyBookings; // Month -> bookings

  AggregatedRevenueData({
    required this.totalRevenue,
    required this.totalBookings,
    required this.averageBookingValue,
    required this.dailyData,
    this.monthlyRevenue = const {},
    this.monthlyBookings = const {},
  });

  // Calculate growth rate compared to previous period
  double calculateGrowthRate(AggregatedRevenueData previous) {
    if (previous.totalRevenue == 0) return 0.0;
    return ((totalRevenue - previous.totalRevenue) / previous.totalRevenue) * 100;
  }
}
